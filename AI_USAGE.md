# AI Usage Log

## Tools Used
- **Gemini (Task Mode)** — Step-by-step AWS CLI, CloudShell, Git Bash, Docker, Jenkins, and architecture design assistance.

## Key Prompts Used
1. *"Walk through the iCloudEMS AWS Cloud Engineer assignment task-by-task using Git Bash, AWS CLI/CloudShell, GitHub, and GitLab."*
2. *"Create least-privilege IAM JSON policies for developers (s3:PutObject on answer-sheets/*), MFA enforcement, and EC2 S3 read role."*
3. *"Write a multi-stage Laravel Dockerfile (<300 MB, non-root), docker-compose.yml with MySQL/Redis, and a FastAPI /predict container."*
4. *"Write a declarative Jenkinsfile to checkout from GitLab, push commit-SHA images to ECR, and trigger an ASG instance refresh."*
5. *"Design near real-time CDC from RDS MySQL to ClickHouse using Debezium, Amazon MSK, and ReplacingMergeTree."*

## Manual Fixes & Adjustments Made
- **Git Bash CIDR & Path Handling:** Fixed empty `MY_IP` causing `/32` to expand to `C:/Program Files/Git/32` on Windows, and used `cygpath -m` for Windows AWS CLI JSON file paths.
- **Opt-In Region `ap-south-2`:** Enabled `ap-south-2` (Hyderabad) via `aws account enable-region` after encountering `InvalidToken` / `InvalidAccessKeyId` during Task 4 setup.
- **GitLab Protected `main` Branch:** Pushed updates to `develop` (`git push gitlab main:develop`) instead of `main` to respect branch protection.
- **Docker Non-Root Runtime:** Configured Nginx to listen on port `8080` and write PID/logs to `/tmp` so the container runs cleanly as non-root `appuser`.
