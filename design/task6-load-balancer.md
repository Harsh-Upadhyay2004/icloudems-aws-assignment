# Task 6: Application Load Balancer Settings

## 1. Setup Summary (`icloudems-erp-alb`)
- **DNS:** `icloudems-erp-alb-1098774393.ap-south-1.elb.amazonaws.com` (multi-AZ: `ap-south-1a`, `ap-south-1b`)
- **Target Groups:**
  - `icloudems-web-tg`: `/health`, interval `15s`, healthy threshold `2`, unhealthy threshold `2`
  - `icloudems-api-tg`: `/health`, interval `15s`, healthy threshold `2`, path rule `/api/*` on HTTPS:443
- **HTTP → HTTPS Redirect:** Port `80` returns `301 Moved Permanently` to `HTTPS:443`.

## 2. ACM Certificate (Domain vs. No Domain)
- **In this lab (no custom domain):** Generated a self-signed TLS certificate with OpenSSL and imported it into AWS Certificate Manager (`aws acm import-certificate`) so the HTTPS:443 listener and 301 redirect work end-to-end.
- **With a real domain (production):**
  1. Request a public certificate in **ACM (`ap-south-1`)** for `erp.university.edu` and `*.erp.university.edu`.
  2. Choose **DNS validation** and add the ACM CNAME record in **Route 53** (or the university's DNS provider).
  3. Wait for status `Issued` (auto-renews before expiry) and attach it to the ALB `HTTPS:443` listener.

## 3. Session & Timeout Choices (Logged-in ERP Users)
- **Sticky Sessions (`lb_cookie`, 24h on `icloudems-web-tg`):**
  - Enabled so that if Laravel stores any local session state, a student's logged-in session stays pinned to the same EC2 instance instead of breaking across requests.
  - *Production improvement:* Store Laravel sessions in **Amazon ElastiCache (Redis)** (`SESSION_DRIVER=redis`), then **disable** sticky sessions so traffic balances evenly and scale-in never logs users out.
- **Idle Timeout (`120 seconds`, up from default `60s`):**
  - ERP tasks like generating PDF fee receipts, bulk admit cards, or mark-sheet exports can take >60s. Raising idle timeout to `120s` prevents premature `504 Gateway Timeout` errors while still closing abandoned connections reasonably fast.
- **Connection Draining / Deregistration Delay (`60 seconds`, down from default `300s`):**
  - Gives in-flight HTTP requests (like a fee payment callback) up to 60s to finish cleanly before an instance is removed during ASG scale-in or deployments, without stalling rollouts for a full 5 minutes.
