# s3_to_minIO

crontab -l
```bash h*/5 * * * * /home/ansible/terraform/files/sync_s3_to_minio.sh >> /home/ansible/terraform/logs/cron.log 2>&1```
