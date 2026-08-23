-- Keeps a Kindle awake for as long as it's plugged in, and lets it sleep
-- normally again the moment it's unplugged.
--
-- KOReader already defers its own auto-suspend while the battery is filling
-- (autosuspend.koplugin/main.lua, the `is_charging` branch of _schedule), but
-- that guard is deliberately conditional on NOT being fully charged -- the
-- comment there reads "We *do* want to make sure we attempt to go into
-- suspend/shutdown again while *fully* charged, though". So a Kindle left on
-- the cable overnight stays awake until it tops up, then sleeps anyway. On top
-- of that, Kindle's own powerd runs a screensaver timer that KOReader doesn't
-- own at all.
--
-- Three separate things therefore have to be held off, and all three are
-- released again on unplug:
--
--   preventScreenSaver           powerd's own screensaver timer (lipc)
--   PluginShare.pause_auto_suspend   KOReader's auto-suspend AND auto-shutdown
--   PluginShare.keepalive        stops AutoSuspend resetting the Kindle t1
--                                timeout, which it must not do while the
--                                screensaver is disabled in powerd
--
-- That last one is not optional. autosuspend.koplugin/main.lua:134-138 says:
-- "KeepAlive on Kindles work by disabling screensaver in powerd. As this makes
-- the t1 timeout behave wackily, we must not reset it, as it causes a crash."
-- AutoSuspend only skips that reset when PluginShare.keepalive is set. While
-- genuinely charging it also skips it for a separate reason (the isCharging
-- check further down), but that second guard lapses exactly when the battery
-- reads fully charged -- which is the window this patch exists to cover.
--
-- Hooks go on Device:_beforeCharging / :_afterNotCharging rather than on a
-- Charging event listener, because a patch has no widget in the event chain to
-- register. Kindle dispatches both through those methods
-- (device/kindle/device.lua UIManager.event_handlers.Charging / NotCharging),
-- and assigning to the instance returned by require("device") shadows whatever
-- the subclass inherited.

local Device = require("device")

if Device:isKindle() then
    local PluginShare = require("pluginshare")
    local lfs = require("libs/libkoreader-lfs")
    local logger = require("logger")

    local function readFirstLine(path)
        local fh = io.open(path, "r")
        if not fh then return nil end
        local line = fh:read("*l")
        fh:close()
        return line
    end

    -- powerd's isCharging() reports charging *activity*, not whether the cable
    -- is in: at full charge it goes false while still plugged (seen on a PW5 at
    -- 99% -- isCharging 0, battery status "Discharging", yet the charger's
    -- online flag still 1). The transition hooks below don't care, since they
    -- fire off the USB plug/unplug event, but startup and resume have no event
    -- to read and genuinely need "is it plugged in?".
    --
    -- Take that from sysfs: any supply that isn't the battery and reports
    -- online. Excluding only type "Battery" rather than matching USB/AC keeps
    -- wireless charging counted on the models that have a Wireless supply.
    local function chargerPresent()
        local ok, present = pcall(function()
            local base = "/sys/class/power_supply"
            for entry in lfs.dir(base) do
                if entry ~= "." and entry ~= ".." then
                    local dir = base .. "/" .. entry
                    if readFirstLine(dir .. "/type") ~= "Battery"
                        and readFirstLine(dir .. "/online") == "1" then
                        return true
                    end
                end
            end
            return false
        end)
        return ok and present
    end

    -- Set the property through KOReader's own lipc handle rather than shelling
    -- out. keepalive.koplugin does this with
    -- os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver 1"), which
    -- is fine there because it only ever runs from a menu tap -- but this patch
    -- also runs it from _beforeSuspend, and forking a process while the system is
    -- preparing to suspend, on a device with under 512 MB of RAM, is asking for
    -- trouble. powerd's own KindlePowerD:init already holds an lipc handle
    -- (device/kindle/powerd.lua) and drives flIntensity through it the same way,
    -- so reuse it: same effect, in-process, no fork.
    --
    -- The os.execute path stays as a fallback for the case where liblipclua
    -- didn't load and powerd has no handle, since then there's nothing to reuse.
    local function setPreventScreenSaver(on)
        local value = on and 1 or 0
        local handle = Device.powerd and Device.powerd.lipc_handle
        if handle then
            local ok = pcall(function()
                handle:set_int_property("com.lab126.powerd", "preventScreenSaver", value)
            end)
            if ok then return end
            logger.warn("StayAwakeWhileCharging: lipc set failed, falling back to shell")
        end
        os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver " .. value)
    end

    local function stayAwake()
        logger.dbg("StayAwakeWhileCharging: holding off sleep (on charge)")
        PluginShare.pause_auto_suspend = true
        PluginShare.keepalive = true
        setPreventScreenSaver(true)
    end

    -- Idempotent, and safe to call when we were never holding anything off --
    -- every transition out of "plugged in" routes through here, so releasing
    -- unconditionally is what stops a missed transition wedging the device
    -- permanently awake.
    --
    -- reset_idle gives powerd a fresh idle window on the way out. Without it,
    -- unplugging put the device to sleep instantly with no screensaver: powerd's
    -- t1 timer had been suppressed for however many hours the cable was in, so
    -- the moment the suppression lifted it saw a long-expired timer and went
    -- straight down. Strictly correct -- the device really had been idle that
    -- long -- but pulling the cable shouldn't kill the device in your hand.
    -- resetT1Timeout must run while still awake; its own comment notes it fails
    -- once the screensaver is up. Skipped on the suspend and exit paths, where a
    -- fresh idle window is either pointless or actively wrong.
    local function allowSleep(reset_idle)
        logger.dbg("StayAwakeWhileCharging: releasing sleep inhibitors",
                   reset_idle and "(with idle reset)" or "")
        PluginShare.pause_auto_suspend = false
        PluginShare.keepalive = false
        setPreventScreenSaver(false)
        if reset_idle and Device.powerd and Device.powerd.resetT1Timeout then
            pcall(function() Device.powerd:resetT1Timeout() end)
        end
    end

    local orig_beforeCharging = Device._beforeCharging
    function Device:_beforeCharging()
        stayAwake()
        return orig_beforeCharging(self)
    end

    local orig_afterNotCharging = Device._afterNotCharging
    function Device:_afterNotCharging()
        -- Unplug: hand back a full idle window rather than a long-expired one.
        allowSleep(true)
        return orig_afterNotCharging(self)
    end

    -- An explicit sleep (power button, or a gesture) should still work while on
    -- charge, so drop the inhibitors on the way down. The next _beforeCharging
    -- re-applies them, and _afterResume below covers waking still plugged in.
    local orig_beforeSuspend = Device._beforeSuspend
    function Device:_beforeSuspend(inhibit)
        allowSleep()
        return orig_beforeSuspend(self, inhibit)
    end

    -- Waking up still on the cable gets no Charging event (nothing changed
    -- while we were out), so re-assert rather than wait for an unplug/replug.
    local orig_afterResume = Device._afterResume
    function Device:_afterResume(inhibit)
        local ret = orig_afterResume(self, inhibit)
        if chargerPresent() then stayAwake() end
        return ret
    end

    -- Leaving preventScreenSaver set after KOReader is gone would keep the
    -- Kindle awake with nothing running to undo it, so clear on the way out.
    -- A SIGKILL still can't be caught -- recover with
    --   lipc-set-prop com.lab126.powerd preventScreenSaver 0
    local orig_exit = Device.exit
    function Device:exit()
        allowSleep()
        return orig_exit(self)
    end

    -- Apply the current state at startup: KOReader is frequently launched with
    -- the cable already in, which produces no transition to hook.
    if chargerPresent() then
        stayAwake()
    end
end
