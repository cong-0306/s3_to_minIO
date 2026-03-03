#!/usr/bin/env python3
# update_video_storage.py
# 목적:
# S3 → MinIO mirror 완료 후,
# 실제 MinIO에 존재하는 파일만 DB를 MINIO 상태로 업데이트

import asyncio
import subprocess
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from db import AsyncSessionLocal


# =========================
# 환경 설정
# =========================
MC_BIN = "/usr/local/bin/mc-minio"
MINIO_ALIAS = "myminio"
MINIO_BUCKET = "videos"


def minio_exists(object_key: str) -> bool:
    """
    MinIO에 객체 존재 여부 확인
    구조: myminio/videos/{object_key}
    """
    target = f"{MINIO_ALIAS}/{MINIO_BUCKET}/{object_key}"

    result = subprocess.run(
        [MC_BIN, "stat", target],
        capture_output=True,
        text=True,
    )

    return result.returncode == 0


async def main():
    updated = 0
    skipped = 0
    checked = 0

    async with AsyncSessionLocal() as session:
        try:
            # 1️⃣ 아직 S3 상태이며 archive 안 된 파일만 조회
            result = await session.execute(
                text("""
                    SELECT file_id, s3_key
                    FROM video_file
                    WHERE storage = 'S3'
                      AND is_archived = FALSE
                    ORDER BY file_id ASC
                """)
            )

            rows = result.fetchall()

            # 2️⃣ MinIO 존재 확인 후 업데이트
            for file_id, s3_key in rows:
                checked += 1

                # 최신 구조에서는 s3_key = minio_key
                if minio_exists(s3_key):
                    await session.execute(
                        text("""
                            UPDATE video_file
                            SET storage = 'MINIO',
                                minio_bucket = :minio_bucket,
                                minio_key = :minio_key,
                                is_archived = TRUE
                            WHERE file_id = :file_id
                        """),
                        {
                            "file_id": file_id,
                            "minio_bucket": MINIO_BUCKET,
                            "minio_key": s3_key,
                        }
                    )
                    updated += 1
                else:
                    skipped += 1

            await session.commit()

            print(f"[DB] checked={checked}, updated={updated}, skipped={skipped}")

        except SQLAlchemyError as e:
            await session.rollback()
            print(f"[DB ERROR] {e}")
            raise

        except Exception as e:
            await session.rollback()
            print(f"[UNEXPECTED ERROR] {e}")
            raise


if __name__ == "__main__":
    asyncio.run(main())

