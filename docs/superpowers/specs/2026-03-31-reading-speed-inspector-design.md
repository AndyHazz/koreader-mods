# Reading Speed Inspector Plugin — Design Spec

## Overview

A KOReader plugin that opens a popup explaining how the reading speed estimate and time-remaining calculations work, backed by a per-page histogram showing reading pace across the book.

## Plugin structure

```
plugins/readingspeedinspector.koplugin/
  _meta.lua           -- plugin metadata
  main.lua            -- entry point, menu registration, dispatcher action
  inspectorview.lua   -- custom widget: formula, histogram, stats breakdown
```

## Access points

- **Menu item**: "Reading speed inspector" under the existing "Reading statistics" submenu (alongside "Current book", "Reading progress", etc.)
- **Dispatcher action**: `reading_speed_inspector` — assignable to any gesture, tap zone, or physical button. Label: "Reading speed inspector".

## Popup layout

A scrollable `InputContainer` with three sections, top to bottom:

### 1. Formula section

Styled text showing the core time-remaining calculation with actual values:

```
28 pages left  x  42s avg/page  =  19m 36s remaining
Chapter: 8 pages left  x  42s avg/page  =  5m 36s
```

### 2. Histogram

A bar chart of per-page capped dwell times for every page read in the current book.

- **Data source**: DB query — `SELECT page, min(sum(duration), max_sec) FROM page_stat WHERE id_book = ? GROUP BY page ORDER BY page`, merged with volatile `self.page_stat` for current-session pages not yet flushed.
- **Bucketing**: If pages exceed available horizontal pixels, bucket adjacent pages together (integer division). Each bar represents one bucket; bar height = average dwell time in that bucket.
- **Average line**: Horizontal dashed line at `avg_time` height across the chart.
- **Bar shading** (three states):
  - Historical (DB) pages: dark gray
  - Current-session pages: light gray
  - Capped pages (duration hit `max_sec`): black — applies to both historical and session bars, overriding their base shade
- **Session start marker**: Vertical line at the first page of the current session.
- **Axis labels**: Left axis shows time scale (e.g. 0s, 60s, 120s). Bottom shows page range.

### 3. Stats breakdown

Key-value list (styled like KOReader's standard key-value layouts):

**Averaging inputs:**
- Average time per page (the core number)
- Total read time (book lifetime)
- Distinct pages read (book lifetime)

**Session vs historical:**
- Session pages / session time
- DB pages / DB time
- Note: these can overlap (same page counted in both until DB flush)

**Filter thresholds:**
- Min threshold (default 5s) — page turns faster than this are discarded
- Max threshold (default 120s) — page dwells longer than this are capped
- Count of capped pages (from DB query)

**Current page:**
- Dwell time so far (snapshot at popup open)
- Whether it would currently be filtered, counted, or capped

**Page counts:**
- Total pages in book
- Pages remaining in book
- Pages remaining in chapter

## Data gathering

All data collected in a single read-only pass when the popup opens:

1. **From `self.ui.statistics`**: `avg_time`, `mem_read_pages`, `mem_read_time`, `book_read_pages`, `book_read_time`, `settings.min_sec`, `settings.max_sec`, `page_stat` (volatile), `id_curr_book`, `curr_page`, `start_current_period`
2. **From DB**: Per-page capped durations for the histogram (single indexed query)
3. **From `self.ui.document`**: `getTotalPagesLeft(page)`, `info.number_of_pages`
4. **From `self.ui.toc`**: `getChapterPagesLeft(pageno)`
5. **Current page dwell**: `os.time() - page_stat[curr_page][last].timestamp`

## Cold start behaviour

When no reading data exists yet (just opened a new book):
- `avg_time` defaults to `0.50 * max_sec` (60s with default settings)
- Formula section shows the default estimate with a note: "(default estimate — no pages read yet)"
- Histogram is empty
- Stats breakdown shows zeroes for read time/pages

## Widget implementation notes

- Uses `ScrollableContainer` for e-ink-friendly scrolling
- Histogram rendered via custom `paintTo` using `bb:paintRect()` (same approach as the existing `HistogramWidget` in calendarview.lua)
- Stats breakdown built as `VerticalGroup` of `TextWidget`/`LeftContainer`/`RightContainer` pairs
- Formula section uses `TextBoxWidget` with bold text for the numbers
- No live updating — static snapshot only
- Close via title bar button or back gesture

## Dependencies

All read-only access to existing KOReader internals:
- `self.ui.statistics` — reading stats plugin instance
- `self.ui.document` — document page info
- `self.ui.toc` — chapter boundaries
- `statistics.sqlite3` — per-page duration data (via statistics plugin's DB connection)
- Standard widgets: `InputContainer`, `ScrollableContainer`, `FrameContainer`, `VerticalGroup`, `TextWidget`, `LineWidget`
- `Blitbuffer` — for histogram bar rendering
