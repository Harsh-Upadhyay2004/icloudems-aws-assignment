# Task 5: Snapshot Handling (Design + Script)

## 1. Automated Daily & Weekly EBS Snapshots (Amazon DLM)
- **Target Resource:** EBS Volumes tagged `Environment=prod` (or `Project=icloudems-erp`).
- **IAM Role:** `AWSDataLifecycleManagerDefaultRole`.
- **Schedules:**
  - **Daily Schedule:** Run every 24 hours at `02:00 UTC` (`07:30 AM IST`), retain **7** daily snapshots.
  - **Weekly Schedule:** Run every Sunday at `03:00 UTC` (`08:30 AM IST`), retain **4** weekly snapshots.
- **CLI Setup Example (`dlm-policy.json`):**
~~~json
{
  "PolicyType": "EBS_SNAPSHOT_MANAGEMENT",
  "ResourceTypes": ["VOLUME"],
  "TargetTags": [{ "Key": "Environment", "Value": "prod" }],
  "Schedules": [
    {
      "Name": "DailySnapshots",
      "CreateRule": { "Interval": 24, "IntervalUnit": "HOURS", "Times": ["02:00"] },
      "RetainRule": { "Count": 7 },
      "CopyTags": true
    },
    {
      "Name": "WeeklySnapshots",
      "CreateRule": { "CronExpression": "cron(0 3 ? * SUN *)" },
      "RetainRule": { "Count": 4 },
      "CopyTags": true
    }
  ]
}
~~~
~~~bash
aws dlm create-lifecycle-policy \
  --region ap-south-1 \
  --execution-role-arn arn:aws:iam::<ACCOUNT_ID>:role/service-role/AWSDataLifecycleManagerDefaultRole \
  --description "Keep 7 daily and 4 weekly EBS snapshots" \
  --state ENABLED \
  --policy-details file://dlm-policy.json
~~~

## 2. RDS Automated Backups (7 Days) vs. Manual Snapshots
- **Enable 7-day automated backups (low-traffic window at 02:30 AM IST / 21:00 UTC):**
~~~bash
aws rds modify-db-instance \
  --region ap-south-1 \
  --db-instance-identifier icloudems-erp-db \
  --backup-retention-period 7 \
  --preferred-backup-window "21:00-21:30" \
  --apply-immediately
~~~
- **Automated Backups vs. Manual Snapshots:**
  - **Retention & Deletion:** Automated backups expire after the retention window (1–35 days) and are **deleted if the RDS instance is deleted** (unless explicitly retained). Manual snapshots **never expire** and survive DB instance deletion until you delete them.
  - **Recovery Granularity:** Automated backups + continuous transaction logs (shipped to S3 every ~5 minutes) support **Point-in-Time Recovery (PITR)** down to the second. Manual snapshots restore only to the exact moment the snapshot was taken.
  - **Trigger:** Automated backups run daily during the preferred backup window; manual snapshots are user/script-triggered (e.g., before a major Laravel migration or schema change).

## 3. Cross-Region RDS Snapshot Copy Script
Implemented in [`scripts/copy_latest_rds_snapshot.sh`](../scripts/copy_latest_rds_snapshot.sh). It queries the latest `available` snapshot in `ap-south-1` and copies it to `ap-south-2`.

## 4. Point-in-Time Recovery (PITR) to 10:15 AM IST Yesterday
> **Timezone note:** AWS RDS PITR uses **UTC**. `10:15 AM IST` = `04:45:00 UTC` (`IST = UTC + 5:30`).

1. **Verify restorable window:** Check `LatestRestorableTime` on `icloudems-erp-db` to confirm `2026-11-23T04:45:00Z` is within the 7-day retention window.
2. **Launch PITR restore (creates a NEW RDS instance; RDS never overwrites in place):**
   - **Console:** **RDS → Databases → `icloudems-erp-db` → Actions → Restore to point in time** → select **Custom date and time** (`2026-11-23 04:45:00 UTC`) → target identifier `icloudems-erp-db-pitr` → attach the same VPC, subnet group, and `icloudems-rds-sg`.
   - **AWS CLI:**
~~~bash
aws rds restore-db-instance-to-point-in-time \
  --region ap-south-1 \
  --source-db-instance-identifier icloudems-erp-db \
  --target-db-instance-identifier icloudems-erp-db-pitr \
  --restore-time "2026-11-23T04:45:00Z" \
  --vpc-security-group-ids sg-0e4090d36c48415d8
~~~
3. **Validate & Cut Over:**
   - Wait until `icloudems-erp-db-pitr` status is `available`.
   - Connect from an EC2 instance (or temporary bastion) to verify the missing/corrupted fee or exam rows are intact.
   - Update Laravel's `DB_WRITE_HOST` (or rename the old DB to `-old` and `icloudems-erp-db-pitr` to `icloudems-erp-db`) and restart/refresh the app tier.
