#!/bin/bash
# Content Pipeline Monitoring Aliases
# Source this file in your ~/.zshrc: source /path/to/aliases.sh

# =============================================================================
# Configuration
# =============================================================================
export PIPELINE_ROOT="$HOME/Documents/BLAS/PRODUCTION/DIALECT_BOT_TERRAFORM_AWS_V1"
export PIPELINE_REGION="eu-central-1"

# =============================================================================
# Terraform Aliases
# =============================================================================
alias tf-status='cd $PIPELINE_ROOT/aws-content-pipeline && terraform show'
alias tf-state='cd $PIPELINE_ROOT/aws-content-pipeline && terraform state list'
alias tf-output='cd $PIPELINE_ROOT/aws-content-pipeline && terraform output'
alias tf-plan='cd $PIPELINE_ROOT/aws-content-pipeline && terraform plan'
alias tf-refresh='cd $PIPELINE_ROOT/aws-content-pipeline && terraform refresh'
alias tf-validate='cd $PIPELINE_ROOT/aws-content-pipeline && terraform validate'

# =============================================================================
# AWS EC2 Aliases
# =============================================================================
alias aws-instance='aws ec2 describe-instances --region $PIPELINE_REGION --filters "Name=tag:Name,Values=content-pipeline-control-vm" --query "Reservations[0].Instances[0].[InstanceId,State.Name,PublicIpAddress,PrivateIpAddress,InstanceType]" --output table'

alias aws-instance-id='aws ec2 describe-instances --region $PIPELINE_REGION --filters "Name=tag:Name,Values=content-pipeline-control-vm" --query "Reservations[0].Instances[0].InstanceId" --output text'

alias aws-instance-ip='aws ec2 describe-instances --region $PIPELINE_REGION --filters "Name=tag:Name,Values=content-pipeline-control-vm" --query "Reservations[0].Instances[0].PublicIpAddress" --output text'

alias aws-instance-state='aws ec2 describe-instances --region $PIPELINE_REGION --filters "Name=tag:Name,Values=content-pipeline-control-vm" --query "Reservations[0].Instances[0].State.Name" --output text'

# =============================================================================
# AWS S3 Aliases
# =============================================================================
alias aws-s3-bucket='aws s3 ls --region $PIPELINE_REGION | grep content-pipeline | awk "{print \$3}"'

alias aws-s3-list='aws s3 ls s3://$(aws-s3-bucket) --recursive --human-readable'

alias aws-s3-usage='aws s3 ls s3://$(aws-s3-bucket) --recursive --summarize --human-readable | tail -2'

alias aws-s3-audio='aws s3 ls s3://$(aws-s3-bucket)/audio/raw/ --recursive --human-readable'

alias aws-s3-scripts='aws s3 ls s3://$(aws-s3-bucket)/scripts/ --recursive --human-readable'

alias aws-s3-recent='aws s3 ls s3://$(aws-s3-bucket) --recursive --human-readable | sort -k1,2 | tail -10'

# =============================================================================
# AWS CloudWatch Logs Aliases
# =============================================================================
alias aws-logs-bootstrap='aws logs tail /content-pipeline/bootstrap --follow --region $PIPELINE_REGION'

alias aws-logs-editorbot='aws logs tail /content-pipeline/editorbot --follow --region $PIPELINE_REGION'

alias aws-logs-recent='aws logs tail /content-pipeline/editorbot --since 1h --region $PIPELINE_REGION'

alias aws-logs-errors='aws logs filter-log-events --region $PIPELINE_REGION --log-group-name /content-pipeline/editorbot --filter-pattern "ERROR" --start-time $(($(date +%s) - 3600))000'

# =============================================================================
# AWS SSM Aliases
# =============================================================================
alias aws-ssm-list='aws ssm describe-parameters --region $PIPELINE_REGION --filters "Key=Name,Values=/editorbot/" --query "Parameters[*].Name" --output table'

alias aws-ssm-age='aws ssm describe-parameters --region $PIPELINE_REGION --filters "Key=Name,Values=/editorbot/" --query "Parameters[*].[Name,LastModifiedDate]" --output table'

alias aws-ssh='aws ssm start-session --target $(cd $PIPELINE_ROOT/aws-content-pipeline && terraform output -raw instance_id) --region $PIPELINE_REGION'

# =============================================================================
# GitHub Actions Aliases
# =============================================================================
alias gh-actions='gh run list --repo macizomedia/editorbot-stack --limit 10'

alias gh-actions-watch='gh run watch --repo macizomedia/editorbot-stack'

alias gh-actions-infra='gh run list --repo macizomedia/aws-content-pipeline --limit 10'

alias gh-actions-docs='gh run list --repo macizomedia/content-pipeline-docs --limit 10'

alias gh-deploy='gh workflow run deploy.yml --repo macizomedia/editorbot-stack'

# =============================================================================
# Git Aliases
# =============================================================================
alias git-status-all='
  echo "=== aws-content-pipeline ===" && 
  cd $PIPELINE_ROOT/aws-content-pipeline && git status -sb && 
  echo "\n=== editorbot-stack ===" && 
  cd $PIPELINE_ROOT/editorbot-stack && git status -sb && 
  echo "\n=== content-pipeline-docs ===" && 
  cd $PIPELINE_ROOT/content-pipeline-docs && git status -sb
'

alias git-pull-all='
  cd $PIPELINE_ROOT/aws-content-pipeline && git pull && 
  cd $PIPELINE_ROOT/editorbot-stack && git pull && 
  cd $PIPELINE_ROOT/content-pipeline-docs && git pull
'

# =============================================================================
# Quick Health Check
# =============================================================================
alias pipeline-health='
  echo "=== Terraform State ===" && 
  cd $PIPELINE_ROOT/aws-content-pipeline && 
  terraform output -json | jq -r "{instance_id, bucket_name, region}" && 
  echo "\n=== AWS Instance ===" && 
  INSTANCE_ID=$(terraform output -raw instance_id) && 
  aws ec2 describe-instances --region $PIPELINE_REGION --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].[State.Name,InstanceType]" --output text && 
  echo "\n=== Recent Logs (last 5 lines) ===" && 
  aws logs tail /content-pipeline/editorbot --since 5m --region $PIPELINE_REGION 2>/dev/null | tail -5 || echo "No recent logs"
'

# =============================================================================
# Quick Status Check
# =============================================================================
alias pipeline-status='
  echo "📦 Instance: $(aws-instance-state)" &&
  echo "💾 S3 Bucket: $(aws-s3-bucket)" &&
  echo "🚀 Last Deploy:" &&
  gh run list --repo macizomedia/editorbot-stack --limit 1
'

# =============================================================================
# Helper Functions
# =============================================================================

# Get instance ID from Terraform
pipeline-instance-id() {
  cd $PIPELINE_ROOT/aws-content-pipeline && terraform output -raw instance_id
}

# Get S3 bucket name
pipeline-bucket() {
  aws s3 ls --region $PIPELINE_REGION | grep content-pipeline | awk '{print $3}'
}

# Quick SSH into instance
pipeline-ssh() {
  aws ssm start-session --target $(pipeline-instance-id) --region $PIPELINE_REGION
}

# View docker logs (after SSH)
pipeline-docker-logs() {
  docker logs editorbot-editorbot-1 --tail ${1:-100} -f
}

# Check cost estimate
pipeline-cost() {
  echo "Estimating monthly costs..."
  echo "EC2 t3.medium (24/7): ~\$30/month"
  echo "S3 storage (1GB): ~\$0.02/month"
  echo "CloudWatch logs: ~\$1/month"
  echo "Gemini API: ~\$0.50/month"
  echo "Total: ~\$33/month"
}

echo "✅ Content Pipeline aliases loaded"
echo "Run 'pipeline-health' for quick status check"
