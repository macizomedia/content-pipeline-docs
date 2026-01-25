# LangGraph Architecture - High-Level Overview

## 📐 System Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                         TELEGRAM USER                                 │
│                         (chat_id:user_id)                             │
└─────────────────────────────┬────────────────────────────────────────┘
                              │
                              │ Voice/Text Messages
                              │ Commands: /init, /template, /start, /context, /reset, /skip
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    TELEGRAM HANDLERS LAYER                            │
│  ┌────────────────┐ ┌────────────────┐ ┌──────────────────────┐    │
│  │ commands.py    │ │ voice.py       │ │ text.py              │    │
│  │ (LangGraph)    │ │ (Legacy FSM)   │ │ (Legacy FSM)         │    │
│  └────────┬───────┘ └────────┬───────┘ └──────────┬───────────┘    │
└───────────┼──────────────────┼────────────────────┼──────────────────┘
            │                  │                    │
            │   Feature Flag   │    Feature Flag    │
            │   Check          │    Check           │
            │   (use_langgraph_for_user())          │
            │                  │                    │
┌───────────▼──────────────────▼────────────────────▼──────────────────┐
│                    ROUTING DECISION                                   │
│  if LANGGRAPH_ROLLOUT_PCT > user_hash:                               │
│      → LangGraph System                                              │
│  else:                                                               │
│      → Legacy FSM System                                             │
└───────────┬──────────────────┬────────────────────────────────────────┘
            │                  │
            │ (90-100%)        │ (0-10%, deprecated)
            │                  │
            ▼                  ▼
┌─────────────────────┐ ┌─────────────────────┐
│  LANGGRAPH SYSTEM   │ │  LEGACY FSM SYSTEM  │
│  (New, Agentic)     │ │  (Old, Deprecated)  │
└─────────┬───────────┘ └─────────────────────┘
          │
          │
          ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    LANGGRAPH STATE MACHINE                            │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────┐    │
│  │                    GRAPH STATE                              │    │
│  │  • chat_id, user_id, thread_id                            │    │
│  │  • config (format, style, assistance_level)               │    │
│  │  • messages (conversation history)                         │    │
│  │  • template_id, template_spec, template_requirements      │    │
│  │  • payload (hook, content, call_to_action, context)       │    │
│  │  • validation_result, validation_attempts                 │    │
│  │  • current_phase (init → collection → validation → finalized) │
│  └────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌─────────┐      ┌─────────┐      ┌─────────┐      ┌─────────┐   │
│  │ INTAKE  │─────▶│COLLECTOR│◀────▶│VALIDATOR│─────▶│FINALIZE │   │
│  └─────────┘      └─────────┘      └─────────┘      └─────────┘   │
│                         │ ▲            │ ▲                          │
│                         │ │            │ │                          │
│                         │ └────────────┘ │                          │
│                         │  Retry loop    │                          │
│                         │  (max 2-5x)    │                          │
│                         └────────────────┘                          │
│                    Self-correction cycle                            │
│                                                                       │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            │ Checkpoint after each node
                            │
                            ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    SQLITE CHECKPOINTER                                │
│  File: /app/data/checkpoints.db                                     │
│                                                                       │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐               │
│  │ Thread 1     │ │ Thread 2     │ │ Thread N     │               │
│  │ (123:456)    │ │ (789:012)    │ │ (345:678)    │               │
│  │ State: {...} │ │ State: {...} │ │ State: {...} │               │
│  └──────────────┘ └──────────────┘ └──────────────┘               │
│                                                                       │
│  Benefits:                                                           │
│  • Survives bot restarts                                            │
│  • Resume interrupted conversations                                 │
│  • Audit trail of all state transitions                             │
└────────────────────────┬──────────────────────────────────────────────┘
                         │
                         │
                         ▼
┌──────────────────────────────────────────────────────────────────────┐
│                    EXTERNAL SERVICES                                  │
│  ┌───────────────┐ ┌──────────────┐ ┌────────────────────┐         │
│  │ Whisper       │ │ Gemini LLM   │ │ Template API       │         │
│  │ (Transcribe)  │ │ (Intent/Val) │ │ (Lambda Gateway)   │         │
│  └───────────────┘ └──────────────┘ └────────────────────┘         │
│  ┌───────────────┐ ┌──────────────┐ ┌────────────────────┐         │
│  │ S3 Storage    │ │ CloudWatch   │ │ Render Plan Builder│         │
│  │ (Audio files) │ │ (Logs)       │ │ (Deterministic)    │         │
│  └───────────────┘ └──────────────┘ └────────────────────┘         │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Through Nodes

### 1. INTAKE NODE
```
Input:  GraphState with new message (voice or text)
Process:
  • If voice: Download from Telegram → Transcribe with Whisper
  • Mediate text (neutralize dialect) via Gemini
  • Add transcription to conversation history
Output: Updated GraphState with transcript + mediated_text
```

### 2. REQUIREMENT COLLECTOR NODE
```
Input:  GraphState with template requirements
Process:
  • Check which fields are missing from payload
  • If user provided input:
      → Extract field values via LLM (few-shot prompting)
      → Update payload
  • If required fields still missing:
      → Ask for next field
      → Stay in collection phase (loop)
  • If all required collected:
      → Move to validation phase
  • Premium users: Auto-fill optional fields via LLM
Output: Updated GraphState with new payload fields + next_field_to_collect
```

### 3. VALIDATOR NODE
```
Input:  GraphState with complete payload
Process:
  • Use Gemini Pro to validate:
      - All required fields present?
      - Content appropriate for template?
      - Text length reasonable?
  • Increment validation_attempts counter
  • If valid:
      → Move to finalized phase
  • If invalid and under retry limit:
      → Generate specific feedback
      → Route back to collection
  • If max retries exceeded:
      → Trigger human-in-loop interrupt
Output: Updated GraphState with validation_result + new phase
```

### 4. FINALIZE NODE
```
Input:  GraphState with validated payload
Process:
  • Generate render plan (deterministic, not AI)
  • Mark conversation as complete
  • Prepare for render execution
Output: Final GraphState with render_plan + finalized phase
```

---

## 🎚️ Assistance Level Impact

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ASSISTANCE LEVEL MATRIX                           │
├──────────────┬───────────────┬────────────────┬──────────────────────┤
│ Level        │ Max Retries   │ Auto-fill      │ Use Case             │
├──────────────┼───────────────┼────────────────┼──────────────────────┤
│ BASIC        │ 2             │ No             │ Free users, testing  │
│ STANDARD     │ 3             │ Yes (some)     │ Regular creators     │
│ PREMIUM      │ 5             │ Yes (all)      │ Power users, high-vol│
└──────────────┴───────────────┴────────────────┴──────────────────────┘

Flow Example (BASIC user):

User: /start
Bot:  📋 Please provide: Hook

User: My hook here
Bot:  ✅ Saved! 📋 Please provide: Content

User: Short content
Bot:  ✅ Validating...
      ⚠️ Validation failed (1/2): Content too short

User: Better content here
Bot:  ✅ Validating...
      ⚠️ Validation failed (2/2): Still too short

      ⚠️ Max retries exceeded. Commands: /reset | /skip

User: /skip
Bot:  ⚠️ Validation skipped! Proceeding...
      🎬 Render plan generated.

---

Flow Example (PREMIUM user):

User: /start
Bot:  📋 Please provide: Hook

User: Hook: Great hook. Content: Amazing detailed content that meets all requirements.
Bot:  ✅ Extracted: hook, content
      🤖 Auto-filled: call_to_action
      ✅ Validating... (1/5)

      ✅ Valid! Moving to finalization...
      🎬 Render plan generated.
```

---

## 🔀 Conditional Routing Logic

```python
# After INTAKE
def route_after_intake(state):
    if state["current_phase"] == "error":
        return END  # Halt on error
    if not state.get("template_id"):
        return "collection"  # Prompt for template
    return "collection"  # Start collection

# After COLLECTION
def route_after_collection(state):
    if state["current_phase"] == "error":
        return END
    if state["current_phase"] == "validation":
        return "validation"  # All fields collected
    return "collection"  # Loop: wait for more input

# After VALIDATION (Self-correction loop)
def route_after_validation(state):
    if state["current_phase"] == "error":
        return END
    if state.get("interrupt_for_human"):
        return END  # Max retries exceeded
    if state["current_phase"] == "finalized":
        return "finalize"  # Validation passed
    return "collection"  # Retry with feedback

# After FINALIZE
# Always END (conversation complete)
```

---

## 💾 State Persistence Flow

```
┌──────────────┐
│ User sends   │
│ message      │
└──────┬───────┘
       │
       ▼
┌──────────────────────┐
│ Handler receives     │
│ Update from Telegram │
└──────┬───────────────┘
       │
       ▼
┌─────────────────────────────┐
│ Load state from SQLite      │
│ thread_id = f"{chat_id}:{user_id}" │
└──────┬──────────────────────┘
       │
       ▼
┌───────────────────────────┐
│ Add message to state      │
│ messages.append(...)      │
└──────┬────────────────────┘
       │
       ▼
┌────────────────────────────┐
│ Invoke graph              │
│ graph.ainvoke(state, config) │
└──────┬─────────────────────┘
       │
       │ ┌──────────────────┐
       ├─▶│ INTAKE NODE      │
       │ │ Execute + Update │
       │ └──────┬───────────┘
       │        │ Checkpoint saved
       │        ▼
       │ ┌──────────────────┐
       ├─▶│ COLLECTION NODE  │
       │ │ Execute + Update │
       │ └──────┬───────────┘
       │        │ Checkpoint saved
       │        ▼
       │ ┌──────────────────┐
       └─▶│ (next node...)   │
           └──────────────────┘

Each node execution → automatic checkpoint to SQLite
```

**Benefits:**
- Resume conversation after bot crash/restart
- Audit trail: replay any conversation from checkpoints
- Debug: inspect state at any point in time

---

## 🧪 Testing Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    TEST FIXTURES                                │
│  • basic_user_state                                            │
│  • premium_user_state                                          │
│  • state_with_template                                         │
│  • test_graph (in-memory MemorySaver, no SQLite)              │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│              CONVERSATION REPLAY TESTS                          │
│                                                                 │
│  Simulate multi-turn conversations:                            │
│                                                                 │
│  test_full_conversation_happy_path():                          │
│    Step 1: User sends "/start"                                │
│    Step 2: User provides hook                                 │
│    Step 3: User provides content                              │
│    Assert: Validation passes, phase = "finalized"             │
│                                                                 │
│  test_validation_retry_loop():                                 │
│    Step 1: Pre-populate payload with bad data                 │
│    Step 2: Invoke validation                                  │
│    Assert: validation_attempts increments                      │
│    Step 3: Retry 3x                                           │
│    Assert: interrupt_for_human = True                          │
│                                                                 │
│  test_premium_user_auto_fill():                                │
│    Step 1: Provide only required fields                       │
│    Assert: LLM auto-fills optional fields                      │
└────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌────────────────────────────────────────────────────────────────┐
│            PARAMETERIZED SCENARIOS                              │
│                                                                 │
│  CONVERSATION_SCENARIOS = [                                    │
│    {"name": "happy_path_basic", ...},                          │
│    {"name": "validation_failure_retry", ...},                  │
│    {"name": "premium_auto_fill", ...},                         │
│  ]                                                             │
│                                                                 │
│  @pytest.mark.parametrize("scenario", CONVERSATION_SCENARIOS)  │
│  async def test_conversation_scenario(scenario):               │
│      # Execute turns from scenario                             │
│      # Assert expected outcomes                                │
└────────────────────────────────────────────────────────────────┘
```

**Mock Strategy:**
- Use `MemorySaver` instead of SQLite in tests
- Mock Gemini LLM calls with canned responses
- Test each node in isolation + full graph integration

---

## 🚩 Feature Flag Flow

```
┌──────────────┐
│ User sends   │
│ /init command│
└──────┬───────┘
       │
       ▼
┌─────────────────────────────────┐
│ Check feature flag              │
│                                 │
│ rollout_pct = env.LANGGRAPH_ROLLOUT_PCT │
│ user_hash = hash(f"{chat_id}:{user_id}") % 100 │
│                                 │
│ if user_hash < rollout_pct:    │
│     use_langgraph = True        │
│ else:                           │
│     use_langgraph = False       │
└─────────────┬───────────────────┘
              │
              ├─ True ─────────────┐
              │                    │
              ▼                    ▼
       ┌──────────────┐    ┌──────────────┐
       │ LangGraph    │    │ Legacy FSM   │
       │ Handler      │    │ Handler      │
       └──────────────┘    └──────────────┘

Rollout Schedule:
Week 1: LANGGRAPH_ROLLOUT_PCT=10  (10% of users)
Week 2: LANGGRAPH_ROLLOUT_PCT=50  (50% of users)
Week 3: LANGGRAPH_ROLLOUT_PCT=100 (100% of users)
```

**Properties:**
- **Deterministic:** Same user always gets same system
- **Gradual:** Control percentage with single env var
- **Safe:** Easy rollback (set to 0)
- **No state mixing:** User can't switch mid-conversation

---

## 📊 Cost Analysis

### LLM API Calls per Conversation

```
Legacy FSM:
  1. Mediation (dialect neutralization): 1 call
  Total: 1 call

LangGraph:
  1. Intake → Mediation: 1 call (same as legacy)
  2. Collection → Intent extraction: 5-10 calls (per user message)
  3. Validation: 1-3 calls (per validation attempt)
  4. Premium auto-fill: 0-1 call (optional fields)
  Total: 7-15 calls (3-4x increase)

Cost Mitigation:
  • Use gemini-2.0-flash for intent (10x cheaper than pro)
  • Use gemini-2.5-pro only for final validation
  • Enable prompt caching (LangGraph built-in, ~50% reduction)
  • Batch multiple fields in one extraction call
```

### Example Cost Calculation

```
Assume:
  • gemini-2.0-flash: $0.01 per 1M input tokens
  • gemini-2.5-pro: $0.10 per 1M input tokens
  • Average conversation: 10 messages, 1000 tokens total

Legacy FSM:
  1 mediation call (pro) = 1000 tokens = $0.0001

LangGraph:
  8 intent calls (flash) = 8000 tokens = $0.00008
  2 validation calls (pro) = 2000 tokens = $0.0002
  Total = $0.00028 per conversation

Cost increase: 2.8x (but better UX, resumable conversations)
```

---

## 🎓 Key Architectural Decisions

### 1. Why LangGraph over Custom FSM?

**Benefits:**
- ✅ Built-in checkpointing (SQLite, Postgres)
- ✅ Automatic error recovery
- ✅ Streaming support
- ✅ Human-in-loop interrupts
- ✅ Graph visualization tools
- ✅ Production-ready (used by LangChain team)

**Trade-offs:**
- ❌ Learning curve (new paradigm)
- ❌ More dependencies
- ❌ Slightly slower (checkpointing overhead)

### 2. Why SQLite over Redis/Postgres?

**Benefits:**
- ✅ No external service (simpler deployment)
- ✅ File-based (easy backup/restore)
- ✅ Good enough for single-instance bot
- ✅ Zero configuration

**Future:**
- Migrate to Postgres if scaling to multi-instance

### 3. Why Assistance Levels?

**Benefits:**
- ✅ Prevents infinite loops (max retry limits)
- ✅ Monetization path (premium tier)
- ✅ Better UX (power users get more autonomy)
- ✅ Cost control (basic users = fewer LLM calls)

### 4. Why Feature Flag?

**Benefits:**
- ✅ Gradual rollout (de-risk deployment)
- ✅ A/B testing (compare systems)
- ✅ Easy rollback (set to 0)
- ✅ No code changes (env var only)

---

## 🔮 Future Enhancements

1. **Streaming to Telegram**
   - Currently: LLM streams internally, Telegram gets final result
   - Future: Stream tokens to Telegram with batched updates (1/sec rate limit)

2. **Sub-Graphs for Complex Templates**
   - Currently: Flat collection loop
   - Future: Nested sub-graphs for multi-step templates

3. **Conversation Analytics**
   - Track: validation retry rate, time to completion, field extraction accuracy
   - Dashboard: Grafana + CloudWatch metrics

4. **Multi-Language Support**
   - Auto-detect user language from first message
   - Translate prompts dynamically

5. **Render Plan Integration**
   - Currently: Finalize node just marks complete
   - Future: Call render plan builder → trigger video generation

---

**Questions? Refer to [LANGGRAPH_MIGRATION.md](LANGGRAPH_MIGRATION.md) for detailed usage guide!**
