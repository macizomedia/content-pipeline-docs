# Render Plan Schema — Canonical

**Project:** EditorBot
**Status:** LOCKED
**Layer:** Visual Strategy → Rendering Engine
**Consumes:**

* Final Script
* TemplateSpec
* Visual Strategy

**Produces:**

* Deterministic render instructions

---

## 1. Purpose of the Render Plan

The Render Plan answers:

> *Exactly what happens on the timeline, second by second?*

It must be:

* deterministic
* serializable
* replayable
* debuggable

No AI decisions here.

---

## 2. Top-Level RenderPlan Object

```json
{
  "render_plan_id": "uuid",
  "format": "REEL_VERTICAL",
  "total_duration_seconds": 52,
  "fps": 30,
  "resolution": {
    "width": 1080,
    "height": 1920
  },
  "audio_tracks": [],
  "scenes": [],
  "subtitles": {},
  "output": {}
}
```

---

## 3. Audio Tracks

```json
"audio_tracks": [
  {
    "type": "voice",
    "source": "original",
    "start_time": 0.0,
    "volume": 1.0
  },
  {
    "type": "music",
    "source": "upbeat_energy_01",
    "start_time": 0.0,
    "volume": 0.25,
    "fade_in": 1.5,
    "fade_out": 2.0
  }
]
```

Rules:

* voice always wins
* music auto-ducked
* no mixing logic in renderer (already decided)

---

## 4. Scene Definition

Each scene is a **time-bounded visual container**.

```json
{
  "scene_id": "scene_1",
  "start_time": 0.0,
  "end_time": 14.2,
  "visual": {},
  "overlays": [],
  "transitions": {}
}
```

---

## 5. Visual Block (per Scene)

```json
"visual": {
  "type": "image",
  "source": "ai_generated",
  "prompt_ref": "hook_visual_01",
  "motion": "slow_zoom_in",
  "background_color": "#000000"
}
```

Allowed `type` values:

* `image`
* `video`
* `solid_color`
* `gradient`

---

## 6. Overlay Objects (Text, Graphics)

```json
"overlays": [
  {
    "type": "text",
    "content_ref": "beat_1.keywords",
    "position": "center",
    "start_time": 0.5,
    "end_time": 4.8,
    "style": "bold_caps",
    "animation": "fade_in_up"
  }
]
```

Key idea:

* overlays are **independent of visuals**
* multiple overlays per scene allowed

---

## 7. Subtitles Block

```json
"subtitles": {
  "enabled": true,
  "style": "subtitle_emphasis",
  "segments": [
    {
      "start": 0.0,
      "end": 3.2,
      "text": "¿Alguna vez te preguntaste…?",
      "highlight": ["preguntaste"]
    }
  ]
}
```

Subtitles are:

* global
* time-aligned
* language-aware

---

## 8. Transitions

```json
"transitions": {
  "in": {
    "type": "cut"
  },
  "out": {
    "type": "fade",
    "duration": 0.5
  }
}
```

Renderer does **exactly** this.

---

## 9. Output Definition

```json
"output": {
  "container": "mp4",
  "codec": "h264",
  "bitrate": "6M",
  "platform_profile": "instagram_reel",
  "filename": "editorbot_opinion_001.mp4"
}
```

Platform profiles are pre-defined constants.

---

## 10. Minimal Example (End-to-End)

```json
{
  "render_plan_id": "rp-001",
  "format": "REEL_VERTICAL",
  "total_duration_seconds": 52,
  "fps": 30,
  "resolution": { "width": 1080, "height": 1920 },
  "audio_tracks": [
    { "type": "voice", "source": "original", "start_time": 0, "volume": 1.0 }
  ],
  "scenes": [
    {
      "scene_id": "scene_1",
      "start_time": 0,
      "end_time": 15,
      "visual": { "type": "image", "source": "ai_generated" },
      "overlays": [],
      "transitions": {}
    }
  ],
  "subtitles": { "enabled": true, "segments": [] },
  "output": { "container": "mp4", "codec": "h264" }
}
```

---

## 11. Why This Layer Matters

* Renderer becomes dumb and reliable
* Any failure is reproducible
* You can preview *without rendering*
* Costs are known before execution

This is **professional video pipeline architecture**.

---

## 12. State Machine Placement (Final)

```
SCRIPT_FINAL
   ↓
VISUAL_STRATEGY_READY
   ↓
RENDER_PLAN_READY
   ↓
RENDER_EXECUTION
```

---