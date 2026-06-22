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
    -- The item lives under the "statistics" menu anchor (via sorting_hint), which
    -- only exists when the statistics module is loaded. In incognito mode there
    -- is no statistics module, so that anchor is absent -- registering anyway
    -- would leave an orphaned sorting_hint and crash KOReader's menu sorter.
    -- A speed inspector is also pointless without statistics, so just skip it.
    if not self.ui.statistics then return end
    -- Use sorting_hint so the menu sorter places this inside the statistics
    -- submenu regardless of plugin load order.
    menu_items.reading_speed_inspector = {
        text = _("Reading speed inspector"),
        sorting_hint = "statistics",
        callback = function()
            self:showInspector()
        end,
        enabled_func = function()
            return self.ui.statistics and self.ui.statistics:isEnabled()
        end,
    }
end

function ReadingSpeedInspector:showInspector()
    local InspectorView = require("inspectorview")
    local view = InspectorView:new{
        ui = self.ui,
    }
    view:show()
end

function ReadingSpeedInspector:onShowReadingSpeedInspector()
    if self.ui.statistics and self.ui.statistics:isEnabled() then
        self:showInspector()
    end
end

return ReadingSpeedInspector
