-- Custom dogear icon patch
-- Replaces the default dogear with a custom PNG at 4x size
local ReaderDogear = require("apps/reader/modules/readerdogear")
local ImageWidget = require("ui/widget/imagewidget")
local DataStorage = require("datastorage")
local Device = require("device")
local lfs = require("libs/libkoreader-lfs")

local SCALE = 4

if not ReaderDogear._custom_dogear_patched then
    ReaderDogear._custom_dogear_patched = true
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
                self[1].dimen.w = Device.screen:getWidth()
                self[1].dimen.h = (self.dogear_y_offset or 0) + scaled_size
            end
            if self.top_pad then
                self.top_pad.width = self.dogear_y_offset or 0
            end
        end
    end
end
