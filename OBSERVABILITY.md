# Observability — Content Pipeline

## Logging Architecture
Application → Docker → CloudWatch Agent → CloudWatch Logs

## Log Groups
- /content-pipeline/editorbot
- /content-pipeline/bootstrap
- /content-pipeline/ssm

## How to Debug
1. Check CloudWatch Logs
2. Filter by level=ERROR
3. Use Logs Insights

## Common Failures
- No logs → Agent not running
- Logs but no streams → IAM issue
- SSM works but no logs → wrong agent

## Verification Commands
- docker logs editorbot-editorbot-1
- amazon-cloudwatch-agent-ctl -a status
