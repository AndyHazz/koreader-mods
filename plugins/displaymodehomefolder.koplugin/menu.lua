-- menu.lua — Display Mode Home Folder
-- Injects "Subfolder display mode" into CoverBrowser's Display Mode menu
-- as a sibling of History/Collections display mode.
-- Returns an installer function: require("menu")(plugin, menu_items)

local FileChooser = require("ui/widget/filechooser")
local logger = require("logger")
local _ = require("gettext")

-- Display mode options: nil (use global) + the 6 CoverBrowser modes.
-- Labels match CoverBrowser's own mode names exactly.
local DISPLAY_MODES = {
    { text = _("Use global setting"), mode = nil },
    { text = _("Classic (filename only)"), mode = "classic" },
    { text = _("Mosaic with cover images"), mode = "mosaic_image" },
    { text = _("Mosaic with text covers"), mode = "mosaic_text" },
    { text = _("Detailed list with cover images and metadata"), mode = "list_image_meta" },
    { text = _("Detailed list with metadata, no images"), mode = "list_only_meta" },
    { text = _("Detailed list with cover images and filenames"), mode = "list_image_filename" },
}

-- Build a sort-by submenu from FileChooser.collates.
local function buildSortItems(setting_key)
    local items = {}
    items[#items + 1] = {
        text = _("Use global setting"),
        checked_func = function()
            return G_reader_settings:readSetting(setting_key) == nil
        end,
        radio = true,
        callback = function()
            G_reader_settings:delSetting(setting_key)
        end,
        separator = true,
    }
    local collates = {}
    for id, def in pairs(FileChooser.collates) do
        collates[#collates + 1] = { id = id, text = def.text, order = def.menu_order }
    end
    table.sort(collates, function(a, b) return a.order < b.order end)
    for _, c in ipairs(collates) do
        items[#items + 1] = {
            text = c.text,
            checked_func = function()
                return G_reader_settings:readSetting(setting_key) == c.id
            end,
            radio = true,
            callback = function()
                G_reader_settings:saveSetting(setting_key, c.id)
            end,
        }
    end
    return items
end

-- Build a display-mode submenu.
local function buildDisplayModeItems(setting_key)
    local items = {}
    for i, entry in ipairs(DISPLAY_MODES) do
        items[#items + 1] = {
            text = entry.text,
            checked_func = function()
                local current = G_reader_settings:readSetting(setting_key)
                if entry.mode == nil then
                    return current == nil
                end
                return current == entry.mode
            end,
            radio = true,
            callback = function()
                if entry.mode == nil then
                    G_reader_settings:delSetting(setting_key)
                else
                    G_reader_settings:saveSetting(setting_key, entry.mode)
                end
            end,
            separator = i == 1,
        }
    end
    return items
end

return function(plugin, menu_items)
    local cb_menu = menu_items.filemanager_display_mode
    if not cb_menu or not cb_menu.sub_item_table then
        logger.warn("DisplayModeHomeFolder: CoverBrowser display mode menu not found, creating standalone menu entry")
        menu_items.subfolder_display_mode = {
            text = _("Subfolder overrides"),
            sub_item_table = {
                {
                    text = _("Subfolder display mode"),
                    sub_item_table = buildDisplayModeItems("subfolder_display_mode"),
                },
                {
                    text = _("Subfolder sort mode"),
                    sub_item_table = buildSortItems("subfolder_collate"),
                },
            },
        }
        return
    end

    -- Inject as sibling of History/Collections display mode
    local sub = cb_menu.sub_item_table
    sub[#sub + 1] = {
        text = _("Subfolder overrides"),
        sub_item_table = {
            {
                text = _("Subfolder display mode"),
                sub_item_table = buildDisplayModeItems("subfolder_display_mode"),
            },
            {
                text = _("Subfolder sort mode"),
                sub_item_table = buildSortItems("subfolder_collate"),
            },
        },
    }
end
