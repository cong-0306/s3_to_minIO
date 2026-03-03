#!/bin/bash
set -uo pipefail

export HOME=/home/ansible
export PATH=/usr/local/bin:/usr/bin:/bin

MC_BIN="/usr/local/bin/mc-minio"

S3_ALIAS="s3"
S3_BUCKET="hybrid-video-minio-backup-prod"

MINIO_ALIAS="myminio"
MINIO_BUCKET="videos"

BASE_DIR="$HOME/terraform"
LOG_DIR="$BASE_DIR/logs"
mkdir -p "$LOG_DIR"

NOW=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="$LOG_DIR/sync_$NOW.log"

echo "[START] S3 → MinIO sync at $NOW" | tee -a "$LOG_FILE"

# mirror 실행
"$MC_BIN" mirror \
  "$S3_ALIAS/$S3_BUCKET" \
  "$MINIO_ALIAS/$MINIO_BUCKET" \
  --overwrite \
  >> "$LOG_FILE" 2>&1

RESULT=$?

if [ $RESULT -eq 0 ]; then
  echo "[SUCCESS] Sync completed" | tee -a "$LOG_FILE"
else
  echo "[ERROR] Mirror failed (code=$RESULT)" | tee -a "$LOG_FILE"
fi

exit $RESULT

