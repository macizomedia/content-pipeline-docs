# EditorBot Debugging Guide

## Quick Reference: How to Debug Production Errors

### 1. Access CloudWatch Logs

#### Option A: AWS Console
```bash
# Navigate to:
CloudWatch → Logs → Log groups → /content-pipeline/editorbot
```

#### Option B: AWS CLI (Recommended)
```bash
# List recent log streams
aws logs describe-log-streams \
  --log-group-name /content-pipeline/editorbot \
  --order-by LastEventTime \
  --descending \
  --max-items 5 \
  --region eu-central-1

# Get the latest stream name and fetch logs
STREAM_NAME=$(aws logs describe-log-streams \
  --log-group-name /content-pipeline/editorbot \
  --order-by LastEventTime \
  --descending \
  --max-items 1 \
  --region eu-central-1 \
  --query 'logStreams[0].logStreamName' \
  --output text)

# Tail logs from the last 10 minutes
aws logs tail /content-pipeline/editorbot \
  --follow \
  --since 10m \
  --region eu-central-1

# Or get specific stream logs
aws logs get-log-events \
  --log-group-name /content-pipeline/editorbot \
  --log-stream-name "$STREAM_NAME" \
  --limit 100 \
  --region eu-central-1 \
  --output json | jq -r '.events[].message'
```

### 2. Understand the HF Hub Warning

**Warning Message:**
```
Warning: You are sending unauthenticated requests to the HF Hub.
Please set a HF_TOKEN to enable higher rate limits and faster downloads.
```

**Context:**
- This appears when Whisper downloads models from Hugging Face Hub
- It's a **WARNING**, not an error
- Transcriptions still work, just with lower rate limits
- If transcriptions completed, this is NOT your error

**To suppress it (optional):**
```bash
# Add to docker-compose.yml environment section:
- HF_TOKEN=${HF_TOKEN:-}
```

### 3. Find the Real Error

CloudWatch logs are **double-nested JSON** (Docker logs wrapped in CloudWatch envelope):
```json
{"log":"{\"ts\": \"...\", \"level\": \"INFO\", ...}\n", "stream":"stderr", "time":"..."}
```

Look for:

#### A. Filter by severity
```bash
# Get only ERROR level messages (simple grep)
aws logs tail /content-pipeline/editorbot \
  --since 30m \
  --region eu-central-1 \
  | grep 'level.*ERROR'

# Pretty-print ERROR messages (unwrap double JSON)
aws logs tail /content-pipeline/editorbot \
  --since 30m \
  --region eu-central-1 \
  | jq -r '.message | fromjson | select(.level == "ERROR") | "\(.ts) [\(.level)] \(.logger): \(.message)"'
```

#### B. Filter by component
```bash
# Template logs (simple)
aws logs tail /content-pipeline/editorbot --since 30m --region eu-central-1 \
  | grep -i template

# Transcription logs
aws logs tail /content-pipeline/editorbot --since 30m --region eu-central-1 \
  | grep -i transcription

# Mediator logs
aws logs tail /content-pipeline/editorbot --since 30m --region eu-central-1 \
  | grep -i mediator

# Pretty-print template logs (unwrap JSON)
aws logs tail /content-pipeline/editorbot --since 30m --region eu-central-1 \
  | jq -r '.message | fromjson | select(.logger | contains("template")) | "\(.ts) \(.logger): \(.message)"'
```

#### C. Look for exceptions
```bash
# Find stack traces
aws logs tail /content-pipeline/editorbot --since 30m --region eu-central-1 \
  | grep -i "traceback\|exception\|error:"
```

### 4. Check Container Status

```bash
# SSH via SSM (no inbound ports needed)
aws ssm start-session --target <INSTANCE_ID> --region eu-central-1

# Once inside:
sudo docker ps
sudo docker logs editorbot-editorbot-1 --tail 100
sudo docker logs editorbot-editorbot-1 --follow

# Check if container keeps restarting
sudo docker inspect editorbot-editorbot-1 | jq '.[0].State'
```

### 5. Common Error Patterns

#### Template API Errors
```json
{
  "level": "ERROR",
  "logger": "bot.templates",
  "message": "Failed to fetch template: 403"
}
```
**Fix:** Check Lambda API permissions or template names

#### Transcription Errors
```json
{
  "level": "ERROR",
  "logger": "bot.transcription",
  "message": "Whisper model download failed"
}
```
**Fix:** Check disk space and network connectivity

#### Mediator Errors
```json
{
  "level": "ERROR",
  "logger": "dialect_mediator",
  "message": "Gemini API returned 403"
}
```
**Fix:** Rotate Gemini API key

### 6. Enable Debug Mode

```bash
# Update docker-compose.yml on instance
LOG_LEVEL=DEBUG

# Restart container
sudo docker compose -f /home/ubuntu/editorbot/editorBot/docker-compose.yml restart
```

### 7. Replay Recent Interactions

```bash
# Find user interactions (simple grep)
aws logs tail /content-pipeline/editorbot --since 1h --region eu-central-1 \
  | grep -E "received|selected|processing|completed"

# Pretty-print with timestamps (unwrap JSON)
aws logs tail /content-pipeline/editorbot --since 1h --region eu-central-1 \
  | jq -r '.message | fromjson | "\(.ts) [\(.logger)]: \(.message)"'
```

### 8. Health Check

```bash
# From instance
curl -f http://localhost:8080/health || echo "Bot not responding"

# Or via Docker
sudo docker exec editorbot-editorbot-1 python -c "import bot; print('Bot module OK')"
```

---

## Structured Log Format

All logs follow this schema:

```json
{
  "ts": "2026-01-24T10:30:00.123456Z",
  "level": "INFO|WARNING|ERROR",
  "service": "editorbot",
  "logger": "bot.transcription",
  "message": "Human-readable message"
}
```

**Log Levels:**
- `DEBUG`: Detailed diagnostic info
- `INFO`: Normal operation milestones
- `WARNING`: Recoverable issues (like HF Hub warning)
- `ERROR`: Operation failures requiring attention

---

## When Things Go Wrong

### Scenario 1: "Script selected but no response"
1. Check CloudWatch for template fetch errors
2. Verify Lambda API is responding
3. Check Gemini API key hasn't been revoked

### Scenario 2: "Transcription never completes"
1. Check audio file size (> 25MB fails)
2. Verify Whisper model is cached (`/home/ubuntu/.cache/huggingface`)
3. Check disk space: `df -h`

### Scenario 3: "Container keeps restarting"
1. Check for env var issues: `sudo docker logs editorbot-editorbot-1`
2. Verify SSM parameters exist
3. Check bootstrap script ran successfully

---

## Emergency Commands

```bash
# Force rebuild
cd /home/ubuntu/editorbot
sudo docker compose down
sudo docker compose build --no-cache
sudo docker compose up -d

# Rotate API key emergency
aws ssm put-parameter \
  --name /editorbot/gemini_api_key \
  --value "NEW_KEY" \
  --type SecureString \
  --overwrite \
  --region eu-central-1

# Clear Whisper cache if corrupted
sudo rm -rf /home/ubuntu/.cache/huggingface
sudo docker compose restart
```

---

## Next Steps

1. **Identify the error** using CloudWatch filters above
2. **Share the actual error message** (not just warnings)
3. **Check the timestamp** to correlate with your interaction
4. **Review component-specific logs** for the failing service

**Remember:** HF Hub warning ≠ actual error. Look for ERROR level messages.
