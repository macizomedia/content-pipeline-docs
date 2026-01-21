# Key Rotation Runbook

## 🔄 Key Rotation Process

### Prerequisites
```bash
# Install gitleaks
brew install gitleaks

# Install boto3 for rotation script
pip install boto3

# Configure AWS credentials
aws configure
```

### 1. Gemini API Key Rotation

#### Generate New Key
1. Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
2. Navigate to APIs & Services → Credentials
3. Click "Create Credentials" → "API Key"
4. Copy the new key
5. Restrict the key:
   - API restrictions: Select "Generative Language API"
   - Application restrictions: None (or IP if possible)

#### Rotate Using Script
```bash
# Backup current key
python scripts/rotate_keys.py backup /editorbot/gemini_api_key

# Rotate to new key
python scripts/rotate_keys.py rotate-gemini AIza...NewKey...

# Restart editorbot
aws ssm send-command \
  --instance-ids i-xxxxx \
  --document-name "AWS-RunShellScript" \
  --parameters 'commands=["cd /home/ubuntu/editorbot/editorBot && docker compose restart"]'
```

#### Manual Rotation
```bash
# Update SSM parameter
aws ssm put-parameter \
  --name /editorbot/gemini_api_key \
  --value "AIza...NewKey..." \
  --type SecureString \
  --overwrite \
  --description "Rotated $(date +%Y-%m-%d)"

# Restart service
ssh ec2-user@instance
cd /home/ubuntu/editorbot/editorBot
docker compose down && docker compose up -d
```

#### Delete Old Key
1. Return to Google Cloud Console
2. Find the old API key
3. Click "Delete"
4. Confirm deletion

---

### 2. Telegram Bot Token Rotation

⚠️ **Note:** Telegram bot tokens cannot be rotated directly. You must:
1. Revoke the old token (disables old bot)
2. Create a new bot OR regenerate token via [@BotFather](https://t.me/BotFather)

#### Steps
```bash
# Talk to @BotFather on Telegram
/mybots
# Select your bot
# Select "API Token" → "Regenerate Token"

# Update SSM parameter
aws ssm put-parameter \
  --name /editorbot/telegram_bot_token \
  --value "1234567890:ABCdef..." \
  --type SecureString \
  --overwrite

# Restart editorbot
cd /home/ubuntu/editorbot/editorBot
docker compose restart
```

---

### 3. AWS Access Keys Rotation

#### For GitHub Actions Secrets
```bash
# 1. Create new access key in AWS Console
aws iam create-access-key --user-name github-actions-user

# 2. Update GitHub secrets (editorbot-stack repo)
gh secret set AWS_ACCESS_KEY_ID --body "AKIA..."
gh secret set AWS_SECRET_ACCESS_KEY --body "..."

# 3. Test deployment
cd editorbot-stack
git commit --allow-empty -m "test: verify new AWS keys"
git push

# 4. Delete old access key
aws iam delete-access-key \
  --user-name github-actions-user \
  --access-key-id AKIA_OLD_KEY_ID
```

---

### 4. SSH Key Pair Rotation

```bash
# Generate new key pair in AWS
aws ec2 create-key-pair \
  --key-name content-pipeline-v2 \
  --query 'KeyMaterial' \
  --output text > ~/.ssh/content-pipeline-v2.pem

chmod 400 ~/.ssh/content-pipeline-v2.pem

# Update Terraform variable
# In terraform.tfvars:
# key_pair_name = "content-pipeline-v2"

# Apply Terraform (will recreate instance)
cd aws-content-pipeline
terraform apply

# Delete old key pair
aws ec2 delete-key-pair --key-name content-pipeline-v1
rm ~/.ssh/content-pipeline-v1.pem
```

---

## 📅 Rotation Schedule

| Secret | Rotation Frequency | Owner |
|--------|-------------------|-------|
| Gemini API Key | 90 days | Development |
| Telegram Bot Token | On compromise only | Development |
| AWS Access Keys | 90 days | Infrastructure |
| SSH Key Pairs | 180 days or on compromise | Infrastructure |
| Instance IAM Role | No rotation (uses temp credentials) | N/A |

---

## 🚨 Emergency Rotation (Compromised Key)

### Immediate Steps
```bash
# 1. Backup evidence
python scripts/rotate_keys.py backup /editorbot/gemini_api_key

# 2. Rotate immediately
python scripts/rotate_keys.py rotate-gemini NEW_KEY

# 3. Restart services
# (Use SSM command from above)

# 4. Audit logs
aws cloudwatch tail /content-pipeline/editorbot --follow

# 5. Review GitHub commit history
git log --all --full-history --source -- '*credentials*'
```

---

## 🔍 Monitoring

### Check Parameter Age
```bash
# List all parameters needing rotation
python scripts/rotate_keys.py list

# Check specific parameter
aws ssm get-parameter-history \
  --name /editorbot/gemini_api_key \
  --max-results 5
```

### Set CloudWatch Alarm (Optional)
```bash
# Create SNS topic for alerts
aws sns create-topic --name key-rotation-alerts

# Subscribe your email
aws sns subscribe \
  --topic-arn arn:aws:sns:eu-central-1:ACCOUNT:key-rotation-alerts \
  --protocol email \
  --notification-endpoint your@email.com

# Create EventBridge rule (triggered every 90 days)
aws events put-rule \
  --name check-key-rotation \
  --schedule-expression "rate(90 days)"
```

---

## 📝 Post-Rotation Checklist

- [ ] Service restarted and running
- [ ] Health check passes (send test message to bot)
- [ ] Old key deleted from provider (Google/AWS)
- [ ] Backup stored securely (encrypted)
- [ ] Rotation logged in docs/CHANGELOG.md
- [ ] Team notified (if applicable)

---

## 🛠️ Troubleshooting

### Service Won't Start After Rotation
```bash
# Check if parameter exists
aws ssm get-parameter --name /editorbot/gemini_api_key

# Check container logs
docker logs editorbot-editorbot-1 --tail 50

# Verify .env is populated (if using ssm mode)
cat /home/ubuntu/editorbot/editorBot/.env
```

### "Invalid API Key" Errors
- Verify new key is correctly entered (no extra spaces)
- Check API restrictions in Google Cloud Console
- Ensure billing is enabled for the project
- Wait 1-2 minutes for key propagation

---

## 📚 References

- [AWS SSM Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Google Cloud API Keys](https://cloud.google.com/docs/authentication/api-keys)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
