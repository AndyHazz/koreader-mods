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
    local logger = require("logger")

    -- Mirrors keepalive.koplugin's Kindle branch. os.execute is fine here:
    -- this only ever runs on a plug/unplug/suspend/exit transition.
    local function setPreventScreenSaver(on)
        os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver " .. (on and "1" or "0"))
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
    local function allowSleep()
        logger.dbg("StayAwakeWhileCharging: releasing sleep inhibitors")
        PluginShare.pause_auto_suspend = false
        PluginShare.keepalive = false
        setPreventScreenSaver(false)
    end

    local orig_beforeCharging = Device._beforeCharging
    function Device:_beforeCharging()
        stayAwake()
        return orig_beforeCharging(self)
    end

    local orig_afterNotCharging = Device._afterNotCharging
    function Device:_afterNotCharging()
        allowSleep()
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
        local ok, charging = pcall(function()
            return self.powerd:isCharging() and not self.powerd:isCharged()
        end)
        if ok and charging then stayAwake() end
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
    local ok, charging = pcall(function()
        return Device.powerd:isCharging() and not Device.powerd:isCharged()
    end)
    if ok and charging then
        stayAwake()
    end
end
