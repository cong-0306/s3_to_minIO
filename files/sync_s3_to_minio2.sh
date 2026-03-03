#!/bin/bash
set -euo pipefail

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

# =====================================
# 1️⃣ Mirror 실행
# =====================================
"$MC_BIN" mirror \
  "$S3_ALIAS/$S3_BUCKET" \
  "$MINIO_ALIAS/$MINIO_BUCKET" \
  --overwrite \
  >> "$LOG_FILE" 2>&1

RESULT=$?

if [ $RESULT -ne 0 ]; then
  echo "[ERROR] Mirror failed (code=$RESULT)" | tee -a "$LOG_FILE"
  exit $RESULT
fi

echo "[SUCCESS] Mirror completed" | tee -a "$LOG_FILE"

# =====================================
# 2️⃣ DB 업데이트 실행
# =====================================
python3 "$BASE_DIR/files/update_video_storage.py" >> "$LOG_FILE" 2>&1
DB_RESULT=$?

if [ $DB_RESULT -ne 0 ]; then
  echo "[ERROR] DB update failed (code=$DB_RESULT)" | tee -a "$LOG_FILE"
  exit $DB_RESULT
fi

echo "[SUCCESS] DB update completed" | tee -a "$LOG_FILE"

echo "[DONE] Sync + DB update finished" | tee -a "$LOG_FILE"

exit 0

