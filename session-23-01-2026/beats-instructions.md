# Beat Libraries — Narrative Primitives

**Project:** EditorBot
**Status:** LOCKED
**Layer:** Narrative Engine
**Depends on:** Template Taxonomy
**Audience:** LLM prompts, validators, render planners

---

## 1. What a “Beat” Is (Strict Definition)

A **beat** is the **smallest narratively meaningful unit** in a script.

A beat is:

* atomic (cannot be split without losing intent)
* timed (has duration implications)
* semantically labeled (role-driven)

A beat is **not**:

* a sentence
* a paragraph
* a visual scene (but it may map to one)

---

## 2. Why Beat Libraries Exist

Beat libraries exist to:

* give the LLM a **controlled vocabulary**
* prevent structural drift
* make scripts machine-actionable
* enable future automation (visuals, pacing, captions)

> If a beat is not in the library, it does not exist.

---

## 3. Canonical Beat Roles (Global)

These beats are **shared across all templates**, but not all templates may allow them.

### 3.1 Attention & Entry Beats

| Beat                | Purpose                       |
| ------------------- | ----------------------------- |
| `hook`              | Capture attention immediately |
| `provocation`       | Challenge or question         |
| `opening_statement` | Calm, declarative entry       |

---

### 3.2 Context Beats

| Beat      | Purpose                 |
| --------- | ----------------------- |
| `context` | Establish background    |
| `setup`   | Prepare narrative space |
| `premise` | Define the core idea    |

---

### 3.3 Argument & Explanation Beats

| Beat            | Purpose                   |
| --------------- | ------------------------- |
| `argument`      | Main claim                |
| `support`       | Evidence or reinforcement |
| `example`       | Concrete illustration     |
| `counterpoint`  | Acknowledge opposition    |
| `clarification` | Reduce ambiguity          |

---

### 3.4 Narrative Beats

| Beat            | Purpose           |
| --------------- | ----------------- |
| `event`         | Something happens |
| `turning_point` | Narrative shift   |
| `resolution`    | Closure of story  |

---

### 3.5 Reflective Beats

| Beat          | Purpose                 |
| ------------- | ----------------------- |
| `reflection`  | Think aloud             |
| `association` | Lateral idea connection |
| `insight`     | Emergent understanding  |

---

### 3.6 Closing Beats

| Beat             | Purpose                   |
| ---------------- | ------------------------- |
| `conclusion`     | Summarize or land         |
| `implication`    | What this means           |
| `call_to_action` | Explicit ask (restricted) |

---

## 4. Template-to-Beat Mapping (LOCKED)

Each template family defines:

* required beats
* allowed beats
* forbidden beats

---

### 4.1 Opinion / Stance

**Required**

* `hook`
* `argument`

**Allowed**

* `counterpoint`
* `support`
* `conclusion`

**Forbidden**

* `exposition`
* `reflection`
* `call_to_action` (v1 rule)

**Typical Flow**

```
hook → argument → support → conclusion
```

---

### 4.2 Explainer / Teaching

**Required**

* `context`
* `explanation`

**Allowed**

* `example`
* `clarification`
* `summary`

**Forbidden**

* `provocation`

**Typical Flow**

```
context → explanation → example → summary
```

---

### 4.3 Narrated Thought / Essay

**Required**

* `reflection`

**Allowed**

* `association`
* `insight`
* `context`

**Forbidden**

* `hook`
* `call_to_action`

**Typical Flow**

```
reflection → association → insight
```

---

### 4.4 Story / Anecdote

**Required**

* `setup`
* `event`
* `resolution`

**Allowed**

* `turning_point`
* `reflection`

**Forbidden**

* `argument`

**Typical Flow**

```
setup → event → turning_point → resolution
```

---

### 4.5 Prompt / Provocation

**Required**

* `provocation`

**Allowed**

* `context` (minimal)

**Forbidden**

* `explanation`
* `summary`

**Typical Flow**

```
provocation
```

---

## 5. Beat Metadata (Machine-Readable)

Every generated beat must include:

```json
{
  "role": "hook",
  "text": "¿Alguna vez te preguntaste…?",
  "estimated_duration": 6,
  "intensity": "high",
  "visual_affinity": "text_overlay"
}
```

### Required Fields

* `role`
* `text`
* `estimated_duration`

### Optional Fields (future-proof)

* `intensity` (`low | medium | high`)
* `visual_affinity` (`static | motion | text_overlay | none`)

---

## 6. Enforcement Rules

* Beats **must appear in logical order**
* Required beats **must exist**
* Forbidden beats **must never be generated**
* Beat count must match template constraints

Violations are handled **internally** (retry, summarize, merge).

---

## 7. Why This Matters for Video

Because beats enable:

* automatic subtitle timing
* scene estimation
* pacing control
* future timeline editors

This is where **video production begins**, not at rendering.

---

## 8. Design Intent (Non-Negotiable)

> Beats are how the system thinks.

If you remove beats:

* templates collapse
* automation becomes impossible
* everything becomes ad-hoc again
