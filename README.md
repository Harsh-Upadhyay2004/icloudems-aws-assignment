# iCloudEMS – AWS Cloud Engineer (AI) Technical Assignment

Production AWS architecture, security, CI/CD, Docker, and CDC design for the iCloudEMS university ERP (Laravel/PHP) in `ap-south-1` (Mumbai) with DR in `ap-south-2` (Hyderabad).

## What Was Built & Verified
- **Task 1 (EC2 Auto Scaling):** Launch template `icloudems-erp-lt` (Ubuntu 22.04, `t3.micro`, Docker + `stress-ng`), multi-AZ ASG `icloudems-erp-asg` (min 1, desired 2, max 4), 60% CPU target tracking, 8:00 AM IST (`30 2 * * *` UTC) scheduled action, and scale-out verified via `stress-ng` (`screenshots/task1-asg-scale-out.png`).
- **Task 2 (Database Auto Scaling):** Design doc in `design/task2-database-autoscaling.md` covering RDS storage autoscaling, Laravel `config/database.php` read/write splitting, Aurora MySQL triggers, and CloudWatch alarms.
- **Task 3 (IAM & Security):** Strong password policy, 3 least-privilege IAM groups (`icloudems-developers`, `icloudems-devops`, `icloudems-auditors`), 4 users, MFA enforcement policy, EC2 S3-read IAM role, custom `s3:PutObject` policy (`iam/`), and locked-down Security Groups (`ALB -> EC2 -> RDS`).
- **Task 4 (S3 Replication):** `ap-south-1` -> `ap-south-2` Cross-Region Replication filtered to `answer-sheets/`, versioning, SSE-S3 encryption, public access blocked, 180-day Glacier lifecycle rule, and replicated file verified (`screenshots/task4-s3-replication.png`).
- **Task 5 (Snapshot Handling):** DLM policy (7 daily, 4 weekly), RDS 7-day backup vs. manual snapshot analysis, PITR steps (`design/task5-snapshot-handling.md`), and `scripts/copy_latest_rds_snapshot.sh`.
- **Task 6 (Load Balancer):** ALB `icloudems-erp-alb` with `/health` target groups, `/api/*` path rule, imported ACM cert with HTTP:80 -> HTTPS:443 redirect, sticky sessions, 120s idle timeout, and 60s draining (`design/task6-load-balancer.md`, `screenshots/task6-alb.png`).
- **Task 7 (GitLab):** Repo with `main` (protected, MR required), `develop`, and `feature/erp-docker`, masked/protected AWS CI/CD variables, and `ci/.gitlab-ci.yml`.
- **Task 8 (Jenkins):** Declarative `ci/Jenkinsfile` (GitLab -> Docker build -> ECR push -> ASG Instance Refresh), ECR repo `icloudems-erp`, and `icloudems-jenkins-role` created. *Incomplete due to time:* Jenkins UI pipeline job run and screenshot; next step is creating the Pipeline job in Jenkins UI pointing to `ci/Jenkinsfile` on `develop` and running Build Now.
- **Task 9 (Docker + AI Bonus):** Multi-stage Alpine `docker/Dockerfile` (non-root `appuser`, <300 MB), `docker/docker-compose.yml` (app, MySQL, Redis, FastAPI), and `docker/ai-service/` exposing `/predict` (verified returning `POSITIVE` sentiment).
- **Task 10 (CDC RDS to ClickHouse):** Architecture diagram, RDS `binlog_format=ROW` & retention settings, `ReplacingMergeTree` DDL, and lag/outage handling in `design/task10-cdc-rds-clickhouse.md`.

## Assumptions
- Used a self-signed certificate imported into ACM for HTTPS/redirect testing because no custom domain was attached.
- Design tasks (2, 5, 10) were documented without provisioning paid RDS/MSK/ClickHouse clusters.
