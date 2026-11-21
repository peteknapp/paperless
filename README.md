# paperless

Paperless-ngx for household **records**: bills, statements, tax forms, medical
paperwork, warranties and manuals. It runs OCR on them, makes them searchable,
and tags and files them.

Keepsakes and photos don't come here. They go through the
[scanning](https://github.com/peteknapp/scanning) sorter into the `pvr`
archive, dated by hand. Paperless takes over every file it imports and
renames it, so it never touches `pvr`.

```
 Scan document (sort.eymf.org) ──┐
 To Paperless / Whole scan ──────┼──►  NAS paperless/consume/  ──►  Paperless (docs.eymf.org)
 (later: Adobe Scan "records",   │      polled every 60 s            OCR · tags · search
  email attachments)  ───────────┘                                         │
                                                                           ▼
                                               NAS paperless/media/documents/originals/YYYY/<correspondent>/<title>.pdf
```

## What lives where

| | Where | Why |
|---|---|---|
| Postgres (`pgdata/`), Valkey (`redisdata/`), search index (`data/`) | `~/paperless` on bps27's local disk | Databases over SMB corrupt or crawl |
| Documents (`media/`), `consume/`, `export/` | NAS, `$NAS_ROOT` (default `/mnt/nas/data/paperless`) | Covered by the NAS backups |

## Setup (bps27)

```bash
git clone git@github.com:peteknapp/paperless.git ~/paperless
cd ~/paperless
cp .env.example .env
openssl rand -base64 48 | tr -d '/+=' | head -c 50; echo   # run twice: DB_PASSWORD, SECRET_KEY
nano .env
mkdir -p /mnt/nas/data/paperless/{media,consume,export}
docker compose up -d
docker compose logs -f webserver          # first start migrates the database (a minute or two)
docker compose exec webserver createsuperuser
```

- `PUID`/`PGID` must be able to write the NAS folders. Check with
  `touch /mnt/nas/data/paperless/consume/x && rm $_`. The CIFS mount options
  (`uid`, `gid`, `file_mode`, `dir_mode`) decide this, the same way as for
  scanservjs.
- Caddy (`~/caddy/Caddyfile`), inside the `*.eymf.org` block:
  ```
  @docs host docs.eymf.org
  handle @docs {
      reverse_proxy 192.168.0.163:8010
  }
  ```
- Homepage (`~/homepage/config/services.yaml`):
  ```yaml
  - Documents:
      - Paperless:
          icon: paperless-ngx.svg
          href: https://docs.eymf.org
          description: Bills, statements, records
  ```

## Hooking up the scanning sorter

In `~/scanning/.env` add
`PAPERLESS_CONSUME=/mnt/nas/data/paperless/consume`, then
`docker compose up -d --build` there. The sorter then gets **Scan document**,
**To Paperless** and **Whole scan → Paperless**.

First test: a 2-sided document through the feeder. That shows whether the
9120e accepts 2-sided and PDF over the network.

## Backups

`backup.sh` runs Paperless's own exporter into `$NAS_ROOT/export`. That gives
the documents plus all tags, correspondents and notes, ready for
`document_importer`. The originals in `media/` alone would lose the metadata.

```
crontab -e
30 2 * * * ~/paperless/backup.sh >> ~/paperless/backup.log 2>&1
```

## Getting started in Paperless

- Correspondents for who it's from (Xcel Energy, Sanford Health, IRS);
  document types for what it is (Bill, Statement, Tax, Medical, Warranty,
  Receipt); a few tags (e.g. `tax-2026`).
- Assign by hand for the first few dozen documents. After that the automatic
  matching (on by default) starts guessing well.
- Users: an account for Kimberly, sharing set per document or by default.
  Reachable away from home once the household is on Tailscale.

## Updating

`docker compose pull && docker compose up -d`. Diun already reports new
images. Postgres major versions need a dump and restore, so keep `postgres:18`
pinned until deliberately upgrading.
