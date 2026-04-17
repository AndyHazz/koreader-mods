# KOReader Mods

A collection of patches, plugins, and style tweaks for [KOReader](https://github.com/koreader/koreader).

## Patches

User patches go in the KOReader `patches/` directory. Copy the `.lua` file and restart KOReader.

| Patch | Description |
|-------|-------------|
| [2-suppress-opening-dialog.lua](patches/2-suppress-opening-dialog.lua) | Hides the "Opening file '...'" dialog that briefly flashes when opening a book. |
| [2-coverbrowser-swipe-updown.lua](patches/2-coverbrowser-swipe-updown.lua) | Adds up/down swipe for page navigation in CoverBrowser History/Collections views. |
| [2-suppress-frontlight-notifications.lua](patches/2-suppress-frontlight-notifications.lua) | Suppresses "Frontlight intensity set to X" and "Warmth set to X" notifications when using gestures to change brightness/warmth. |
| [2-dogear-custom.lua](patches/2-dogear-custom.lua) | Replaces the default bookmark dogear with a custom folded-corner icon at 4x scale. Copy [dogear-custom.png](icons/dogear-custom.png) to `koreader/icons/`. |

## Plugins

Plugins go in the KOReader `plugins/` directory. Copy the entire `.koplugin` folder and restart KOReader.

| Plugin | Description |
|--------|-------------|
| [readingspeedinspector.koplugin](plugins/readingspeedinspector.koplugin) | Shows how reading speed and time-remaining estimates are calculated, with a per-page histogram and detailed stats breakdown. Accessible via Reading statistics menu and as a dispatcher action. |

Also see [bookends.koplugin](https://github.com/AndyHazz/bookends.koplugin) — configurable text overlays at 6 screen positions.

## Style Tweaks

CSS style tweaks go in the KOReader `styletweaks/` directory. Each `.css` file is automatically loaded and applied to documents.

| Tweak | Description |
|-------|-------------|
| [captions.css](styletweaks/captions.css) | Caption styling |
| [footnotes.css](styletweaks/footnotes.css) | Footnote formatting |
| [headings.css](styletweaks/headings.css) | Heading styles |
| [hr.css](styletweaks/hr.css) | Horizontal rule styling |
| [img.css](styletweaks/img.css) | Centre images, constrain to page width |
| [paragraphs.css](styletweaks/paragraphs.css) | Paragraph spacing and indentation |
| [tables.css](styletweaks/tables.css) | Table formatting |
| [toc.css](styletweaks/toc.css) | Table of contents styling |

## Device scripts

Standalone shell scripts for one-off device maintenance. Run over SSH on the target device.

| Script | Description |
|--------|-------------|
| [syncthing-ext-storage.sh](scripts/syncthing-ext-storage.sh) | Moves Syncthing's SQLite database off VFAT (`/mnt/us`) to an ext3 partition (`/var/local`) on the Kindle. Fixes the "disk I/O error: no such file or directory" crash loop that Syncthing 2.x hits under burst write load on VFAT. Preserves the device ID by copying identity files; patches `syncthing.koplugin/main.lua`'s `homePath()` in-place. |
| [invalidate-stale-bookinfo-cache.sh](scripts/invalidate-stale-bookinfo-cache.sh) | Invalidates stale rows in KOReader's `bookinfo_cache.sqlite3`. Compares each cached filemtime to the on-disk mtime and deletes rows where the file has been modified since extraction (e.g. after a metadata rewrite by an external tool). CoverBrowser re-extracts lazily on the next library view. |

## Installation paths

| Device | Patches | Plugins | Style Tweaks |
|--------|---------|---------|--------------|
| Kindle | `/mnt/us/koreader/patches/` | `/mnt/us/koreader/plugins/` | `/mnt/us/koreader/styletweaks/` |
| Kobo | `/mnt/onboard/.adds/koreader/patches/` | `/mnt/onboard/.adds/koreader/plugins/` | `/mnt/onboard/.adds/koreader/styletweaks/` |
| Android | Varies | Same | Same |

## Compatibility

Tested on KOReader 2025.08 (Kindle PW5).

## License

AGPL-3.0 — see [LICENSE](LICENSE)
