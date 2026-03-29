-- Suppresses the "Opening file '...'" dialog that briefly flashes
-- when opening a book. The dialog has a zero timeout and disappears
-- too quickly to read, so it just adds visual noise.

local BD = require("ui/bidi")
local InfoMessage = require("ui/widget/infomessage")
local ReaderUI = require("apps/reader/readerui")
local UIManager = require("ui/uimanager")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local T = require("ffi/util").template
local _ = require("gettext")

local orig_showReaderCoroutine = ReaderUI.showReaderCoroutine

function ReaderUI:showReaderCoroutine(file, provider, seamless)
    -- Show an invisible InfoMessage to preserve the forceRePaint/nextTick
    -- flow that the original relies on, without the visual flash.
    UIManager:show(InfoMessage:new{
        text = T(_("Opening file '%1'."), BD.filepath(filemanagerutil.abbreviate(file))),
        timeout = 0.0,
        invisible = true,
    })
    UIManager:forceRePaint()
    UIManager:nextTick(function()
        local co = coroutine.create(function()
            self:doShowReader(file, provider, seamless)
        end)
        local ok, err = coroutine.resume(co)
        if err ~= nil or ok == false then
            io.stderr:write('[!] doShowReader coroutine crashed:\n')
            io.stderr:write(debug.traceback(co, err, 1))
            require("device"):setIgnoreInput(false)
            require("ui/input"):inhibitInputUntil(0.2)
            UIManager:show(InfoMessage:new{
                text = _("No reader engine for this file or invalid file.")
            })
            self:showFileManager(file)
        end
    end)
end
