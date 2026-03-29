local WidgetContainer = require("ui/widget/container/widgetcontainer")

local DisplayModeHomeFolder = WidgetContainer:extend{
    name = "displaymodehomefolder",
}

function DisplayModeHomeFolder:init()
    if self.ui.document then
        return -- FileManager only, not Reader
    end
    self.ui.menu:registerToMainMenu(self)

    local patcher = require("patchfilechooser")
    patcher.apply()
    self._patcher = patcher
end

function DisplayModeHomeFolder:onCloseWidget()
    if self._patcher then
        self._patcher.teardown()
        self._patcher = nil
    end
end

function DisplayModeHomeFolder:addToMainMenu(menu_items)
    -- Menu injection is built separately in menu.lua
    require("menu")(self, menu_items)
end

return DisplayModeHomeFolder
