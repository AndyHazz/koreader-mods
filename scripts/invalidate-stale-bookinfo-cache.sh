#!/bin/sh
# Invalidate stale rows in KOReader's bookinfo_cache.sqlite3.
#
# Why: KOReader's CoverBrowser caches extracted EPUB metadata in
# bookinfo_cache.sqlite3, keyed by filename + directory. It only
# re-extracts when the cached filemtime differs from the on-disk
# mtime. That works for most flows, but a few scenarios leave the
# cache stuck:
#   - A book was modified on another device and synced in while
#     KOReader was running.
#   - A metadata-enrichment tool rewrote the EPUB in place but the
#     book hasn't been browsed in CoverBrowser since.
#   - The file was restored from backup with an older mtime that
#     happens to be newer than the cache thought it was.
#
# Symptom: missing cover / series / description in the library view
# even though the EPUB itself is fine.
#
# This script walks every row in the cache, stats the underlying
# file, and deletes rows where the on-disk mtime is newer than what
# the cache recorded. Rows for files that no longer exist are left
# alone (CoverBrowser has its own pruning). Idempotent — re-running
# on a freshly-cleaned cache is a no-op.
#
# Run on-device (SSH into the Kindle):
#   /bin/sh invalidate-stale-bookinfo-cache.sh
#
# After running, open KOReader's file browser. CoverBrowser will
# re-extract metadata the next time each affected book is visible.

set -e

DB="${1:-/mnt/us/koreader/settings/bookinfo_cache.sqlite3}"

if [ ! -f "$DB" ]; then
    echo "ERROR: bookinfo cache not found at $DB" >&2
    echo "Pass the correct path as the first argument." >&2
    exit 1
fi

if ! command -v sqlite3 >/dev/null 2>&1; then
    echo "ERROR: sqlite3 not available on PATH" >&2
    exit 1
fi

# Pull every row's (rowid, directory, filename, cached_filemtime).
# Use -separator $'\t' for a reliable delimiter (filenames can contain |).
TMP_IN=$(mktemp -t bookinfo-cache-XXXXXX)
TMP_STALE=$(mktemp -t bookinfo-stale-XXXXXX)
trap 'rm -f "$TMP_IN" "$TMP_STALE"' EXIT

sqlite3 -separator '	' "$DB" \
    "SELECT bcid, directory, filename, ifnull(filemtime, 0) FROM bookinfo" \
    > "$TMP_IN"

TOTAL=$(wc -l < "$TMP_IN" | tr -d ' ')
echo "Scanning $TOTAL cache rows..."

missing=0
fresh=0
stale=0

while IFS='	' read -r bcid directory filename cached_mtime; do
    [ -z "$bcid" ] && continue
    full="${directory}${filename}"
    if [ ! -f "$full" ]; then
        missing=$((missing + 1))
        continue
    fi
    disk_mtime=$(stat -c %Y "$full" 2>/dev/null || echo 0)
    if [ "$disk_mtime" -gt "$cached_mtime" ]; then
        echo "$bcid" >> "$TMP_STALE"
        stale=$((stale + 1))
    else
        fresh=$((fresh + 1))
    fi
done < "$TMP_IN"

echo "  fresh:   $fresh"
echo "  stale:   $stale"
echo "  missing: $missing (skipped — CoverBrowser prunes these itself)"

if [ "$stale" -gt 0 ]; then
    # Build a single DELETE. sqlite3 handles large IN-lists fine.
    IDS=$(tr '\n' ',' < "$TMP_STALE" | sed 's/,$//')
    sqlite3 "$DB" "DELETE FROM bookinfo WHERE bcid IN ($IDS)"
    echo "Deleted $stale stale row(s)."
    echo
    echo "Next step: open KOReader's file browser and scroll past"
    echo "the affected books. CoverBrowser will re-extract each one."
fi
