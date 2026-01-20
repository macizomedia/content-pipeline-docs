# Implementation Guide

## Current Deployment State

This document describes the **actual deployed system** as of January 2026.

This is not aspirational. This is what exists now.

---

## Deployed Infrastructure

### AWS Resources (Provisioned via Terraform)

**Region:** `eu-central-1`

**Control VM:**
- Instance type: `t3.medium`
- OS: Ubuntu 22.04 LTS
- Role: Orchestration, transcription, bot runtime
- Access: AWS SSM Session Manager only (no SSH)
- Bootstrap: `/var/lib/cloud/instance/scripts/part-001`

**Storage:**
- S3 bucket: `content-pipeline-<random-suffix>`
- Versioning: enabled
- Access: private, IAM-only
- Structure:
  ```
  s3://content-pipeline-*/
    audio/raw/
    audio/cleaned/
    scripts/
    subtitles/
    (video/ and images/ not actively used yet)
  ```

**IAM:**
- Control VM role: full S3 bucket access
- CI/CD credentials: scoped to SSM Run Command and S3 read

**Networking:**
- Security group: explicit IPv4/IPv6 allowlists for admin access
- No inbound SSH port (22 is closed)
- Outbound: unrestricted (required for Docker pulls, apt, LLM API)

**Logging:**
- CloudWatch log groups:
  - `/content-pipeline/bootstrap`
  - `/content-pipeline/editorbot`

---

## Deployed Application Services

### EditorBot Stack

**Repository:** `editorbot-stack` (GitHub)

**Submodules:**
- `editorBot` → https://github.com/macizomedia/editorBot.git
- `dialect_mediator` → https://github.com/macizomedia/dialect_mediator.git

**Runtime:**
- Docker Compose (`editorBot/docker-compose.yml`)
- Container name: `editorbot-editorbot-1`
- Managed by systemd service: `/etc/systemd/system/editorbot.service`

**Dependencies:**
- Python 3.10+
- Whisper (local, CPU-based transcription)
- Google Gemini API (dialect mediation)
- boto3 (S3 I/O)
- python-telegram-bot

**Environment Variables:**
Injected at runtime from AWS SSM Parameter Store:
- `/editorbot/telegram_bot_token`
- `/editorbot/gemini_api_key`

**Current Capabilities:**
- Accepts voice messages via Telegram
- Transcribes audio using Whisper (local model)
- Mediates text via Google Gemini 1.5 Flash
- Generates structured scripts
- Writes artifacts to S3
- Notifies user via Telegram

**Not Yet Implemented:**
- Image generation
- Video assembly
- Multi-format export

---

## Operational Procedures

### Accessing the Control VM

**Via SSM Session Manager:**
```bash
aws ssm start-session --target <INSTANCE_ID> --region eu-central-1
```

**No SSH access is configured.**

If you need to inspect logs:
```bash
# On the instance
sudo journalctl -u editorbot -f
docker logs editorbot-editorbot-1 -f
```

---

### Deploying Application Updates

**Automated (via GitHub Actions):**

1. Push changes to `editorbot-stack` main branch
2. Workflow `.github/workflows/deploy.yml` triggers
3. SSM Run Command executes on control VM:
   ```bash
   cd /home/ubuntu/editorbot
   git pull origin main
   git submodule update --init --recursive
   docker compose -f editorBot/docker-compose.yml down
   docker compose -f editorBot/docker-compose.yml up -d --build
   ```
4. Check CloudWatch logs for startup confirmation

**Manual (via SSM):**

If automation fails, you can run commands directly:
```bash
aws ssm send-command \
  --instance-ids <INSTANCE_ID> \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/ubuntu/editorbot && git pull"]' \
  --region eu-central-1
```

Retrieve output:
```bash
aws ssm get-command-invocation \
  --command-id <COMMAND_ID> \
  --instance-id <INSTANCE_ID> \
  --region eu-central-1
```

---

### Rotating Secrets

**Telegram Bot Token:**
1. Generate new token via BotFather
2. Update SSM parameter:
   ```bash
   aws ssm put-parameter \
     --name /editorbot/telegram_bot_token \
     --value "NEW_TOKEN" \
     --overwrite \
     --region eu-central-1
   ```
3. Restart service:
   ```bash
   aws ssm send-command \
     --instance-ids <INSTANCE_ID> \
     --document-name "AWS-RunShellScript" \
     --parameters 'commands=["sudo systemctl restart editorbot"]' \
     --region eu-central-1
   ```

**Gemini API Key:**
Same process, parameter name: `/editorbot/gemini_api_key`

---

### Updating Terraform Infrastructure

**Local workflow:**
```bash
cd aws-content-pipeline
terraform fmt
terraform validate
terraform plan
terraform apply
```

**State is stored remotely in S3 + DynamoDB.**

**Critical variables:**
- `content_bucket_name` (must be globally unique)
- `admin_ipv4_cidr_blocks` (your IP for emergency access)
- `admin_ipv6_cidr_blocks` (optional)
- `editorbot_env_mode` (set to `ssm` for production)

**After infrastructure changes:**
- If user_data changed, terminate and recreate instance
- If security group changed, no instance restart needed

---

## Known Limitations & Workarounds

### Bootstrap Script Failures

**Symptom:** Instance boots but EditorBot doesn't start automatically.

**Cause:** Bootstrap script (`part-001`) failed due to non-empty directory or submodule fetch errors.

**Fix:**
1. SSH via SSM
2. Manually run:
   ```bash
   cd /home/ubuntu
   rm -rf editorbot
   git clone --recurse-submodules https://github.com/macizomedia/editorbot-stack.git editorbot
   cd editorbot/editorBot
   docker compose up -d --build
   ```
3. Verify systemd service:
   ```bash
   sudo systemctl status editorbot
   ```

---

### Submodule Commit Not Found

**Symptom:** `git submodule update` fails with "reference not found".

**Cause:** Parent repo references a submodule commit SHA that hasn't been pushed.

**Fix:**
1. Navigate to submodule directory (`editorBot/` or `dialect_mediator/`)
2. Push the missing commit:
   ```bash
   git push origin main
   ```
3. Update parent repo:
   ```bash
   cd /home/ubuntu/editorbot
   git submodule update --init --recursive
   ```

---

### Gemini API 403 Errors

**Symptom:** Bot responds with "Mediation failed".

**Cause:** API key revoked or quota exceeded.

**Fix:**
1. Verify key validity in Google Cloud Console
2. Generate new key if needed
3. Update SSM parameter (see "Rotating Secrets")
4. Restart service

---

### Whisper Transcription Timeout

**Symptom:** Long audio files fail to transcribe.

**Cause:** CPU-bound transcription on t3.medium takes time.

**Workaround:**
- Use shorter audio clips (<5 minutes)
- OR provision larger instance (t3.large)
- OR add GPU layer for Whisper (future enhancement)

---

## Monitoring & Observability

### CloudWatch Logs

**Bootstrap logs:**
```bash
aws logs tail /content-pipeline/bootstrap --follow --region eu-central-1
```

**Application logs:**
```bash
aws logs tail /content-pipeline/editorbot --follow --region eu-central-1
```

**No automated alerting is configured.**

---

### Health Checks

**Manual verification:**
1. Send test voice message to Telegram bot
2. Verify transcription response
3. Check S3 for new artifacts:
   ```bash
   aws s3 ls s3://content-pipeline-<suffix>/audio/raw/
   ```

**No automated health checks exist.**

---

## Cost Profile

**Current monthly estimate (eu-central-1):**
- t3.medium (24/7): ~$30/month
- S3 storage (< 1GB): ~$0.02/month
- CloudWatch logs: ~$1/month
- Data transfer: ~$1/month
- Gemini API (Flash): ~$0.50/month (usage-based)

**Total: ~$33/month**

**GPU layer (when implemented):**
- g4dn.xlarge: ~$0.526/hour (on-demand)
- Expected usage: <10 hours/month = ~$5/month

**Projected total with GPU: ~$38/month**

---

## Disaster Recovery

### Backup Strategy

**S3 bucket:** versioning enabled, objects are recoverable.

**Application code:** version-controlled in GitHub.

**Secrets:** stored in SSM Parameter Store (not backed up automatically).

**Recommendation:**
- Export SSM parameters monthly:
  ```bash
  aws ssm get-parameters-by-path \
    --path /editorbot \
    --with-decryption \
    --region eu-central-1 > editorbot-secrets-backup.json
  ```
- Store encrypted backup locally (NOT in Git)

---

### Instance Recreation

If the control VM is lost:

1. Run Terraform apply (provisions new instance)
2. Bootstrap script runs automatically
3. Restore SSM parameters (if needed)
4. Trigger deployment workflow

**Total recovery time: <15 minutes**

---

## Troubleshooting Checklist

**Bot not responding:**
- [ ] Check systemd: `sudo systemctl status editorbot`
- [ ] Check container: `docker ps`
- [ ] Check logs: `docker logs editorbot-editorbot-1`
- [ ] Verify Telegram token in SSM

**Transcription failures:**
- [ ] Check Whisper model installed
- [ ] Verify audio file format (WAV, MP3 supported)
- [ ] Check CPU load: `htop`

**S3 write failures:**
- [ ] Verify IAM role attached to instance
- [ ] Check bucket name in environment variables
- [ ] Test boto3 access: `aws s3 ls` (from instance)

**Deployment failures:**
- [ ] Verify GitHub Actions secrets
- [ ] Check SSM command output
- [ ] Verify instance ID in workflow

---

## Future Implementation Tasks

These are **not yet deployed**:

### GPU Burst Layer
- Terraform module for g4dn.xlarge
- AUTOMATIC1111 Stable Diffusion container
- Image generation API integration

### Video Assembly Pipeline
- FFmpeg + MoviePy integration
- Subtitle burning
- Multi-format export (9:16, 16:9)

### Automation Enhancements
- CloudWatch alarms
- Auto-restart on service failure
- Cost budgets and alerts

---

## References

**Related Documentation:**
- [ARCHITECTURE.md](ARCHITECTURE.md) — Design principles
- [SPECIFICATIONS.md](SPECIFICATIONS.md) — Original requirements
- [README.md](README.md) — Documentation overview

**External Resources:**
- AWS SSM documentation
- Terraform AWS provider docs
- Whisper model documentation

---

**Last Updated:** January 2026
**Status:** Operational (limited feature set)
