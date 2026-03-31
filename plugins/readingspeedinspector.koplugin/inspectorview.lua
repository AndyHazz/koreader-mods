local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local CloseButton = require("ui/widget/closebutton")
local Device = require("device")
local Font = require("ui/font")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local ScrollableContainer = require("ui/widget/container/scrollablecontainer")
local Size = require("ui/size")
local TextBoxWidget = require("ui/widget/textboxwidget")
local TextWidget = require("ui/widget/textwidget")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local datetime = require("datetime")
local Screen = Device.screen
local T = require("ffi/util").template
local _ = require("gettext")

local DataGatherer = require("datagatherer")
local SpeedHistogramWidget = require("histogramwidget")

local InspectorView = InputContainer:extend{
    ui = nil,
    width = nil,
    height = nil,
}

function InspectorView:init()
    self.width = self.width or Screen:getWidth()
    self.height = self.height or Screen:getHeight()
    self.dimen = Geom:new{ w = self.width, h = self.height }

    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{ ges = "swipe", range = self.dimen }
        }
    end

    -- Gather data
    local data = DataGatherer:collect(self.ui)
    local fmt = data.duration_format

    -- Layout constants
    local padding = Size.padding.large
    local content_width = self.width - 2 * padding - ScrollableContainer:getScrollbarWidth()
    local font_face_normal = Font:getFace("cfont", 16)
    local font_face_bold = Font:getFace("cfont", 16)
    local font_face_small = Font:getFace("cfont", 14)
    local font_face_title_section = Font:getFace("cfont", 18)

    -- Build the content
    local vgroup = VerticalGroup:new{ align = "left" }

    -- === FORMULA SECTION ===
    table.insert(vgroup, self:buildSectionTitle(_("Time remaining estimate"), font_face_title_section, content_width))
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    local avg_str = datetime.secondsToClockDuration(fmt, data.avg_time, false)
    local book_time_str = datetime.secondsToClockDuration(fmt, data.time_left_book, true)
    local chapter_time_str = datetime.secondsToClockDuration(fmt, data.time_left_chapter, true)

    local formula_text
    if data.has_data then
        formula_text = T(_("%1 pages left  ×  %2 avg/page  =  %3"),
            data.pages_left_book, avg_str, book_time_str)
            .. "\n"
            .. T(_("Chapter: %1 pages left  ×  %2 avg/page  =  %3"),
            data.pages_left_chapter, avg_str, chapter_time_str)
    else
        formula_text = _("No reading data yet — the estimate uses a default of 60s per page until you start turning pages.")
    end

    table.insert(vgroup, TextBoxWidget:new{
        text = formula_text,
        face = font_face_normal,
        width = content_width,
        alignment = "left",
    })

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_large })

    -- === HISTOGRAM SECTION ===
    table.insert(vgroup, self:buildSectionTitle(_("Per-page reading time"), font_face_title_section, content_width))
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    if #data.per_page > 0 then
        -- Legend
        local legend_text = _("■ historical  ") .. _("■ this session  ") .. _("■ capped  ") .. _("--- average")
        table.insert(vgroup, TextWidget:new{
            text = legend_text,
            face = font_face_small,
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        })
        table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

        -- Histogram
        local histo_height = math.floor(self.height * 0.20)
        table.insert(vgroup, SpeedHistogramWidget:new{
            width = content_width,
            height = histo_height,
            per_page = data.per_page,
            max_sec = data.max_sec,
            avg_time = data.avg_time,
            session_start_page = data.session_start_page,
            total_pages = data.total_pages,
        })

        -- Axis labels
        local axis_group = OverlapGroup:new{
            dimen = { w = content_width },
            TextWidget:new{
                text = "p.1",
                face = font_face_small,
                fgcolor = Blitbuffer.COLOR_DARK_GRAY,
            },
        }
        -- Right-aligned page count
        local right_label = TextWidget:new{
            text = T("p.%1", data.total_pages),
            face = font_face_small,
            fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        }
        right_label.overlap_offset = { content_width - right_label:getSize().w, 0 }
        table.insert(axis_group, right_label)
        table.insert(vgroup, axis_group)
    else
        table.insert(vgroup, TextBoxWidget:new{
            text = _("No per-page data available yet."),
            face = font_face_normal,
            width = content_width,
        })
    end

    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_large })

    -- === STATS BREAKDOWN ===
    table.insert(vgroup, self:buildSectionTitle(_("Calculation breakdown"), font_face_title_section, content_width))
    table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })

    local stats_rows = {}

    -- Averaging inputs
    table.insert(stats_rows, { _("Average time per page"), avg_str })
    table.insert(stats_rows, { _("Total read time (book lifetime)"), datetime.secondsToClockDuration(fmt, data.total_read_time, false) })
    table.insert(stats_rows, { _("Distinct pages read"), tostring(data.total_read_pages) })
    table.insert(stats_rows, "separator")

    -- Session vs historical
    table.insert(stats_rows, { _("This session: pages read"), tostring(data.mem_read_pages) })
    table.insert(stats_rows, { _("This session: read time"), datetime.secondsToClockDuration(fmt, data.mem_read_time, false) })
    table.insert(stats_rows, { _("From database: pages read"), tostring(data.book_read_pages) })
    table.insert(stats_rows, { _("From database: read time"), datetime.secondsToClockDuration(fmt, data.book_read_time, false) })
    table.insert(stats_rows, "separator")

    -- Filter thresholds
    table.insert(stats_rows, { _("Min page duration (below = ignored)"), T(_("%1s"), data.min_sec) })
    table.insert(stats_rows, { _("Max page duration (above = capped)"), T(_("%1s"), data.max_sec) })
    table.insert(stats_rows, { _("Pages that hit the cap"), tostring(data.capped_count) })
    table.insert(stats_rows, "separator")

    -- Current page
    if data.current_page_dwell then
        local dwell_str = datetime.secondsToClockDuration(fmt, data.current_page_dwell, false)
        local status
        if data.current_page_dwell < data.min_sec then
            status = _("(would be ignored)")
        elseif data.current_page_dwell > data.max_sec then
            status = _("(would be capped)")
        else
            status = _("(will be counted)")
        end
        table.insert(stats_rows, { _("Current page dwell time"), dwell_str .. "  " .. status })
    else
        table.insert(stats_rows, { _("Current page dwell time"), _("N/A") })
    end
    table.insert(stats_rows, "separator")

    -- Page counts
    table.insert(stats_rows, { _("Total pages in book"), tostring(data.total_pages) })
    table.insert(stats_rows, { _("Current page"), tostring(data.curr_page) })
    table.insert(stats_rows, { _("Pages remaining (book)"), tostring(data.pages_left_book) })
    table.insert(stats_rows, { _("Pages remaining (chapter)"), tostring(data.pages_left_chapter) })

    for _, row in ipairs(stats_rows) do
        if row == "separator" then
            table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })
            table.insert(vgroup, LineWidget:new{
                dimen = Geom:new{ w = content_width, h = Size.line.medium },
                background = Blitbuffer.COLOR_LIGHT_GRAY,
            })
            table.insert(vgroup, VerticalSpan:new{ width = Size.span.vertical_default })
        else
            table.insert(vgroup, self:buildKeyValueRow(row[1], row[2], font_face_normal, content_width))
        end
    end

    table.insert(vgroup, VerticalSpan:new{ width = Size.padding.large })

    -- === ASSEMBLE ===
    local title_bar = TitleBar:new{
        title = _("Reading speed inspector"),
        width = self.width,
        close_callback = function() self:onClose() end,
    }

    local scroll_height = self.height - title_bar:getHeight()
    self.cropping_widget = ScrollableContainer:new{
        dimen = Geom:new{
            w = self.width,
            h = scroll_height,
        },
        FrameContainer:new{
            padding = padding,
            bordersize = 0,
            background = Blitbuffer.COLOR_WHITE,
            vgroup,
        },
    }

    self[1] = FrameContainer:new{
        width = self.width,
        height = self.height,
        padding = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            align = "left",
            title_bar,
            self.cropping_widget,
        },
    }
end

function InspectorView:buildSectionTitle(text, face, width)
    return TextWidget:new{
        text = text,
        face = face,
        bold = true,
        max_width = width,
    }
end

function InspectorView:buildKeyValueRow(key, value, face, width)
    local key_w = TextWidget:new{
        text = key,
        face = face,
        max_width = math.floor(width * 0.6),
    }
    local value_w = TextWidget:new{
        text = value,
        face = face,
        fgcolor = Blitbuffer.COLOR_DARK_GRAY,
        max_width = math.floor(width * 0.4),
    }
    return HorizontalGroup:new{
        key_w,
        HorizontalSpan:new{ width = Size.span.horizontal_default },
        value_w,
    }
end

function InspectorView:show()
    UIManager:show(self, "full")
end

function InspectorView:onClose()
    UIManager:close(self, "full")
    return true
end

function InspectorView:onSwipe(_, ges)
    if ges.direction == "south" then
        self:onClose()
        return true
    end
end

return InspectorView
