# 📚 EditorBot - Complete Workflow Guide

## Table of Contents
1. [System Architecture](#architecture)
2. [Data Flow Diagram](#data-flow)
3. [Component Deep Dive](#components)
4. [State Machine Walkthrough](#state-machine)
5. [How to Add Features](#adding-features)
6. [Extension Examples](#examples)

---

## 🏗️ Architecture {#architecture}

### High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        TELEGRAM USERS                            │
└────────────────┬────────────────────────────────────────────────┘
                 │ (Voice/Text messages)
                 ▼
    ┌────────────────────────────────┐
    │   TELEGRAM BOT API            │
    │  (python-telegram-bot)        │
    └────────────┬───────────────────┘
                 │ (Update events)
                 ▼
    ┌────────────────────────────────┐
    │   EVENT HANDLERS               │
    │  (voice.py, text.py)          │
    │  ├─ Receive message            │
    │  ├─ Extract data               │
    │  └─ Trigger workflows          │
    └────────────┬───────────────────┘
                 │ (Events)
                 ▼
    ┌────────────────────────────────┐
    │   STATE MACHINE (FSM)          │
    │  machine.py                   │
    │  ├─ Validate transitions       │
    │  ├─ Update state               │
    │  └─ Persist conversation      │
    └────────────┬───────────────────┘
                 │ (Conversation state)
                 ▼
    ┌────────────────────────────────┐
    │   SERVICES                     │
    │  ├─ Transcription              │
    │  │  (speech → text)            │
    │  ├─ Mediation                  │
    │  │  (dialect → standard)       │
    │  └─ Storage                    │
    │     (in-memory for now)        │
    └────────────┬───────────────────┘
                 │ (Results)
                 ▼
    ┌────────────────────────────────┐
    │   RESPONSE FORMATTING          │
    │  (bot messages to user)        │
    └────────────┬───────────────────┘
                 │ (Messages)
                 ▼
    ┌────────────────────────────────┐
    │   TELEGRAM BOT API             │
    │  (send replies)                │
    └────────────┬───────────────────┘
                 │
                 ▼
    ┌─────────────────────────────────────────────────────────────────┐
    │                        TELEGRAM USERS                            │
    │              (receive mediated text and options)                 │
    └─────────────────────────────────────────────────────────────────┘
```

### Directory Structure

```
editorBot/
├── bot/
│   ├── bot.py                 # Entry point, initializes bot
│   ├── handlers/              # Event handlers
│   │   ├── voice.py          # Handle voice messages
│   │   ├── text.py           # Handle text messages
│   │   └── commands.py       # Handle commands (future)
│   ├── services/             # Business logic
│   │   ├── mediation.py      # Dialect mediation
│   │   └── transcription.py  # Speech-to-text
│   └── state/                # State management
│       ├── machine.py        # FSM logic
│       ├── models.py         # Data models
│       ├── runtime.py        # In-memory storage
│       └── store.py          # (placeholder for DB)
├── pyproject.toml            # Dependencies
├── .env                       # Credentials (git-ignored)
└── audit.py                   # Testing script
```

---

## 🔄 Data Flow Diagram {#data-flow}

### Voice Message Flow

```
User sends voice message
        ↓
[handle_voice triggered]
        ↓
1. Get conversation state from storage
   state = runtime.get_conversation(chat_id)  // → IDLE
        ↓
2. Transition state: IDLE → TRANSCRIBED
   state = FSM.handle_event(VOICE_RECEIVED)
        ↓
3. Download audio file from Telegram
   file = await context.bot.get_file(file_id)
        ↓
4. Transcribe audio to text
   transcript = services.transcribe_audio(file_path)
        ↓
5. Transition state: TRANSCRIBED → MEDIATED
   state = FSM.handle_event(TEXT_RECEIVED, transcript)
        ↓
6. Mediate dialect (Spanish variant → Standard Spanish)
   mediated = services.mediate_text(transcript)
        ↓
7. Transition state: MEDIATED → AWAITING_EDIT
   state = FSM.handle_event(TEXT_RECEIVED, mediated)
        ↓
8. Save conversation state to storage
   runtime.save_conversation(chat_id, state)
        ↓
9. Send response to user with options
   "✍️ Texto mediado (borrador):\n\n{mediated}"
   "Responde con: OK / EDITAR / CANCELAR"
        ↓
User chooses: OK, EDITAR, or CANCELAR
        ↓
[handle_text triggered]
        ↓
(see text flow below)
```

### Text Message Flow

```
User sends text message (including OK/EDITAR/CANCELAR)
        ↓
[handle_text triggered]
        ↓
1. Get current conversation state
   state = runtime.get_conversation(chat_id)  // → AWAITING_EDIT
        ↓
2. Check command
   IF "OK":
      ├─ Transition: AWAITING_EDIT → CONFIRMED
      ├─ Send confirmation
      └─ Save state → goes to IDLE
   
   ELSE IF "EDITAR":
      ├─ Ask for edited text
      └─ Stay in AWAITING_EDIT
   
   ELSE IF "CANCELAR":
      ├─ Transition: AWAITING_EDIT → IDLE
      ├─ Send cancellation message
      └─ Clear conversation
   
   ELSE (plain text):
      ├─ User provided edited text
      ├─ Update mediated_text with new input
      ├─ Stay in AWAITING_EDIT
      └─ Ask for OK/CANCELAR again
        ↓
3. Save updated conversation state
   runtime.save_conversation(chat_id, state)
        ↓
4. Send response to user
        ↓
User sees bot response
```

---

## 🔧 Component Deep Dive {#components}

### 1. **Entry Point: `bot/bot.py`**

```python
# Purpose: Initialize and run the bot
# Responsibilities:
#   - Load Telegram bot token
#   - Create ApplicationBuilder
#   - Register message handlers
#   - Start polling for updates

def main():
    token = os.environ.get("TELEGRAM_BOT_TOKEN")  # From .env
    app = ApplicationBuilder().token(token).build()
    
    # Register handlers for different message types
    app.add_handler(MessageHandler(filters.VOICE, handle_voice))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_text))
    
    # Start listening for messages
    app.run_polling()
```

**Key Points:**
- Runs indefinitely, listening to Telegram API
- Dispatches incoming messages to appropriate handlers
- Handlers are async functions

---

### 2. **Event Handlers: `bot/handlers/`**

#### `voice.py` - Handle Voice Messages

```python
async def handle_voice(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Flow:
    1. Get conversation state
    2. Download voice file
    3. Transcribe to text
    4. Mediate dialect
    5. Update FSM state
    6. Send response to user
    """
    
    chat_id = update.effective_chat.id  # Unique user identifier
    
    # Step 1: Load current conversation
    convo = get_conversation(chat_id)  # From state/runtime.py
    
    # Step 2: Update FSM state
    convo = handle_event(convo, EventType.VOICE_RECEIVED)
    
    # Step 3-5: Download and process audio
    voice = update.message.voice
    file = await context.bot.get_file(voice.file_id)
    
    with tempfile.NamedTemporaryFile(suffix=".ogg") as tmp:
        await file.download_to_drive(tmp.name)
        transcript = transcribe_audio(tmp.name)
    
    # Step 6: Update FSM with transcript
    convo = handle_event(convo, EventType.TEXT_RECEIVED, transcript)
    
    # Step 7: Mediate the text
    mediated = mediate_text(transcript)
    
    # Step 8: Update FSM with mediated text
    convo = handle_event(convo, EventType.TEXT_RECEIVED, mediated)
    
    # Step 9: Persist state
    save_conversation(chat_id, convo)
    
    # Step 10: Send response
    await update.message.reply_text(
        f"✍️ Texto mediado (borrador):\n\n{mediated}\n\n"
        "Responde con:\n- OK\n- EDITAR (pegando texto)\n- CANCELAR"
    )
```

**Key Points:**
- `async` function (required by telegram.ext)
- Uses `update` object to get message data
- Uses `context.bot` to download files
- Orchestrates multiple services
- Error handling via try-except

#### `text.py` - Handle Text Messages

```python
async def handle_text(update: Update, context: ContextTypes.DEFAULT_TYPE):
    """
    Handle user commands and edited text
    Flow:
    1. Get conversation state
    2. Check if message is a command (OK/EDITAR/CANCELAR)
    3. Update FSM accordingly
    4. Send appropriate response
    """
    
    chat_id = update.effective_chat.id
    text = update.message.text.strip()
    
    # Get current conversation state
    convo = get_conversation(chat_id)
    
    try:
        # Check for commands
        if text.upper() == "OK":
            # User confirmed the mediated text
            convo = handle_event(convo, EventType.COMMAND_OK)
            await update.message.reply_text("✅ Texto confirmado. Continuamos.")
        
        elif text.upper() == "CANCELAR":
            # User canceled the process
            convo = handle_event(convo, EventType.COMMAND_CANCELAR)
            await update.message.reply_text("❌ Proceso cancelado.")
        
        elif text.upper() == "EDITAR":
            # User wants to edit - wait for new text
            await update.message.reply_text("✏️ Pega el texto editado a continuación.")
        
        else:
            # User provided edited text
            convo = handle_event(convo, EventType.TEXT_RECEIVED, text)
            await update.message.reply_text(
                "✍️ Texto recibido.\nPuedes editarlo o responder OK."
            )
        
        # Save updated state
        save_conversation(chat_id, convo)
    
    except Exception as e:
        await update.message.reply_text(f"⚠️ Error: {e}")
```

**Key Points:**
- Simpler than voice handler
- No file download needed
- Routes based on command words
- Can process edited text

---

### 3. **State Machine: `bot/state/machine.py`**

**Purpose:** Enforce valid state transitions, prevent invalid combinations

```python
# Valid state transitions:
IDLE (start)
  ├─ VOICE_RECEIVED → TRANSCRIBED
  └─ (any other event → ERROR)

TRANSCRIBED
  ├─ TEXT_RECEIVED (transcript) → MEDIATED
  └─ (any other event → ERROR)

MEDIATED
  ├─ TEXT_RECEIVED (mediated text) → AWAITING_EDIT
  ├─ COMMAND_OK → CONFIRMED
  ├─ COMMAND_EDITAR → AWAITING_EDIT
  └─ COMMAND_CANCELAR → IDLE

AWAITING_EDIT
  ├─ TEXT_RECEIVED (new text) → AWAITING_EDIT
  ├─ COMMAND_OK → CONFIRMED
  └─ COMMAND_CANCELAR → IDLE

CONFIRMED → IDLE (always)
```

**Why a State Machine?**
- Prevents invalid operations (e.g., can't say "OK" before text exists)
- Makes code logic explicit and testable
- Documents all possible flows
- Catches bugs early with InvalidTransition exception

---

### 4. **Services: `bot/services/`**

#### Transcription Service

```python
def transcribe_audio(file_path: str) -> str:
    """
    Convert audio file to text
    
    Currently: Stub returning dummy text
    TODO: Implement with Whisper, Google Speech-to-Text, etc.
    """
    return "transcripción de prueba"
```

#### Mediation Service

```python
def mediate_text(raw_text: str) -> str:
    """
    Convert Venezuelan dialect Spanish to standard Spanish
    
    Flow:
    1. Create Mediator with Venezuelan profile
    2. Create GeminiClient (connects to Google Gemini)
    3. Call mediator.mediate() with text
    4. Extract mediated_text from result
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError("Missing GEMINI_API_KEY environment variable")
    
    mediator = Mediator(
        profile=VenezuelanDialectProfile(),
        llm=GeminiClient(api_key=api_key),
    )
    
    result = mediator.mediate(Text(content=raw_text))
    return result.mediated_text
```

**Key Points:**
- Uses `dialect_mediator` package (separate module)
- GeminiClient handles API communication
- VenezuelanDialectProfile defines dialect rules
- Returns mediated text

---

### 5. **State Storage: `bot/state/runtime.py`**

```python
# Current implementation: In-memory dict
_conversations = {}

def get_conversation(chat_id: int) -> Conversation:
    """Get or create conversation state for a user"""
    if chat_id not in _conversations:
        _conversations[chat_id] = Conversation()  # Start in IDLE state
    return _conversations[chat_id]

def save_conversation(chat_id: int, convo: Conversation):
    """Save conversation state for a user"""
    _conversations[chat_id] = convo
```

**Limitations:**
- Data lost when bot restarts
- All users' data in memory (doesn't scale)
- No persistence

**Future Improvements:**
- Replace with database (PostgreSQL, MongoDB)
- Add expiration for old conversations
- Add logging/auditing

---

## 🎯 State Machine Walkthrough {#state-machine}

### Complete User Journey Example

```
USER → BOT

1. User starts, sends voice message (Spanish, Venezuelan dialect)
   "Che, como estah toh?"
   ↓
   Handler: voice.py
   FSM State: IDLE → TRANSCRIBED
   Action: transcribe_audio() called
   ↓

2. Bot displays transcript
   Output: "Che, como estah toh?"
   ↓
   Handler: voice.py (continuation)
   FSM State: TRANSCRIBED → MEDIATED
   Action: mediate_text() called
   ↓

3. Bot displays mediated text
   Output: "Oye, ¿cómo estás tú?"
   User is asked: OK / EDITAR / CANCELAR
   ↓
   FSM State: MEDIATED → AWAITING_EDIT
   ↓

4a. User chooses EDITAR
   Message: "EDITAR"
   ↓
   Handler: text.py
   FSM State: AWAITING_EDIT (no transition)
   Action: ask for edited text
   ↓

5a. User sends custom edit
   Message: "Oye, ¿cómo está usted?"
   ↓
   Handler: text.py
   FSM State: AWAITING_EDIT → AWAITING_EDIT (update mediated_text)
   Action: save new text as mediated_text
   ↓

6a. User confirms
   Message: "OK"
   ↓
   Handler: text.py
   FSM State: AWAITING_EDIT → CONFIRMED
   Action: mark as confirmed
   ↓

7. Bot acknowledges
   Output: "✅ Texto confirmado. Continuamos."
   ↓
   FSM State: CONFIRMED → IDLE
   ↓

8. Bot is ready for next message
   FSM State: IDLE
```

---

## 🚀 Adding Features {#adding-features}

### Checklist for New Features

```
1. Define what state(s) the feature affects
2. Add new EventType to machine.py if needed
3. Add state transitions to handle_event()
4. Create service if needed (bot/services/)
5. Create handler if needed (bot/handlers/)
6. Update models.py if new data needed
7. Test the FSM transitions
8. Add error handling
```

### Example 1: Add Language Selection

**Current:** Spanish only (Venezuelan → Standard)
**Goal:** Let users choose which dialect to mediate

**Steps:**

1. **Add new event to state machine:**
```python
# bot/state/machine.py
class EventType(Enum):
    # ... existing ...
    LANGUAGE_SELECTED = "language_selected"  # NEW
```

2. **Add new state:**
```python
# bot/state/models.py
class BotState(Enum):
    # ... existing ...
    SELECTING_LANGUAGE = "selecting_language"  # NEW
```

3. **Update Conversation model:**
```python
@dataclass
class Conversation:
    state: BotState = BotState.IDLE
    transcript: Optional[str] = None
    mediated_text: Optional[str] = None
    language: Optional[str] = None  # NEW
    dialect: Optional[str] = None   # NEW
```

4. **Add FSM transitions:**
```python
# bot/state/machine.py
# Add to handle_event():
if state == BotState.SELECTING_LANGUAGE:
    if event == EventType.LANGUAGE_SELECTED:
        return Conversation(
            state=BotState.IDLE,
            language=payload,  # "Spanish", "Portuguese", etc.
        )
```

5. **Create handler for /start command:**
```python
# bot/handlers/commands.py (new file)
async def start_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    convo = Conversation(state=BotState.SELECTING_LANGUAGE)
    save_conversation(chat_id, convo)
    
    await update.message.reply_text(
        "Elige idioma:\n"
        "1️⃣ Español\n"
        "2️⃣ Portugués\n"
        "3️⃣ Otro"
    )
```

6. **Update text handler to process selection:**
```python
# bot/handlers/text.py
if convo.state == BotState.SELECTING_LANGUAGE:
    if text == "1":
        convo.language = "Spanish"
        convo = handle_event(convo, EventType.LANGUAGE_SELECTED, "Spanish")
        # ... save and continue
```

---

### Example 2: Add Database Storage

**Current:** In-memory dict (loses data on restart)
**Goal:** Persist to PostgreSQL

**Steps:**

1. **Install database package:**
```bash
pip install psycopg2-binary sqlalchemy
```

2. **Create database models:**
```python
# bot/state/db.py
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.orm import declarative_base

Base = declarative_base()

class ConversationDB(Base):
    __tablename__ = "conversations"
    
    chat_id = Column(Integer, primary_key=True)
    state = Column(String)
    transcript = Column(String, nullable=True)
    mediated_text = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.now)
    updated_at = Column(DateTime, default=datetime.now, onupdate=datetime.now)

# Connection
engine = create_engine('postgresql://user:password@localhost/editorbot')
Base.metadata.create_all(engine)
Session = sessionmaker(bind=engine)
```

3. **Replace runtime.py with DB calls:**
```python
# bot/state/runtime.py
from sqlalchemy.orm import Session
from .db import ConversationDB, Session as SessionLocal

def get_conversation(chat_id: int) -> Conversation:
    session = SessionLocal()
    db_conv = session.query(ConversationDB).filter_by(chat_id=chat_id).first()
    
    if not db_conv:
        return Conversation()  # Default IDLE
    
    return Conversation(
        state=BotState[db_conv.state],
        transcript=db_conv.transcript,
        mediated_text=db_conv.mediated_text,
    )

def save_conversation(chat_id: int, convo: Conversation):
    session = SessionLocal()
    db_conv = session.query(ConversationDB).filter_by(chat_id=chat_id).first()
    
    if not db_conv:
        db_conv = ConversationDB(chat_id=chat_id)
    
    db_conv.state = convo.state.value
    db_conv.transcript = convo.transcript
    db_conv.mediated_text = convo.mediated_text
    
    session.add(db_conv)
    session.commit()
    session.close()
```

---

### Example 3: Add Custom Dialect Profile

**Current:** Only Venezuelan dialect
**Goal:** Support Rioplatense (Argentine) and other dialects

**Steps:**

1. **Dialect profiles already exist in `dialect_mediator`:**
```python
# Available in dialect_mediator/profiles/
# - venezuelan.py (already using)
# - rioplatense.py (already available)
```

2. **Create a profile selector:**
```python
# bot/services/mediation.py
from dialect_mediator.profiles.venezuelan import VenezuelanDialectProfile
from dialect_mediator.profiles.rioplatense import RioplatenseDialectProfile

DIALECT_PROFILES = {
    "Venezuelan": VenezuelanDialectProfile(),
    "Argentine": RioplatenseDialectProfile(),
}

def mediate_text(raw_text: str, dialect: str = "Venezuelan") -> str:
    profile = DIALECT_PROFILES.get(dialect, VenezuelanDialectProfile())
    
    mediator = Mediator(
        profile=profile,
        llm=GeminiClient(api_key=os.environ["GEMINI_API_KEY"]),
    )
    
    result = mediator.mediate(Text(content=raw_text))
    return result.mediated_text
```

3. **Update handlers to pass dialect:**
```python
# bot/handlers/voice.py
mediated = mediate_text(transcript, convo.dialect or "Venezuelan")
```

---

### Example 4: Add Logging and Monitoring

**Current:** Only print() statements
**Goal:** Professional logging for debugging and monitoring

**Steps:**

1. **Create logging config:**
```python
# bot/config/logging.py
import logging
from logging.handlers import RotatingFileHandler

def setup_logging():
    logger = logging.getLogger('editorbot')
    logger.setLevel(logging.DEBUG)
    
    # File handler (persistent)
    fh = RotatingFileHandler(
        'logs/editorbot.log',
        maxBytes=10*1024*1024,  # 10MB
        backupCount=5
    )
    fh.setLevel(logging.DEBUG)
    
    # Console handler (live view)
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)
    
    # Formatter
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    fh.setFormatter(formatter)
    ch.setFormatter(formatter)
    
    logger.addHandler(fh)
    logger.addHandler(ch)
    
    return logger

# Usage
logger = setup_logging()
```

2. **Add logging to handlers:**
```python
# bot/handlers/voice.py
logger.info(f"Voice message from {chat_id}")
logger.debug(f"Transcript: {transcript}")
logger.info(f"Mediation complete: {mediated[:50]}...")  # Log first 50 chars
```

---

## 📖 Extension Examples {#examples}

### Feature 1: Save Conversation History

```python
# Add to Conversation model:
@dataclass
class Conversation:
    # ... existing fields ...
    history: list[dict] = field(default_factory=list)  # NEW

# Add to handlers:
def save_to_history(chat_id, event_type, data):
    convo = get_conversation(chat_id)
    convo.history.append({
        'timestamp': datetime.now(),
        'event': event_type,
        'data': data,
    })
    save_conversation(chat_id, convo)
```

### Feature 2: Export Mediated Text

```python
# bot/handlers/commands.py
async def export_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    chat_id = update.effective_chat.id
    convo = get_conversation(chat_id)
    
    if convo.mediated_text:
        # Create formatted text
        export_text = f"""
        Original (Transcript): {convo.transcript}
        Mediated (Standard): {convo.mediated_text}
        """
        
        await update.message.reply_text(export_text)
    else:
        await update.message.reply_text("No mediated text to export")
```

### Feature 3: Rate Limiting

```python
# bot/middleware/rate_limiter.py
from datetime import datetime, timedelta

rate_limits = {}

def check_rate_limit(chat_id, max_requests=10, time_window=60):
    """Allow max_requests per time_window seconds"""
    now = datetime.now()
    
    if chat_id not in rate_limits:
        rate_limits[chat_id] = []
    
    # Remove old requests outside window
    rate_limits[chat_id] = [
        req_time for req_time in rate_limits[chat_id]
        if now - req_time < timedelta(seconds=time_window)
    ]
    
    if len(rate_limits[chat_id]) >= max_requests:
        return False  # Rate limit exceeded
    
    rate_limits[chat_id].append(now)
    return True  # OK

# Usage in handlers:
if not check_rate_limit(chat_id):
    await update.message.reply_text("⏰ Too many requests. Please wait.")
    return
```

### Feature 4: User Preferences

```python
# bot/state/models.py
@dataclass
class UserPreferences:
    preferred_dialect: str = "Venezuelan"
    auto_confirm: bool = False
    language: str = "Spanish"

@dataclass
class Conversation:
    # ... existing fields ...
    preferences: UserPreferences = field(default_factory=UserPreferences)

# Storage in database for persistence
```

---

## 🎓 Key Concepts to Remember

### 1. **Async/Await Pattern**
- All handlers are `async def`
- Use `await` for any I/O operation (API calls, file downloads)
- Allows handling multiple users simultaneously

### 2. **State Machine Benefits**
- Explicit state transitions prevent bugs
- Easy to visualize all possible flows
- InvalidTransition catches programming errors
- Deterministic behavior

### 3. **Separation of Concerns**
- **Handlers:** Input/output, user interaction
- **Services:** Business logic (transcription, mediation)
- **State Machine:** Workflow coordination
- **Storage:** Persistence layer

### 4. **Error Handling**
- Try-except blocks in handlers
- Graceful error messages to users
- Log errors for debugging
- Never crash without user feedback

### 5. **Testing Strategy**
```python
# Test state transitions independently
def test_state_machine():
    convo = Conversation()
    
    convo = handle_event(convo, EventType.VOICE_RECEIVED)
    assert convo.state == BotState.TRANSCRIBED
    
    convo = handle_event(convo, EventType.TEXT_RECEIVED, "test")
    assert convo.state == BotState.MEDIATED

# Test handlers with mock Update objects
async def test_handle_text():
    mock_update = Mock()
    mock_update.effective_chat.id = 12345
    mock_update.message.text = "OK"
    
    await handle_text(mock_update, Mock())
    # Assert response sent
```

---

## 🔗 Architecture Decision Records

### Why Finite State Machine?
- **Pro:** Explicit, testable, prevents invalid states
- **Con:** Slightly more boilerplate code
- **Decision:** FSM is worth it for clarity and correctness

### Why In-Memory Storage?
- **Pro:** Simple, fast for development
- **Con:** Data lost on restart, doesn't scale
- **Decision:** Use for MVP, replace with DB in production

### Why Telegram Bot API vs WebHook?
- **Pro (Polling):** Simpler setup, works behind NAT/firewall
- **Con (Polling):** Higher latency, more API calls
- **Decision:** Polling fine for this use case, switch to WebHook if needed

### Why Single Mediator per Dialect?
- **Pro:** Simple, less configuration
- **Con:** Limited flexibility
- **Decision:** Refactor to support multiple dialects in phase 2

---

## 📋 Next Steps for Development

### Phase 1: Core Stability ✅ (Done)
- [x] Basic voice message handling
- [x] State machine working
- [x] Mediation service integrated

### Phase 2: Features (Next)
- [ ] Implement real transcription (replace stub)
- [ ] Add database persistence
- [ ] Support multiple dialects
- [ ] Add command handlers (/start, /help, /settings)
- [ ] Add logging

### Phase 3: Production Ready (After Phase 2)
- [ ] Error tracking (Sentry)
- [ ] Performance monitoring
- [ ] Rate limiting
- [ ] User feedback system
- [ ] Admin dashboard

### Phase 4: Advanced Features (Future)
- [ ] User authentication
- [ ] Payment integration
- [ ] Batch processing
- [ ] Webhook mode instead of polling
- [ ] Multi-language support

---

## 🆘 Common Debugging Patterns

```python
# Check FSM state
convo = get_conversation(chat_id)
print(f"Current state: {convo.state}")
print(f"Transcript: {convo.transcript}")
print(f"Mediated: {convo.mediated_text}")

# Test service directly
from bot.services.mediation import mediate_text
result = mediate_text("Che, como estah?")
print(f"Result: {result}")

# Test handler without Telegram
async def test_handler():
    from unittest.mock import Mock, AsyncMock
    update = Mock()
    update.effective_chat.id = 123
    update.message.text = "OK"
    context = Mock()
    await handle_text(update, context)

# Check environment
import os
print(f"Token set: {bool(os.environ.get('TELEGRAM_BOT_TOKEN'))}")
print(f"API key set: {bool(os.environ.get('GEMINI_API_KEY'))}")
```

---

**Happy coding! Feel free to extend this bot with the patterns shown above.** 🚀
