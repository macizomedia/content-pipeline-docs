# 🚀 LangGraph Deployment Guide - Week 1 (10% Rollout)

**Date:** January 24, 2026  
**Instance ID:** `i-013b229ba83c93cb9` (eu-central-1)  
**Deployment Type:** Gradual Rollout (10% → 50% → 100%)  
**Status:** Ready for Deployment

---

## Deployment Command

Execute this command to deploy LangGraph on the control VM:

```bash
aws ssm send-command \
  --instance-ids i-013b229ba83c93cb9 \
  --document-name AWS-RunShellScript \
  --region eu-central-1 \
  --parameters 'commands=[
    "cd /home/ubuntu/editorbot-stack/editorBot",
    "git pull origin main",
    "git submodule sync --recursive",
    "git submodule update --init --recursive",
    "docker-compose down",
    "docker-compose up --build -d",
    "sleep 5",
    "docker-compose exec -T editorbot bash -c \"echo LANGGRAPH_ROLLOUT_PCT=10 >> /app/.env\" || true",
    "docker-compose restart",
    "docker-compose ps",
    "echo DEPLOYMENT COMPLETE"
  ]' \
  --query 'Command.CommandId' \
  --output text
```

---

## What This Deployment Does

| Step | Action | Purpose |
|------|--------|---------|
| 1 | `git pull origin main` | Pull latest LangGraph code |
| 2 | `git submodule sync/update` | Update EditorBot and dialect_mediator |
| 3 | `docker-compose down` | Tear down old FSM-based containers |
| 4 | `docker-compose up --build -d` | Build new image with LangGraph + deps |
| 5 | `sleep 5` | Wait for container startup |
| 6 | Set `LANGGRAPH_ROLLOUT_PCT=10` | Enable LangGraph for 10% of users |
| 7 | `docker-compose restart` | Apply feature flag |
| 8 | `docker-compose ps` | Verify containers are running |

---

## Monitoring Deployment

### Get Command Execution ID

The SSM command returns a `CommandId`. Use it to check status:

```bash
# Check command status
aws ssm get-command-invocation \
  --command-id <COMMAND_ID> \
  --instance-id i-013b229ba83c93cb9 \
  --region eu-central-1 \
  --query 'Status' \
  --output text

# View full command output
aws ssm get-command-invocation \
  --command-id <COMMAND_ID> \
  --instance-id i-013b229ba83c93cb9 \
  --region eu-central-1 \
  --query 'StandardOutputContent' \
  --output text
```

### View Live Logs

After deployment, check container logs:

```bash
# SSH to control VM
aws ssm start-session --target i-013b229ba83c93cb9 --region eu-central-1

# Once inside, view logs
cd /home/ubuntu/editorbot-stack/editorBot
docker-compose logs -f editorbot
```

---

## Verification Checklist

After deployment, verify these:

- [ ] `docker-compose ps` shows all containers running (`Up` status)
- [ ] No errors in `docker-compose logs editorbot`
- [ ] `/app/.env` contains `LANGGRAPH_ROLLOUT_PCT=10`
- [ ] Telegram bot responds to `/start` command
- [ ] New LangGraph commands work:
  - [ ] `/init format=REEL_VERTICAL style=dynamic assistance=standard`
  - [ ] `/template` lists templates
  - [ ] `/start` begins collection
  - [ ] `/reset` clears state
  - [ ] `/skip` bypasses validation
- [ ] SQLite checkpoint directory exists: `docker-compose exec editorbot ls /app/data/`
- [ ] LangGraph logs appear for ~10% of test users

---

## Key Metrics to Monitor (Week 1)

Track these metrics during testing:

### Success Metrics
- ✅ **Deployment success rate:** 100% (all containers running)
- ✅ **User conversation completion rate:** Target >80%
- ✅ **Validation attempts per conversation:** Avg 2-3 (based on assistance level)
- ✅ **LLM response latency:** <5 seconds (with flash model)
- ✅ **Feature flag accuracy:** 10% ± 2% of users on LangGraph

### Error Metrics
- ⚠️ **Validation timeouts:** Should be <1% of conversations
- ⚠️ **Field extraction errors:** Monitor false negatives
- ⚠️ **SQLite persistence errors:** Should be 0
- ⚠️ **LLM API errors:** Track gemini API failures

### Cost Metrics
- 📊 **API calls per conversation:** ~7-15 (3-4x increase from FSM)
- 📊 **Gemini API cost:** Monitor daily spend vs. baseline
- 📊 **Token usage:** Track input/output tokens per model

---

## Rollout Schedule

### Week 1: Testing Phase (10%)
**Start Date:** Jan 24, 2026  
**Feature Flag:** `LANGGRAPH_ROLLOUT_PCT=10`  
**Users:** ~10% of active users  
**Goal:** Validate all features, collect feedback

**Action Items:**
- Deploy with 10% rollout
- Monitor logs for errors (24/7)
- Test all 6 new commands manually
- Collect user feedback
- Document any issues

### Week 2: Expansion Phase (50%)
**Start Date:** Jan 31, 2026  
**Feature Flag:** `LANGGRAPH_ROLLOUT_PCT=50`  
**Users:** ~50% of active users  
**Goal:** Expand testing, refine LLM prompts

**Action Items:**
- Increase rollout to 50%
- Refine `extract_fields_from_input()` prompts based on Week 1 data
- Optimize Gemini model selection (flash vs. pro)
- Monitor A/B test metrics

### Week 3: Full Cutover (100%)
**Start Date:** Feb 7, 2026  
**Feature Flag:** `LANGGRAPH_ROLLOUT_PCT=100`  
**Users:** 100% of users  
**Goal:** Deprecate old FSM

**Action Items:**
- Set rollout to 100%
- Remove legacy FSM code (machine.py, models.py)
- Archive old handler logic
- Update documentation
- Celebrate! 🎉

---

## Rollback Procedure

If critical issues occur, rollback immediately:

```bash
# SSH to control VM
aws ssm start-session --target i-013b229ba83c93cb9 --region eu-central-1

# Disable LangGraph (set rollout to 0%)
cd /home/ubuntu/editorbot-stack/editorBot
docker-compose exec editorbot bash -c "echo LANGGRAPH_ROLLOUT_PCT=0 >> /app/.env"
docker-compose restart

# Verify old FSM is active
docker-compose logs -f editorbot
```

**Full rollback** (revert code):
```bash
git revert HEAD
docker-compose down
docker-compose up --build -d
```

---

## Troubleshooting

### Issue: Deployment Command Fails

**Symptoms:** SSM command returns `Failed` status

**Steps:**
1. Check EC2 instance is running: `aws ec2 describe-instances --instance-ids i-013b229ba83c93cb9 --region eu-central-1`
2. View error logs: `aws ssm get-command-invocation --command-id <ID> --instance-id i-013b229ba83c93cb9 --region eu-central-1 --query 'StandardErrorContent'`
3. Check instance IAM role has SSM permissions
4. Retry deployment

### Issue: Docker Build Fails

**Symptoms:** `docker-compose up --build -d` fails

**Steps:**
1. Check Docker daemon: `docker ps`
2. Check disk space: `docker exec editorbot df -h`
3. View Dockerfile errors: `docker-compose logs` (during build)
4. Clean up: `docker system prune -a` and retry

### Issue: LangGraph Not Active for 10% of Users

**Symptoms:** All users using old FSM, not 10%

**Steps:**
1. Verify env var: `docker-compose exec editorbot cat /app/.env | grep LANGGRAPH`
2. Check feature flag logic: `grep -A 10 'use_langgraph_for_user' bot/graph/feature_flag.py`
3. Restart containers: `docker-compose restart`
4. Test with specific user: Set chat_id to hash to 0-9 (e.g., chat_id=1234567890)

### Issue: Validation Loop Never Completes

**Symptoms:** Users stuck in validation → collection cycle

**Steps:**
1. Check assistance level: `docker-compose exec editorbot cat /app/.env | grep ASSISTANCE`
2. Verify max_validation_retries is enforced in state
3. Check LLM validation prompts in `nodes.py`
4. Increase log verbosity if needed

---

## Support & Escalation

### Quick Questions
- See `QUICK_REFERENCE.md` for command syntax
- See `LANGGRAPH_ARCHITECTURE.md` for system design

### Deployment Issues
- Check SSM command output
- Review `docker-compose logs editorbot`
- SSH to instance for hands-on debugging

### Code Issues
- Review `IMPLEMENTATION_SUMMARY.md` for spec compliance
- Trace issue in `bot/graph/*.py` files
- Check test cases in `test_langgraph_integration.py`

---

## Success Criteria

Deployment is **successful** when:

✅ All containers running (`docker-compose ps` shows `Up`)  
✅ No critical errors in logs  
✅ `/init`, `/template`, `/start` commands work  
✅ SQLite checkpoint file exists and grows  
✅ ~10% of test users routed to LangGraph  
✅ Conversation completion rate ≥80%  
✅ No infinite validation loops  
✅ Feature flag can be toggled without restart  

---

## Next Steps

1. **Execute SSM deployment command** (above)
2. **Monitor logs for 24 hours**
3. **Verify success criteria**
4. **Approve Week 2 expansion** or troubleshoot issues
5. **Escalate if needed**

---

**Deployment Owner:** You  
**Created:** 2026-01-24  
**Status:** Ready  
**Confidence:** 8.5/10

Good luck! 🚀
