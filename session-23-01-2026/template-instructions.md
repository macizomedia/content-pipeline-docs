## Template Taxonomy & Integration Contract

**Project:** EditorBot Content Pipeline
**Status:** LOCKED (Do not improvise)
**Audience:** Coding agents, contributors, future maintainers
**Last updated:** 2026-01

---

## 1. Purpose of this Document

This document defines the **official template taxonomy** used by EditorBot and the **rules governing how templates integrate with the state machine, LLM prompts, and rendering pipeline**.

This is a **design contract**, not a suggestion.

Any implementation **must conform** to this document unless explicitly revised.

---

## 2. Core Design Principle

> **Templates are affordances, not validators.**

Templates:

* Guide generation
* Constrain creativity early
* Define audience expectations

Templates **must not**:

* Reject user content after generation
* Surprise users with late failures
* Act as post-hoc judges

---

## 3. Canonical Template Families (LOCKED)

EditorBot supports **five template families**.
These represent **audience relationships**, not formats.

### 3.1 Opinion / Stance

**Intent:** Express a clear viewpoint
**Audience relationship:** Speaker → Audience

**Use cases:**

* Political commentary
* Cultural critique
* Editorial opinion

**Narrative characteristics:**

* Strong hook
* Linear argument
* Clear conclusion

**Typical constraints:**

* Duration: 60-90s
* Required beats: `hook`, `argument`
* Optional beats: `counterpoint`, `conclusion`
* Forbidden beats: `exposition`, `call_to_action`

---

### 3.2 Explainer / Teaching

**Intent:** Help the audience understand
**Audience relationship:** Guide → Learner

**Use cases:**

* Journalism
* Education
* Contextual breakdowns

**Narrative characteristics:**

* Structured explanation
* Visual support encouraged

**Typical constraints:**

* Duration: 45–120s
* Required beats: `context`, `explanation`
* Optional beats: `example`, `summary`

---

### 3.3 Narrated Thought / Essay

**Intent:** Explore an idea reflectively
**Audience relationship:** Thinker ↔ Listener

**Use cases:**

* Philosophy
* Long-form reasoning
* Reflective commentary

**Narrative characteristics:**

* Slower pacing
* Fewer, deeper beats
* Atmospheric tone

**Typical constraints:**

* Duration: 60–180s
* Required beats: `reflection`
* Optional beats: `association`, `insight`

---

### 3.4 Story / Anecdote

**Intent:** Tell a story
**Audience relationship:** Storyteller → Listener

**Use cases:**

* Personal anecdotes
* Case studies
* Narrative journalism

**Narrative characteristics:**

* Clear beginning, middle, end
* Emotional arc

**Typical constraints:**

* Duration: 45–120s
* Required beats: `setup`, `event`, `resolution`

---

### 3.5 Prompt / Provocation

**Intent:** Trigger thought or engagement
**Audience relationship:** Instigator → Audience

**Use cases:**

* Teasers
* Questions
* Conceptual prompts

**Narrative characteristics:**

* Single idea
* Strong ending

**Typical constraints:**

* Duration: 15–30s
* Required beats: `provocation`
* Forbidden beats: `explanation`

---

## 4. Formats Are Secondary (Important)

Formats (Reel, Slides, 16:9, etc.) are **delivery skins**, not templates.

A template family:

* **MAY** support multiple formats
* **MUST NOT** be named after a format

Examples:

* ❌ `ReelTemplate`
* ✅ `Opinion → REEL_VERTICAL`

---

## 5. TemplateSpec Contract (Implementation Guidance)

Each concrete template **must** declare:

```json
{
  "template_family": "opinion",
  "intent_profile": "stance",
  "audience_relationship": "speaker_to_audience",
  "allowed_formats": ["REEL_VERTICAL"],
  "duration": {
    "min_seconds": 30,
    "target_seconds": 45,
    "max_seconds": 60
  },
  "script_structure": {
    "allowed_structure_types": ["linear_argument"],
    "min_beats": 3,
    "max_beats": 5,
    "required_roles": ["hook", "argument"],
    "optional_roles": ["conclusion"],
    "forbidden_roles": ["exposition"]
  }
}
```

---

## 6. State Machine Integration (MANDATORY)

Template selection **must occur before script generation**.

Canonical order:

```
MEDIATED
  ↓
TEMPLATE_SELECTED
  ↓
SCRIPT_DRAFTED
```

The LLM prompt **must inject template constraints** at generation time.

Post-generation rejection is **not allowed**.

---

## 7. Validator Role (Internal Only)

Validation logic:

* Runs internally
* Auto-corrects or retries generation
* Never blocks the user unless catastrophic

User-facing validation errors are **explicitly forbidden**.

---

## 8. UX Copy Rules

The bot must:

* Speak in human terms
* Frame templates as creative choices

Allowed:

> “How should this story live?”

Forbidden:

> “This script does not comply with the template.”

---

## 9. What Is Explicitly Out of Scope (v1)

The following are **not supported** and must not be added implicitly:

* Meme templates
* Trend-following formats
* Duets / stitches
* AI avatars
* Multi-speaker scripts

---

## 10. Extension Rules (Future-Safe)

New templates:

* Must belong to an existing family **or**
* Introduce a new family via documentation first

No ad-hoc additions.

---

## 11. Design Intent Summary

EditorBot is not a bot.

It is:

> **A voice-driven video editor that guides, constrains, and collaborates.**

All implementation decisions must preserve this mental model.

---

## 12. Change Process

Any change to this document requires:

1. Explicit discussion
2. Documentation update
3. Version bump

---

**END OF CONTRACT**

---