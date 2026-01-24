# Remote Debugging Strategy

Future-proofing notes for cloud-based debugging capabilities.

**Status:** Design phase (not implemented)
**Priority:** Medium (useful when collaborating or debugging in production)
**Complexity:** Low-Medium (2-4 hours implementation)

---

## Problem Statement

Currently, debugging EditorBot requires:
- SSH/SSM access to EC2 instance
- Local CLI tool (only works on host machine)
- No visibility from mobile devices
- Manual CloudWatch log inspection

**Goal:** Enable remote debugging with structured logging visibility from any device (especially phone).

---

## Recommended Architecture

### Phase 1: Admin Commands in EditorBot ⭐ RECOMMENDED

**Concept:**
Extend the production EditorBot with admin-only commands for debugging.

**Why This Works:**
- Already have Telegram infrastructure
- Natural mobile interface (existing app)
- Secure via user_id whitelist
- CloudWatch logs already centralized
- Minimal new code

**Implementation:**

```python
# bot/handlers/admin.py

import logging
from telegram import Update
from telegram.ext import ContextTypes
from functools import wraps

logger = logging.getLogger(__name__)

# Configuration
ADMIN_USER_IDS = [
    123456789,  # Your Telegram user_id
]

def admin_only(func):
    """Decorator to restrict commands to admin users"""
    @wraps(func)
    async def wrapper(update: Update, context: ContextTypes.DEFAULT_TYPE):
        user_id = update.effective_user.id

        if user_id not in ADMIN_USER_IDS:
            logger.warning(
                "unauthorized_admin_access",
                extra={
                    "user_id": user_id,
                    "command": update.message.text,
                }
            )
            await update.message.reply_text("❌ Unauthorized")
            return

        logger.info(
            "admin_command_executed",
            extra={
                "user_id": user_id,
                "command": update.message.text,
            }
        )

        return await func(update, context)
    return wrapper


@admin_only
async def admin_state(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Show current conversation state for a chat.

    Usage:
        /admin_state              # Show own state
        /admin_state 123456       # Show state for chat_id
    """
    # Parse target chat_id
    if context.args:
        target_chat_id = int(context.args[0])
    else:
        target_chat_id = update.effective_chat.id

    # Get conversation from state manager
    from bot.state.manager import get_conversation
    conversation = get_conversation(target_chat_id)

    # Format state
    state_text = f"""
🔍 **Debug State**

Chat ID: `{target_chat_id}`
State: `{conversation.state.value}`

Transcript: {_preview(conversation.transcript)}
Mediated: {_preview(conversation.mediated_text)}
Script: {_preview(conversation.final_script)}
Template: `{conversation.selected_template or 'None'}`
Soundtrack: `{conversation.selected_soundtrack or 'None'}`

Render Plan: {'✅ Generated' if conversation.render_plan else '❌ Not generated'}
Visual Strategy: {'✅ Ready' if conversation.visual_strategy else '❌ Not ready'}
"""

    await update.message.reply_text(state_text, parse_mode="Markdown")


@admin_only
async def admin_logs(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Query CloudWatch logs for a chat.

    Usage:
        /admin_logs 123456 50     # Last 50 logs for chat_id
        /admin_logs 123456        # Last 20 logs
    """
    if not context.args:
        await update.message.reply_text("Usage: /admin_logs <chat_id> [count]")
        return

    target_chat_id = int(context.args[0])
    count = int(context.args[1]) if len(context.args) > 1 else 20

    # Query CloudWatch
    from bot.services.cloudwatch import query_logs
    logs = await query_logs(
        log_group="/editorbot/logs",
        filter_pattern=f'{{$.chat_id = {target_chat_id}}}',
        limit=count,
    )

    # Format logs
    log_text = f"📋 **Last {len(logs)} logs for chat {target_chat_id}**\n\n"

    for log in logs:
        timestamp = log.get("timestamp", "")
        event = log.get("message", "")
        log_text += f"• {timestamp}: {event}\n"

    await update.message.reply_text(log_text, parse_mode="Markdown")


@admin_only
async def admin_reset(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Reset conversation state (useful for recovering from stuck states).

    Usage:
        /admin_reset 123456
    """
    if not context.args:
        await update.message.reply_text("Usage: /admin_reset <chat_id>")
        return

    target_chat_id = int(context.args[0])

    from bot.state.manager import reset_conversation
    reset_conversation(target_chat_id)

    await update.message.reply_text(f"✅ Reset conversation for chat {target_chat_id}")


@admin_only
async def admin_simulate(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Manually trigger state machine event.

    Usage:
        /admin_simulate 123456 RENDER_PLAN_BUILT
    """
    if len(context.args) < 2:
        await update.message.reply_text(
            "Usage: /admin_simulate <chat_id> <event>\n"
            "Events: VOICE_RECEIVED, TEXT_RECEIVED, TEMPLATE_SELECTED, etc."
        )
        return

    target_chat_id = int(context.args[0])
    event_name = context.args[1]

    from bot.state.machine import handle_event, EventType
    from bot.state.manager import get_conversation

    conversation = get_conversation(target_chat_id)
    event = EventType[event_name]

    new_state = await handle_event(conversation, event, payload=None)

    await update.message.reply_text(
        f"✅ Triggered {event_name}\n"
        f"State: {conversation.state.value} → {new_state.value}"
    )


def _preview(text: str, max_len: int = 50) -> str:
    """Helper to preview long text"""
    if not text:
        return "`None`"
    if len(text) <= max_len:
        return f"`{text}`"
    return f"`{text[:max_len]}...`"


# Register handlers in main.py:
# application.add_handler(CommandHandler("admin_state", admin_state))
# application.add_handler(CommandHandler("admin_logs", admin_logs))
# application.add_handler(CommandHandler("admin_reset", admin_reset))
# application.add_handler(CommandHandler("admin_simulate", admin_simulate))
```

**Security Checklist:**

- [ ] Add your Telegram user_id to `ADMIN_USER_IDS`
- [ ] Never commit real user IDs (use environment variable)
- [ ] Add rate limiting (max 10 admin commands/minute)
- [ ] Log all admin actions to CloudWatch
- [ ] Add confirmation for destructive commands (reset, simulate)

**Phone Usage:**

```
/admin_state
/admin_logs 123456 50
/admin_reset 123456
/admin_simulate 123456 RENDER_PLAN_BUILT
```

**Estimated Effort:** 2-3 hours

---

### Phase 2: CloudWatch Integration

**Requirements:**
- AWS SDK (boto3) already in requirements
- Proper IAM permissions for CloudWatch Logs read access

**CloudWatch Service Helper:**

```python
# bot/services/cloudwatch.py

import boto3
from typing import List, Dict, Any
from datetime import datetime, timedelta

class CloudWatchService:
    def __init__(self, log_group: str = "/editorbot/logs"):
        self.client = boto3.client("logs", region_name="eu-central-1")
        self.log_group = log_group

    async def query_logs(
        self,
        filter_pattern: str,
        limit: int = 20,
        start_time: datetime = None,
    ) -> List[Dict[str, Any]]:
        """
        Query CloudWatch logs with filter.

        Example filter patterns:
        - '{ $.chat_id = 123456 }'
        - '{ $.event = "transcription_complete" }'
        - '{ $.level = "ERROR" }'
        """
        if not start_time:
            start_time = datetime.now() - timedelta(hours=24)

        response = self.client.filter_log_events(
            logGroupName=self.log_group,
            filterPattern=filter_pattern,
            startTime=int(start_time.timestamp() * 1000),
            limit=limit,
        )

        return [
            {
                "timestamp": event["timestamp"],
                "message": event["message"],
            }
            for event in response.get("events", [])
        ]
```

**IAM Policy (add to control VM role):**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:FilterLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "arn:aws:logs:eu-central-1:*:log-group:/editorbot/*"
    }
  ]
}
```

**Estimated Effort:** 1 hour

---

## Alternative Architectures (Future Consideration)

### Option 2: Separate Debug Bot

**When to use:**
- Need more complex debugging features
- Want complete separation from production
- Multiple admin users with different permissions

**Structure:**
```
editorbot-stack/
  editorBot/          # Production bot
  debugBot/           # Admin-only bot
    bot/
      commands/
        state.py
        logs.py
        metrics.py
```

**Pros:**
- Clean separation (can't break production)
- More powerful debug features
- Independent deployment

**Cons:**
- Second bot token needed
- More maintenance overhead
- Slightly more complex architecture

**Estimated Effort:** 4-6 hours

---

### Option 3: HTTP API + Token Auth

**When to use:**
- Need programmatic access (not just Telegram)
- Want web dashboard
- Multiple clients (web, mobile, CLI)

**NOT RECOMMENDED because:**
- Over-engineered for single user
- Need to secure HTTP endpoint (ALB, auth, HTTPS)
- Worse mobile UX than Telegram
- More attack surface

---

## Implementation Checklist

When ready to implement:

### Phase 1: Admin Commands (Core)
- [ ] Create `bot/handlers/admin.py`
- [ ] Add admin user whitelist (environment variable)
- [ ] Implement `/admin_state` command
- [ ] Implement `/admin_logs` command (stub first)
- [ ] Implement `/admin_reset` command
- [ ] Add admin command handlers to `main.py`
- [ ] Test locally with CLI
- [ ] Add structured logging for admin actions
- [ ] Document commands in README

### Phase 2: CloudWatch Integration
- [ ] Create `bot/services/cloudwatch.py`
- [ ] Add boto3 CloudWatch client
- [ ] Update IAM role with CloudWatch read permissions
- [ ] Implement log filtering
- [ ] Connect `/admin_logs` to CloudWatch
- [ ] Test log queries
- [ ] Add error handling for AWS API failures

### Phase 3: Advanced Features (Optional)
- [ ] Add `/admin_metrics` (conversation success rates)
- [ ] Add `/admin_health` (system status)
- [ ] Add rate limiting decorator
- [ ] Add confirmation dialogs for destructive commands
- [ ] Create admin command reference doc

---

## Testing Strategy

### Local Testing

```bash
# Start bot locally
cd editorbot-stack/editorBot
source ../../.venv/bin/activate
python -m bot.main

# In Telegram:
/admin_state
/admin_logs 123456 10
```

### Production Testing

```bash
# Deploy to EC2
cd editorbot-stack
./scripts/ssm_deploy.sh

# Test commands from phone via Telegram
```

---

## Security Considerations

**Critical:**
- User ID whitelist in environment variable (not hardcoded)
- Audit all admin actions
- Rate limit admin commands
- Never expose in public bot

**Environment Variables:**

```bash
# Add to .env or SSM Parameter Store
ADMIN_USER_IDS=123456789,987654321
ADMIN_RATE_LIMIT=10  # commands per minute
```

**Terraform Update (SSM Parameters):**

```hcl
resource "aws_ssm_parameter" "admin_user_ids" {
  name  = "/editorbot/admin_user_ids"
  type  = "StringList"
  value = var.admin_user_ids
}
```

---

## Cost Analysis

**Current costs:** ~$0
**Added costs:** ~$0

- CloudWatch API calls: Free tier (5GB ingestion, 5GB archive)
- No new infrastructure
- Uses existing bot/EC2/CloudWatch

**Estimated monthly cost:** $0 (within free tier)

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-24 | Deferred implementation | Focus on core bot functionality first |
| TBD | Implement Phase 1 | When remote debugging becomes necessary |

---

## References

- [Telegram Bot API - Commands](https://core.telegram.org/bots/api#setmycommands)
- [AWS CloudWatch Logs - Filter Patterns](https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html)
- [python-telegram-bot - Decorators](https://docs.python-telegram-bot.org/en/stable/examples.html)

---

## Quick Start (When Ready)

```bash
# 1. Create admin handler
cp content-pipeline-docs/reference/REMOTE_DEBUGGING.md editorbot-stack/editorBot/bot/handlers/admin.py

# 2. Edit to keep only implementation code

# 3. Add your Telegram user_id
export TELEGRAM_USER_ID=$(curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates" | jq -r '.result[0].message.from.id')
echo $TELEGRAM_USER_ID  # Save this

# 4. Add to main.py
# application.add_handler(CommandHandler("admin_state", admin_state))

# 5. Test locally
python -m bot.main

# 6. Test in Telegram
/admin_state
```

---

**Next Review:** When bot goes to production or collaboration begins
