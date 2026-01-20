# 🎯 EditorBot - Complete Learning Path

Welcome to the EditorBot codebase! This document guides you through understanding and improving the bot.

---

## 📚 Documentation Overview

We've created comprehensive guides for different learning styles:

| Document | Purpose | Best For |
|----------|---------|----------|
| **WORKFLOW_GUIDE.md** | Deep technical walkthrough | Understanding every detail |
| **QUICK_REFERENCE.md** | Fast lookup guide | Quick answers while coding |
| **VISUAL_GUIDE.md** | Diagrams and ASCII art | Visual learners |
| **EXECUTION_AUDIT.md** | Code quality analysis | Understanding current state |
| **This file** | Learning path | Getting started |

---

## 🚀 Getting Started (30 minutes)

### Step 1: Read the Architecture (5 min)
Open: `WORKFLOW_GUIDE.md` → Section: "Architecture"

**You'll learn:**
- The 5-layer architecture (Telegram → Handlers → FSM → Services → Storage)
- How messages flow through the system
- Component responsibilities

### Step 2: Understand the State Machine (10 min)
Open: `WORKFLOW_GUIDE.md` → Section: "State Machine Walkthrough"

**You'll learn:**
- All 5 states the bot can be in
- How states transition
- Why this design prevents bugs

### Step 3: Trace a Message (10 min)
Open: `VISUAL_GUIDE.md` → Section: "Message Flow Visualization"

**You'll learn:**
- Exact path a voice message takes
- All function calls in order
- Timing of each step

### Step 4: Review the Code (5 min)
```bash
cd /Users/user/Documents/BLAS/DEVELOPMENT/BOTs/editorBot
cat bot/bot.py          # Entry point
cat bot/handlers/voice.py  # Main logic
cat bot/state/machine.py   # FSM
```

---

## 🔧 Making Your First Change (10 minutes)

### Change a Bot Message

1. **Find the message:**
   ```bash
   grep -r "Texto confirmado" bot/
   # Returns: bot/handlers/text.py:16
   ```

2. **Open the file:**
   ```bash
   nano bot/handlers/text.py
   # Line 16: "✅ Texto confirmado. Continuamos."
   ```

3. **Edit it:**
   ```python
   # Change to:
   "✅ Perfect! Text confirmed. Let's continue."
   ```

4. **Test it:**
   ```bash
   python -m bot.bot  # Starts bot
   # Send text "OK" to see new message
   ```

### Change the Dialect

1. **Find the dialect:**
   ```bash
   grep -r "VenezuelanDialectProfile" bot/
   # Returns: bot/services/mediation.py:8
   ```

2. **Open the file:**
   ```bash
   nano bot/services/mediation.py
   # Line 8: profile=VenezuelanDialectProfile(),
   ```

3. **Change it:**
   ```python
   from dialect_mediator.profiles.rioplatense import RioplatenseDialectProfile
   # Change line 8 to:
   profile=RioplatenseDialectProfile(),
   ```

4. **Test it:**
   ```bash
   python -m bot.bot
   # Send "Che, che" - should convert to Argentine Spanish
   ```

---

## 🎓 Deep Dive Topics (1 hour each)

### Topic 1: Async Programming in Telegram
**Goal:** Understand how the bot handles multiple users simultaneously

**Read:**
- WORKFLOW_GUIDE.md → "Key Concepts to Remember" → "Async/Await Pattern"

**Hands-on:**
```python
# Try this in Python shell
import asyncio

async def hello():
    print("Starting")
    await asyncio.sleep(2)  # Simulates API call
    print("Done")

asyncio.run(hello())  # Executes asynchronously
```

### Topic 2: Adding a New State
**Goal:** Expand the state machine

**Read:**
- WORKFLOW_GUIDE.md → "Adding Features" → "Example 1: Add Language Selection"

**Hands-on:**
1. Add state to `state/models.py`
2. Add event to `state/machine.py`
3. Add transitions to `handle_event()`
4. Test with: `python -c "from bot.state.machine import handle_event"`

### Topic 3: Database Integration
**Goal:** Replace in-memory storage with PostgreSQL

**Read:**
- WORKFLOW_GUIDE.md → "Adding Features" → "Example 2: Add Database Storage"

**Hands-on:**
1. Install: `pip install sqlalchemy psycopg2`
2. Create database schema
3. Update `runtime.py` to use database
4. Test persistence

### Topic 4: Service Implementation
**Goal:** Implement real transcription (replace stub)

**Read:**
- WORKFLOW_GUIDE.md → "Services" section
- `bot/services/transcription.py` (currently a stub)

**Options:**
- Use Whisper: `pip install openai-whisper`
- Use Google Speech-to-Text: `pip install google-cloud-speech`
- Use AssemblyAI: `pip install assemblyai`

**Example with Whisper:**
```python
# bot/services/transcription.py
import whisper

def transcribe_audio(file_path: str) -> str:
    model = whisper.load_model("base")
    result = model.transcribe(file_path)
    return result["text"]
```

### Topic 5: Error Handling & Logging
**Goal:** Add professional logging

**Read:**
- WORKFLOW_GUIDE.md → "Adding Features" → "Example 4: Add Logging"

**Hands-on:**
1. Create `bot/config/logging.py`
2. Add logging to each handler
3. Test by checking `logs/editorbot.log`

---

## 🏗️ Build Your Own Feature (1-2 hours)

### Project: Export Function

**Goal:** Let users export mediated text

**Requirements:**
1. User types `/export`
2. Bot sends formatted text with original and mediated versions
3. User can copy it

**Implementation Plan:**

1. **Add handler:**
```bash
# bot/handlers/commands.py
nano +1 bot/handlers/commands.py
```

2. **Add code:**
```python
async def export_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    convo = get_conversation(chat_id)
    
    if not convo.mediated_text:
        await update.message.reply_text("No mediated text yet")
        return
    
    export = f"""
📄 TEXT EXPORT

Original:
{convo.transcript}

Mediated:
{convo.mediated_text}
"""
    await update.message.reply_text(export)
```

3. **Register in bot.py:**
```python
from telegram.ext import CommandHandler
from bot.handlers.commands import export_command

app.add_handler(CommandHandler("export", export_command))
```

4. **Test:**
```bash
python -m bot.bot
# Send voice message
# Type: /export
# Should see both texts
```

---

## 🐛 Debugging Your Changes

### Use the Debug Checklist

From QUICK_REFERENCE.md:
```
- [ ] Can bot connect to Telegram?
- [ ] Is GEMINI_API_KEY set?
- [ ] What's the current state?
- [ ] Is state machine throwing InvalidTransition?
- [ ] Is transcription service returning text?
- [ ] Is mediation service returning mediated text?
- [ ] Are we saving state to storage?
- [ ] Are handler responses being sent?
```

### Add Debug Prints

```python
# In handlers or services
import logging
logger = logging.getLogger(__name__)

logger.debug(f"Current state: {convo.state}")
logger.debug(f"Transcript: {transcript[:50]}...")  # First 50 chars
logger.info("Mediation completed successfully")
logger.error(f"Failed to transcribe: {e}")
```

### Check Logs

```bash
# Terminal output
python -m bot.bot 2>&1 | tee debug.log

# Or if you added logging file output
tail -f logs/editorbot.log
```

---

## 📈 Progression Path

### Week 1: Understand
- [ ] Read all documentation
- [ ] Trace a message through code
- [ ] Change a bot message
- [ ] Change the dialect
- [ ] Run tests

### Week 2: Modify
- [ ] Add a new command handler
- [ ] Implement the `/export` feature
- [ ] Add logging
- [ ] Write simple tests

### Week 3: Extend
- [ ] Implement real transcription
- [ ] Add database support
- [ ] Add language selection
- [ ] Deploy to EC2

### Week 4: Polish
- [ ] Add error tracking (Sentry)
- [ ] Add performance monitoring
- [ ] Optimize API calls
- [ ] Write comprehensive tests

---

## 🔗 Code Navigation Map

```
START HERE:
│
├─ bot.py
│  └─ Entry point, shows which handlers are registered
│
├─ handlers/
│  ├─ voice.py ⭐ MAIN WORKFLOW
│  │   └─ Shows how voice messages flow through system
│  │
│  └─ text.py ⭐ COMMAND HANDLING
│      └─ Shows how user commands are processed
│
├─ state/
│  ├─ machine.py ⭐ FSM LOGIC
│  │   └─ All possible state transitions
│  │
│  ├─ models.py ⭐ DATA STRUCTURES
│  │   └─ Conversation dataclass
│  │
│  └─ runtime.py
│      └─ Storage implementation
│
└─ services/
   ├─ transcription.py (NEEDS IMPLEMENTATION)
   └─ mediation.py (USES EXTERNAL LIBRARY)
```

---

## 💡 Key Insights

### Insight 1: Why State Machine?
Instead of scattered if-statements everywhere, we use a state machine. This:
- Makes valid transitions explicit
- Prevents invalid operations (e.g., "OK" when no text exists)
- Makes bugs obvious (InvalidTransition exception)
- Makes code testable

### Insight 2: Why Async/Await?
Instead of blocking on each user's request, async allows:
- Multiple users without multiple threads
- Fast response time (no waiting for slow operations)
- Clean code (looks like regular Python, not callback hell)

### Insight 3: Why Handlers + Services?
Instead of putting all logic in one file:
- **Handlers:** Focus on Telegram API (receiving/sending messages)
- **Services:** Focus on business logic (transcription, mediation)
- Easy to test services independently
- Easy to swap implementations (Whisper vs Google Speech-to-Text)

### Insight 4: Why In-Memory Storage?
For now, conversation state is stored in a Python dict:
- Fast for development
- No database setup needed
- Lost on bot restart (but fine for testing)
- Easy to replace later (just swap runtime.py)

---

## 🎯 Success Metrics

After working through this guide, you should be able to:

- [ ] Explain the state machine in 2 minutes
- [ ] Trace a voice message through the code
- [ ] Add a new bot message
- [ ] Add a new command handler
- [ ] Implement a service
- [ ] Debug issues using logs
- [ ] Deploy changes to production
- [ ] Add new features without breaking existing ones

---
