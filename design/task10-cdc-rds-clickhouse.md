# Task 10: CDC Setup — RDS MySQL to ClickHouse (Design)

## 1. Architecture (< 1 Minute Near Real-Time Latency)

~~~text
+------------------+     binlog (ROW)     +-----------------------+     Kafka Topic      +-----------------------------+
|  Amazon RDS      | -------------------> |  Kafka Connect +      | -------------------> |  Amazon MSK (Kafka)         |
|  MySQL (Primary) |                      |  Debezium MySQL       |  (erp.db.fee_txns)   |  Retention: 7 days          |
+------------------+                      +-----------------------+                      +-----------------------------+
                                                                                                       |
                                                                                                       v
+------------------+     Materialized     +-----------------------+                      +-----------------------------+
|  Analytics       | <------------------- |  ClickHouse           | <------------------- |  ClickHouse Kafka Engine    |
|  Dashboards      |     View / Query     |  ReplacingMergeTree   |   INSERT via MV      |  (kafka_fee_transactions)   |
+------------------+                      +-----------------------+                      +-----------------------------+
~~~

- **Why Debezium + Amazon MSK + ClickHouse Kafka Engine:** Captures every `INSERT`, `UPDATE`, and `DELETE` from MySQL binlogs in sub-second real time (< 1 minute SLA) without adding `SELECT` polling load to the production RDS MySQL instance.

## 2. Required RDS MySQL Settings
1. **Custom DB Parameter Group** (attached to `icloudems-erp-db`; requires a **reboot** for static parameters):
   - `binlog_format = ROW` (required so Debezium receives full before/after row images)
   - `binlog_row_image = FULL`
   - `gtid_mode = ON` and `enforce_gtid_consistency = ON` (for reliable failover/resume)
2. **Automated Backups Enabled:** `backup_retention_period >= 1` (e.g., `7` days from Task 5) — RDS MySQL disables binary logging if backup retention is `0`.
3. **Binlog Retention Hours** (RDS purges binlogs aggressively by default, so set at least 24 hours):
~~~sql
CALL mysql.rds_set_configuration('binlog retention hours', 24);
~~~

## 3. ClickHouse `fee_transactions` DDL (`ReplacingMergeTree`) & Updates/Deletes

~~~sql
-- 1. Kafka Engine source table (consumes Debezium JSON events from MSK)
CREATE TABLE kafka_fee_transactions (
    id              UInt64,
    student_id      UInt64,
    amount_paise    Int64,
    status          String,
    updated_at      DateTime64(3, 'UTC'),
    _is_deleted     UInt8,
    _version        UInt64
) ENGINE = Kafka
SETTINGS
    kafka_broker_list = 'b-1.icloudems-msk.kafka.ap-south-1.amazonaws.com:9092',
    kafka_topic_list = 'erp.icloudems.fee_transactions',
    kafka_group_name = 'ch_fee_transactions_cg',
    kafka_format = 'JSONEachRow';

-- 2. Final deduplicated storage table using ReplacingMergeTree
CREATE TABLE fee_transactions (
    id              UInt64,
    student_id      UInt64,
    amount_paise    Int64,
    status          String,
    updated_at      DateTime64(3, 'UTC'),
    _is_deleted     UInt8,
    _version        UInt64
) ENGINE = ReplacingMergeTree(_version, _is_deleted)
ORDER BY (id);

-- 3. Materialized View streaming from Kafka Engine -> ReplacingMergeTree
CREATE MATERIALIZED VIEW mv_fee_transactions TO fee_transactions AS
SELECT id, student_id, amount_paise, status, updated_at, _is_deleted, _version
FROM kafka_fee_transactions;
~~~

- **How Updates are handled:** Debezium emits a new row with the same `id` and a higher `_version` (binlog timestamp/LSN). `ReplacingMergeTree(_version, _is_deleted)` keeps only the row with the highest `_version` per `ORDER BY (id)` during background part merges.
- **How Deletes are handled:** Debezium's `ExtractNewRecordState` SMT converts a MySQL `DELETE` into a row with `_is_deleted = 1` and a higher `_version`. Analytics queries use `SELECT * FROM fee_transactions FINAL WHERE _is_deleted = 0` so deleted rows are excluded immediately even before merges complete.

## 4. Monitoring Replication Lag & 2-Hour Consumer Outage
- **Monitoring Lag:**
  1. **Amazon MSK / CloudWatch:** Track `MaxOffsetLag` / `SumOffsetLag` on consumer group `ch_fee_transactions_cg` (alert if lag > 60s or > 10,000 messages).
  2. **Debezium JMX / CloudWatch:** Alert if `MilliSecondsBehindSource > 30000` (30s).
  3. **End-to-End Heartbeat:** Write a heartbeat row in MySQL every 30s and alert if `now() - max(updated_at) > 60s` in ClickHouse.
- **What happens if the CDC consumer is down for 2 hours?**
  - **Zero data loss:** MSK retains Kafka topics on disk (e.g., 7 days), and RDS keeps binlogs for 24 hours (`binlog retention hours = 24`). While ClickHouse is down, Debezium keeps buffering events in MSK (or if Debezium is down, it resumes from its last committed binlog GTID/offset).
  - **Recovery:** When the consumer restarts, it reads from the last committed Kafka offset and drains the 2-hour backlog in parallel batches, causing a temporary CPU/I/O spike and background `ReplacingMergeTree` merges before returning to <1 minute lag.
