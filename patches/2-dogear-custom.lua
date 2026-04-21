-- Custom dogear icon patch
-- Replaces the default dogear with a custom PNG at 4x size, then registers
-- a toast overlay that re-paints the dogear after every ReaderView pass so
-- it stays on top of Bookends / other view modules — *and* survives a
-- Bookends paintTo error (which aborts Bookends' own dogear-repaint mid-way
-- and has been leaving the dogear obscured for a while).
--
-- The earlier version of this overlay broke ReaderRolling's CRe reload gate
-- because `getTopmostVisibleWidget` returned the toast instead of ReaderUI.
-- Adding `invisible = true` keeps us out of that walk (uimanager.lua:780) —
-- the _repaint loop at uimanager.lua:1246 does NOT check `invisible`, so the
-- overlay still paints.
local ReaderDogear = require("apps/reader/modules/readerdogear")
local ImageWidget = require("ui/widget/imagewidget")
local DataStorage = require("datastorage")
local Device = require("device")
local lfs = require("libs/libkoreader-lfs")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Geom = require("ui/geometry")
local Screen = Device.screen

local SCALE = 4

if not ReaderDogear._custom_dogear_patched then
    ReaderDogear._custom_dogear_patched = true

    local DogearOverlay = WidgetContainer:extend{
        name = "DogearOverlay",
        toast = true,
        invisible = true,
        covers_fullscreen = false,
    }

    function DogearOverlay:init()
        self.dimen = Geom:new{ x = 0, y = 0, w = 0, h = 0 }
    end

    function DogearOverlay:paintTo(bb, x, y)
        local dogear = self._dogear
        if not dogear or not dogear.view or not dogear.view.dogear_visible then return end
        -- Suppress when a fullscreen widget (TOC, bookmap, etc.) covers the
        -- reader. Small dialogs (ButtonDialog, ConfirmBox) don't set
        -- covers_fullscreen, so the dogear stays visible above them.
        for i = #UIManager._window_stack, 1, -1 do
            local w = UIManager._window_stack[i].widget
            if w ~= self and not w.toast then
                if w.covers_fullscreen then return end
                break
            end
        end
        dogear:paintTo(bb, x, y)
    end

    local orig_setupDogear = ReaderDogear.setupDogear
    ReaderDogear.setupDogear = function(self, new_dogear_size)
        orig_setupDogear(self, new_dogear_size)
        local icon_path = DataStorage:getDataDir() .. "/icons/dogear-custom.png"
        if lfs.attributes(icon_path, "mode") == "file" and self.icon then
            local scaled_size = math.ceil(self.dogear_size * SCALE)
            self.icon:free()
            self.icon = ImageWidget:new{
                file = icon_path,
                width = scaled_size,
                height = scaled_size,
                alpha = true,
                is_icon = true,
            }
            self.dogear_size = scaled_size
            if self.vgroup then
                self.vgroup[2] = self.icon
                self.vgroup:resetLayout()
            end
            if self[1] and self[1].dimen then
                self[1].dimen.w = Screen:getWidth()
                self[1].dimen.h = (self.dogear_y_offset or 0) + scaled_size
            end
            if self.top_pad then
                self.top_pad.width = self.dogear_y_offset or 0
            end
            if not self._dogear_overlay then
                self._dogear_overlay = DogearOverlay:new{ _dogear = self }
                UIManager:show(self._dogear_overlay)
            end
            self._dogear_overlay.dimen = self[1].dimen:copy()
        end
    end

    local orig_onCloseDocument = ReaderDogear.onCloseDocument
    ReaderDogear.onCloseDocument = function(self)
        if self._dogear_overlay then
            UIManager:close(self._dogear_overlay)
            self._dogear_overlay = nil
        end
        if orig_onCloseDocument then
            return orig_onCloseDocument(self)
        end
    end
end
