#!/usr/bin/env bash
set -euo pipefail

DB_INSTANCE_ID="${1:-icloudems-erp-db}"
SOURCE_REGION="ap-south-1"
DR_REGION="ap-south-2"

echo "Finding latest RDS snapshot for '$DB_INSTANCE_ID' in$SOURCE_REGION..."
LATEST_SNAPSHOT_ARN=$(aws rds describe-db-snapshots \
  --region "$SOURCE_REGION" \
  --db-instance-identifier "$DB_INSTANCE_ID" \
  --query "sort_by(DBSnapshots[?Status=='available'], &SnapshotCreateTime)[-1].DBSnapshotArn" \
  --output text)

if [ -z "$LATEST_SNAPSHOT_ARN" ] \vert{}\vert{} [ "$LATEST_SNAPSHOT_ARN" = "None" ]; then
  echo "ERROR: No available snapshot found for $DB_INSTANCE_ID in$SOURCE_REGION."
  exit 1
fi

TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
TARGET_SNAPSHOT_ID="${DB_INSTANCE_ID}-dr-${TIMESTAMP}"

echo "Copying $LATEST_SNAPSHOT_ARN -> $DR_REGION ($TARGET_SNAPSHOT_ID)..."
# Note: If the source RDS snapshot is encrypted with KMS, add: --kms-key-id <ap-south-2-kms-key-arn>
aws rds copy-db-snapshot \
  --region "$DR_REGION" \
  --source-region "$SOURCE_REGION" \
  --source-db-snapshot-identifier "$LATEST_SNAPSHOT_ARN" \
  --target-db-snapshot-identifier "$TARGET_SNAPSHOT_ID"

echo "Snapshot copy initiated: $TARGET_SNAPSHOT_ID in$DR_REGION."
