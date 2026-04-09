-- Custom dogear icon patch
-- Replaces the default dogear with a custom PNG at 4x size
-- Uses a toast overlay to render above bookends but below menus
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
        covers_fullscreen = false,
    }

    function DogearOverlay:init()
        self.dimen = Geom:new{ x = 0, y = 0, w = 0, h = 0 }
    end

    function DogearOverlay:paintTo(bb, x, y)
        local dogear = self._dogear
        if not dogear or not dogear.view or not dogear.view.dogear_visible then return end
        -- Only paint when no menus/dialogs are open: count non-toast
        -- widgets in the stack (normally just ReaderUI = 1)
        local count = 0
        for i = 1, #UIManager._window_stack do
            local w = UIManager._window_stack[i].widget
            if w ~= self and not w.toast then
                count = count + 1
            end
        end
        if count > 1 then return end
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
            -- Register overlay once; it reads visibility from dogear.view
            if not self._dogear_overlay then
                self._dogear_overlay = DogearOverlay:new{}
                self._dogear_overlay._dogear = self
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
