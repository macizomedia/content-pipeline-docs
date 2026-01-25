# Visual Strategy — Canonical Layer

**Project:** EditorBot
**Status:** LOCKED
**Layer:** Script → Render Plan
**Consumes:** Script Schema + TemplateSpec
**Produces:** Visual Plan

---

## 1. Purpose of the Visual Strategy

The Visual Strategy answers **one question only**:

> *Given this script and this template, how should visuals behave over time?*

It does **not**:

* generate images
* pick files
* render video

It **does**:

* decide *what kind* of visuals are needed
* decide *how many*
* decide *where they change*
* decide *who is responsible* (AI, static, text-only)

---

## 2. Visual Strategy Object (Top-Level)

```json
{
  "strategy_id": "uuid",
  "template_id": "opinion_monologue_reel",
  "format": "REEL_VERTICAL",
  "visual_mode": "mixed",
  "scene_count": 4,
  "scene_rules": {},
  "text_overlay_policy": {},
  "asset_sources": {}
}
```

---

## 3. Core Fields Explained

### 3.1 `visual_mode` (Critical)

```text
"text_only" | "slides" | "mixed" | "cinematic"
```

| Mode        | Meaning                |
| ----------- | ---------------------- |
| `text_only` | Subtitles + background |
| `slides`    | One visual per beat    |
| `mixed`     | Combination (default)  |
| `cinematic` | Scene-driven visuals   |

This is usually dictated by **TemplateSpec.visual_rules.visual_strategy**.

---

### 3.2 `scene_count`

```json
"scene_count": 4
```

* Defines how many **visual segments** exist
* Scenes ≠ beats (can be fewer or equal)
* Used later to generate or assign assets

---

## 4. Scene Rules

```json
"scene_rules": {
  "scene_alignment": "beat-driven",
  "max_scene_duration_seconds": 15,
  "allow_scene_reuse": false
}
```

### Common Values

| Field                        | Options                       |
| ---------------------------- | ----------------------------- |
| `scene_alignment`            | `beat-driven` / `time-driven` |
| `max_scene_duration_seconds` | Hard cap                      |
| `allow_scene_reuse`          | Reuse backgrounds             |

---

## 5. Text Overlay Policy

```json
"text_overlay_policy": {
  "enabled": true,
  "style": "subtitle_emphasis",
  "max_chars_per_line": 42,
  "highlight_keywords": true
}
```

This controls:

* subtitles
* kinetic text
* emphasis words

> This is where **design meets cognition**.

---

## 6. Asset Source Strategy

```json
"asset_sources": {
  "images": "ai_generated",
  "video_clips": "none",
  "backgrounds": "library",
  "music": "selected"
}
```

| Asset          | Options             |
| -------------- | ------------------- |
| `ai_generated` | Midjourney, SD, etc |
| `library`      | Pre-made            |
| `user_upload`  | Future              |
| `none`         | Skip                |

---

## 7. Example — Opinion Reel Visual Strategy

```json
{
  "strategy_id": "vs-001",
  "template_id": "opinion_monologue_reel",
  "format": "REEL_VERTICAL",
  "visual_mode": "mixed",
  "scene_count": 3,
  "scene_rules": {
    "scene_alignment": "beat-driven",
    "max_scene_duration_seconds": 20,
    "allow_scene_reuse": false
  },
  "text_overlay_policy": {
    "enabled": true,
    "style": "bold_keywords",
    "highlight_keywords": true
  },
  "asset_sources": {
    "images": "ai_generated",
    "backgrounds": "library",
    "music": "selected"
  }
}
```

---

## 8. Relationship to Beats (Important)

Mapping logic (example):

| Beat Role  | Visual Treatment     |
| ---------- | -------------------- |
| hook       | Fast cut + bold text |
| argument   | Stable background    |
| conclusion | Minimalist / fade    |

This mapping is **template-owned**, not LLM-owned.

---

## 9. Why This Layer Exists (Don Norman lens)

This layer:

* reduces cognitive load
* prevents surprise at render time
* makes intent visible before cost is incurred
* allows previews without generation

> The system explains *what will happen* before it happens.

