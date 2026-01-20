# Runbook — Content Pipeline + EditorBot

Date: 2026-01-20

## Scope
- Infrastructure repo: aws-content-pipeline/
- Application repo: editorbot-stack/ (submodules: editorBot, dialect_mediator)
- Control VM: EC2 t3.medium
- Storage: S3 versioned bucket
- Deploy: GitHub Actions → SSM Run Command

## Environments
- Region: eu-central-1
- Instance ID: i-0e6ef0bb4377ace52
- S3 bucket: content-pipeline-alpha-31a2ecea

## Secrets
### GitHub Actions (editorbot-stack repo)
- AWS_ACCESS_KEY_ID
- AWS_SECRET_ACCESS_KEY
- AWS_REGION
- EDITORBOT_INSTANCE_ID
- TOKEN_DEPLOY

### AWS SSM Parameter Store
- /editorbot/telegram_bot_token
- /editorbot/gemini_api_key

## Deploy (standard)
1) Push changes to editorbot-stack (and submodules first).
2) Trigger GitHub Actions → deploy workflow.
3) Verify workflow success.
4) Check logs:
   - CloudWatch Log Groups: /content-pipeline/bootstrap, /content-pipeline/editorbot

## Manual verification
- Instance check:
  - `docker ps`
  - `docker logs --tail 200 editorbot-editorbot-1`
  - `docker inspect --format '{{.State.Health.Status}}' editorbot-editorbot-1`

## Rollback
- Re-run deploy with previous git commit:
  - Reset editorbot-stack to a known good commit and push
  - Re-run deploy workflow

## Alerts
- CloudWatch alarms are configured for CPU and disk usage.
- Confirm the SNS email subscription sent to the alert address.

## Common failures
- SSM command fails: check SSM command output via `aws ssm get-command-invocation`.
- Git dubious ownership: ensure deploy script sets `safe.directory`.
- Git pull auth: ensure TOKEN_DEPLOY secret exists and remote is HTTPS with token.
- Gemini 403: key revoked; rotate SSM parameter.

## Contact / Ownership
- Owner: project maintainers
- Escalation: update docs/INTEGRATION_AUDIT.md
