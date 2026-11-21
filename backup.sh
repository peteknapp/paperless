#!/bin/bash
# Nightly export of everything in Paperless (documents + tags, correspondents,
# notes, users) to the NAS export folder, in a form Paperless can re-import
# with document_importer. The NAS backups / Glacier scripts pick it up from there.
#
# crontab -e on bps27:
#   30 2 * * * ~/paperless/backup.sh >> ~/paperless/backup.log 2>&1
set -euo pipefail
cd "$(dirname "$0")"
echo "== $(date '+%F %T') export"
# -d: drop files from the export that were deleted in Paperless
# -f: compare checksums, not just timestamps (CIFS times are coarse)
docker compose exec -T webserver document_exporter ../export -d -f
echo "== done"
