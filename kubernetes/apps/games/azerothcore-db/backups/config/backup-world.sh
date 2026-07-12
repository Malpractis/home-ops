#!/usr/bin/env bash
# Weekly mysqldump of acore_world (huge, reproducible from source SQL — the
# dump just makes restores one-step). Any failure exits non-zero -> the Job
# goes Failed -> the games namespace alerts fire.
set -euo pipefail

HOST=azerothcore-db.games.svc.cluster.local
STAMP="$(date +%Y%m%d-%H%M%S)"
RETAIN_COUNT=2

out="/backups/acore_world-${STAMP}.sql.gz"
echo "[backup-world] dumping acore_world -> ${out}"
# --no-tablespaces: skips the tablespace dump that would need PROCESS priv;
# the acore user only has grants on acore_%.
mysqldump --host="${HOST}" --user=acore \
  --single-transaction --routines --no-tablespaces \
  acore_world | gzip > "${out}"
gunzip -t "${out}"

echo "[backup-world] pruning to the newest ${RETAIN_COUNT} dumps"
# Timestamps are in the filenames, so lexicographic sort == chronological.
ls -1 /backups/acore_world-*.sql.gz | sort -r | tail -n "+$((RETAIN_COUNT + 1))" \
  | xargs -r rm -fv --

echo "[backup-world] done"
ls -lh /backups
