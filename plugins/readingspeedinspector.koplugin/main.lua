local Dispatcher = require("dispatcher")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local _ = require("gettext")

local ReadingSpeedInspector = WidgetContainer:extend{
    name = "readingspeedinspector",
    is_doc_only = true,
}

function ReadingSpeedInspector:onDispatcherRegisterActions()
    Dispatcher:registerAction("reading_speed_inspector", {
        category = "none",
        event = "ShowReadingSpeedInspector",
        title = _("Reading speed inspector"),
        reader = true,
    })
end

function ReadingSpeedInspector:init()
    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function ReadingSpeedInspector:addToMainMenu(menu_items)
    local stats_menu = menu_items.statistics
    if stats_menu and stats_menu.sub_item_table then
        table.insert(stats_menu.sub_item_table, {
            text = _("Reading speed inspector"),
            callback = function()
                self:showInspector()
            end,
            enabled_func = function()
                return self.ui.statistics and self.ui.statistics:isEnabled()
            end,
        })
    else
        menu_items.reading_speed_inspector = {
            text = _("Reading speed inspector"),
            sorting_hint = "more_tools",
            callback = function()
                self:showInspector()
            end,
            enabled_func = function()
                return self.ui.statistics and self.ui.statistics:isEnabled()
            end,
        }
    end
end

function ReadingSpeedInspector:showInspector()
    local InspectorView = require("inspectorview")
    local view = InspectorView:new{
        ui = self.ui,
    }
    view:show()
end

function ReadingSpeedInspector:onShowReadingSpeedInspector()
    self:showInspector()
end

return ReadingSpeedInspector
