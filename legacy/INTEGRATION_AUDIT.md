# Integration & Audit Notes (Student Repos)

Date: 2026-01-19

## Summary
Two student repos were aligned into a single production workspace:
- Infrastructure: `aws-content-pipeline/`
- Application: `editorbot-stack/`

## Findings (pre-fix)
1. **Leaked service account JSON** in `editorbot-stack/google-credentials.json`.
2. **Hardcoded SSH CIDRs** in Terraform security group.
3. **Bootstrap script overwrote app Dockerfile/compose** and used a wrong module path (`Bot.bot`).
4. **SSM access missing** in IAM policy, despite bootstrap using SSM.
5. **Terraform variables not wired** into user_data (repo URL + env mode unused).

## Fixes applied
- Removed credentials from `google-credentials.json` and ignored it in `.gitignore`.
- Added `admin_ipv4_cidr_blocks` and `admin_ipv6_cidr_blocks` variables and used dynamic ingress rules.
- Parameterized `user_data` via `templatefile(...)` and injected EditorBot settings.
- Added least-privilege SSM policy and optional KMS decrypt key.
- Adjusted bootstrap to use repo-provided Dockerfile/compose and `.env` location.
- Added CloudWatch log groups and agent configuration for bootstrap + Docker logs.
- Added deploy workflow in `editorbot-stack/.github/workflows/deploy.yml` using SSM Run Command.
- Added CI workflow in `.github/workflows/ci.yml` for Terraform + Python + security scans.

## Secrets and credentials
- GitHub repo secrets (editorbot-stack):
	- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`, `EDITORBOT_INSTANCE_ID`, `TOKEN_DEPLOY`
- SSM Parameter Store (runtime secrets):
	- `/editorbot/telegram_bot_token`
	- `/editorbot/gemini_api_key`

## Operational notes
- Deploys run via GitHub Actions → SSM Run Command (no SSH).
- If Git reports “dubious ownership”, ensure `safe.directory` is set in the deploy script.
- CloudWatch log groups:
	- `/content-pipeline/bootstrap`
	- `/content-pipeline/editorbot`
- Runbook: [docs/RUNBOOK.md](docs/RUNBOOK.md)

## Remaining decisions
- Confirm whether SSM parameters use a custom KMS key and set `ssm_kms_key_arn` if needed.
- Decide how GPU image generation will be invoked (separate Terraform or manual instance).
