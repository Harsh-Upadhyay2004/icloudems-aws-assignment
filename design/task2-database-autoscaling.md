# Task 2: Database Auto Scaling (Design)

## 1. RDS Storage Autoscaling
- **How to enable:** In RDS Console (**Modify DB Instance → Storage → Enable storage autoscaling**) or via AWS CLI:
~~~bash
aws rds modify-db-instance \
  --db-instance-identifier icloudems-erp-db \
  --max-allocated-storage 500 \
  --apply-immediately
~~~
- **Max Storage Threshold & Why:** **500 GB** (assuming a 50–100 GB baseline).
  - Provides 5–10x headroom for result-day traffic spikes, MySQL binary logs (`binlog` required for Task 10 CDC), and temporary query tables without hitting `StorageFull` downtime.
  - Acts as a **cost guardrail** so runaway logs or uncleaned temporary tables cannot auto-scale storage unchecked toward the 64 TB limit.

## 2. Scaling Reads with Read Replicas & Laravel (`config/database.php`)
- **Read Replicas:** Provision one or more RDS MySQL Read Replicas in `ap-south-1` to offload heavy read workloads (exam result lookups, student dashboards, fee history) from the primary writer instance.
- **Laravel Read/Write Splitting (`config/database.php`):**
~~~php
'mysql' => [
    'driver' => 'mysql',
    'read' => [
        'host' => [
            env('DB_READ_HOST_1', 'icloudems-read-1.ap-south-1.rds.amazonaws.com'),
        ],
    ],
    'write' => [
        'host' => [
            env('DB_WRITE_HOST', 'icloudems-primary.ap-south-1.rds.amazonaws.com'),
        ],
    ],
    'sticky'    => true, // Reads go to writer for the rest of the request after a write, avoiding stale reads
    'port'      => env('DB_PORT', '3306'),
    'database'  => env('DB_DATABASE', 'icloudems_erp'),
    'username'  => env('DB_USERNAME'),
    'password'  => env('DB_PASSWORD'),
    'charset'   => 'utf8mb4',
    'collation' => 'utf8mb4_unicode_ci',
],
~~~

## 3. Moving to Aurora MySQL with Replica Auto Scaling
- **When to migrate:**
  - Result-day and admission spikes require adding/removing read replicas dynamically (RDS MySQL replicas are static and take 10–15+ minutes to provision).
  - You need >5 read replicas (Aurora supports up to 15 low-latency replicas sharing a single distributed storage volume) or sub-second failover.
  - Standard MySQL async replication lag exceeds acceptable SLAs under heavy write bursts.
- **Auto Scaling Policy:**
  - **Trigger Metric:** `RDSReaderAverageCPUUtilization` (Target Tracking Scaling Policy)
  - **Target Value:** **60%** average CPU across Aurora Reader instances (with min 1, max 5 readers, 300s scale-in cooldown).

## 4. Three CloudWatch Alarms & Thresholds
1. **`CPUUtilization` > 80%** for 3 consecutive 5-minute periods (15 min) — alerts before hitting 90%+ saturation and query timeouts.
2. **`FreeStorageSpace` < 10 GB** (or < 15% of allocated storage) — warns before storage autoscaling kicks in or if approaching `MaxAllocatedStorage`.
3. **`ReplicaLag` > 30 seconds** (and/or `DatabaseConnections` > 80% of `max_connections`) — catches replication delay before students see stale results or connection exhaustion.
