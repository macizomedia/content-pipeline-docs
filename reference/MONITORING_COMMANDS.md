# Monitoring Commands Reference

Quick reference for checking infrastructure and application state.

---

## 🔧 Shell Aliases

Add these to your `~/.zshrc` for quick access:

```bash
# =============================================================================
# Content Pipeline Monitoring Aliases
# =============================================================================

# Terraform Status
alias tf-status='cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline && terraform show'
alias tf-state='cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline && terraform state list'
alias tf-output='cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline && terraform output'
alias tf-plan='cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline && terraform plan'
alias tf-refresh='cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline && terraform refresh'

# AWS EC2 Instance Status
alias aws-instance='aws ec2 describe-instances --region eu-central-1 --filters "Name=tag:Name,Values=content-pipeline-control-vm" --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress]" --output table'
alias aws-instance-full='aws ec2 describe-instances --region eu-central-1 --filters "Name=tag:Name,Values=content-pipeline-control-vm" --output json | jq'

# AWS S3 Bucket
alias aws-s3-list='aws s3 ls --region eu-central-1 | grep content-pipeline'
alias aws-s3-usage='aws s3 ls s3://$(aws s3 ls --region eu-central-1 | grep content-pipeline | awk "{print \$3}") --recursive --summarize --human-readable'
alias aws-s3-recent='aws s3 ls s3://$(aws s3 ls --region eu-central-1 | grep content-pipeline | awk "{print \$3}")/audio/raw/ --recursive --human-readable | tail -10'

# AWS CloudWatch Logs
alias aws-logs-bootstrap='aws logs tail /content-pipeline/bootstrap --follow --region eu-central-1'
alias aws-logs-editorbot='aws logs tail /content-pipeline/editorbot --follow --region eu-central-1'
alias aws-logs-recent='aws logs tail /content-pipeline/editorbot --since 1h --region eu-central-1'

# AWS SSM (Secrets)
alias aws-ssm-list='aws ssm describe-parameters --region eu-central-1 --filters "Key=Name,Values=/editorbot/" --query "Parameters[*].Name" --output table'
alias aws-ssm-age='aws ssm describe-parameters --region eu-central-1 --filters "Key=Name,Values=/editorbot/" --query "Parameters[*].[Name,LastModifiedDate]" --output table'

# AWS SSM Session
alias aws-ssh='aws ssm start-session --target $(terraform -chdir=~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline output -raw instance_id) --region eu-central-1'

# Docker Status (run after SSM session)
alias docker-status='docker ps -a'
alias docker-logs='docker logs editorbot-editorbot-1 --tail 100 -f'
alias docker-inspect='docker inspect editorbot-editorbot-1 | jq'

# GitHub Actions
alias gh-actions='gh run list --repo macizomedia/editorbot-stack --limit 10'
alias gh-actions-watch='gh run watch --repo macizomedia/editorbot-stack'
alias gh-actions-infra='gh run list --repo macizomedia/aws-content-pipeline --limit 10'

# Git Status (all repos)
alias git-status-all='echo "=== aws-content-pipeline ===" && cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline && git status -sb && echo "\n=== editorbot-stack ===" && cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/editorbot-stack && git status -sb && echo "\n=== content-pipeline-docs ===" && cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/content-pipeline-docs && git status -sb'

# Quick Health Check
alias pipeline-health='echo "=== Terraform State ===" && cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline && terraform output -json | jq -r "{instance_id, bucket_name}" && echo "\n=== AWS Instance ===" && aws ec2 describe-instances --region eu-central-1 --instance-ids $(terraform output -raw instance_id) --query "Reservations[0].Instances[0].State.Name" --output text && echo "\n=== Recent Logs ===" && aws logs tail /content-pipeline/editorbot --since 5m --region eu-central-1 | tail -5'
```

---

## 📋 Quick Commands

### Check Everything

```bash
# One-liner to check entire pipeline health
pipeline-health
```

### Terraform State

```bash
# List all managed resources
terraform state list

# Show specific resource
terraform state show aws_instance.control_vm

# Get outputs
terraform output

# Refresh state from AWS
terraform refresh
```

### AWS Instance

```bash
# Instance status
aws ec2 describe-instances \
  --region eu-central-1 \
  --filters "Name=tag:Name,Values=content-pipeline-control-vm" \
  --query "Reservations[0].Instances[0].[InstanceId,State.Name,InstanceType,LaunchTime]" \
  --output table

# Get instance ID
aws ec2 describe-instances \
  --region eu-central-1 \
  --filters "Name=tag:Name,Values=content-pipeline-control-vm" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text

# Instance metrics (CPU, Network)
aws cloudwatch get-metric-statistics \
  --region eu-central-1 \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$(terraform output -raw instance_id) \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average
```

### S3 Bucket

```bash
# List all content
aws s3 ls s3://$(aws s3 ls | grep content-pipeline | awk '{print $3}') --recursive

# Check specific folders
aws s3 ls s3://$(aws s3 ls | grep content-pipeline | awk '{print $3}')/audio/raw/
aws s3 ls s3://$(aws s3 ls | grep content-pipeline | awk '{print $3}')/scripts/

# Bucket size and object count
aws s3 ls s3://$(aws s3 ls | grep content-pipeline | awk '{print $3}') \
  --recursive --summarize --human-readable | tail -2

# Recent uploads (last 24h)
aws s3api list-objects-v2 \
  --bucket $(aws s3 ls | grep content-pipeline | awk '{print $3}') \
  --query "Contents[?LastModified>='$(date -u -v-1d +%Y-%m-%d)'].{Key:Key,Size:Size,Modified:LastModified}" \
  --output table
```

### CloudWatch Logs

```bash
# Tail logs (real-time)
aws logs tail /content-pipeline/editorbot --follow --region eu-central-1

# Last hour
aws logs tail /content-pipeline/editorbot --since 1h --region eu-central-1

# Filter errors
aws logs filter-log-events \
  --region eu-central-1 \
  --log-group-name /content-pipeline/editorbot \
  --filter-pattern "ERROR" \
  --start-time $(($(date +%s) - 3600))000

# Get log streams
aws logs describe-log-streams \
  --region eu-central-1 \
  --log-group-name /content-pipeline/editorbot \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

### SSM Parameters (Secrets)

```bash
# List all editorbot parameters
aws ssm describe-parameters \
  --region eu-central-1 \
  --filters "Key=Name,Values=/editorbot/" \
  --query "Parameters[*].[Name,LastModifiedDate,Type]" \
  --output table

# Check when secrets were last updated
aws ssm describe-parameters \
  --region eu-central-1 \
  --parameter-filters "Key=Name,Values=/editorbot/" \
  --query "Parameters[*].[Name,LastModifiedDate]" \
  --output table

# Get parameter value (use carefully, prints secret!)
aws ssm get-parameter \
  --region eu-central-1 \
  --name /editorbot/telegram_bot_token \
  --with-decryption \
  --query "Parameter.Value" \
  --output text
```

### SSM Session (SSH Alternative)

```bash
# Start session
aws ssm start-session \
  --target $(terraform output -raw instance_id) \
  --region eu-central-1

# Once inside, useful commands:
docker ps                                    # Check container status
docker logs editorbot-editorbot-1 --tail 50  # View logs
sudo journalctl -u editorbot -n 50           # View systemd logs
docker stats                                 # Resource usage
df -h                                        # Disk usage
free -h                                      # Memory usage
```

### Docker (Inside SSM Session)

```bash
# Container status
docker ps -a

# View logs
docker logs editorbot-editorbot-1 --tail 100 -f

# Inspect container
docker inspect editorbot-editorbot-1

# Container stats
docker stats editorbot-editorbot-1 --no-stream

# Restart container
docker compose -f ~/editorbot/editorBot/docker-compose.yml restart

# View environment variables
docker exec editorbot-editorbot-1 env | grep -E "TELEGRAM|GEMINI|WHISPER"
```

### GitHub Actions

```bash
# List recent workflow runs
gh run list --repo macizomedia/editorbot-stack --limit 10

# Watch current run
gh run watch --repo macizomedia/editorbot-stack

# View specific run
gh run view <run-id> --repo macizomedia/editorbot-stack

# View logs
gh run view <run-id> --log --repo macizomedia/editorbot-stack

# List workflows
gh workflow list --repo macizomedia/editorbot-stack

# Trigger manual deploy
gh workflow run deploy.yml --repo macizomedia/editorbot-stack
```

### Cost Monitoring

```bash
# Current month costs (requires AWS Cost Explorer enabled)
aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-01),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "UnblendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE \
  --region us-east-1

# EC2 running hours this month
aws cloudwatch get-metric-statistics \
  --region eu-central-1 \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$(terraform output -raw instance_id) \
  --start-time $(date +%Y-%m-01T00:00:00) \
  --end-time $(date +%Y-%m-%dT23:59:59) \
  --period 86400 \
  --statistics SampleCount
```

---

## 🚀 Installation

Add aliases to your shell:

```bash
# Append to ~/.zshrc
cat >> ~/.zshrc << 'EOF'

# Content Pipeline Aliases
source ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/content-pipeline-docs/reference/aliases.sh

EOF

# Reload shell
source ~/.zshrc
```

---

## 📊 Monitoring Dashboard (Terminal)

Create a simple monitoring script:

```bash
#!/bin/bash
# ~/bin/pipeline-monitor.sh

clear
echo "==================================="
echo "   Content Pipeline Status"
echo "==================================="
echo

echo "📦 Terraform State:"
cd ~/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1/aws-content-pipeline
terraform output -json | jq -r '{instance_id, bucket_name, region}'
echo

echo "🖥️  EC2 Instance:"
INSTANCE_ID=$(terraform output -raw instance_id)
aws ec2 describe-instances --region eu-central-1 --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].[State.Name,InstanceType,LaunchTime]' \
  --output text
echo

echo "📊 Recent Logs (last 5 minutes):"
aws logs tail /content-pipeline/editorbot --since 5m --region eu-central-1 | tail -5
echo

echo "💾 S3 Storage:"
aws s3 ls s3://$(aws s3 ls | grep content-pipeline | awk '{print $3}') \
  --recursive --summarize --human-readable | tail -2
echo

echo "🚀 GitHub Actions (last 3 runs):"
gh run list --repo macizomedia/editorbot-stack --limit 3
echo

echo "==================================="
echo "Run 'pipeline-health' for quick check"
echo "Run 'aws-logs-editorbot' for live logs"
echo "==================================="
```

Make it executable:
```bash
chmod +x ~/bin/pipeline-monitor.sh
```

Add alias:
```bash
alias pipeline-monitor='~/bin/pipeline-monitor.sh'
```

---

## 🔍 Troubleshooting Commands

```bash
# Check if container is running
docker ps | grep editorbot

# Check systemd service
sudo systemctl status editorbot

# Check container health
docker inspect editorbot-editorbot-1 --format='{{.State.Health.Status}}'

# View all environment variables
docker exec editorbot-editorbot-1 env

# Check disk space
df -h /

# Check memory
free -h

# Check recent system logs
sudo journalctl -n 100 --no-pager

# Test S3 access from instance
aws s3 ls s3://$(aws s3 ls | grep content-pipeline | awk '{print $3}')/

# Test SSM parameter access
aws ssm get-parameter --name /editorbot/telegram_bot_token --region eu-central-1
```

---

**Last Updated:** January 2026
