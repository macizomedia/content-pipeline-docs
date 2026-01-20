# System Specifications

## Purpose of This Document

This document compares the **original design requirements** with the **current implementation state**.

It serves as an honest accounting of:
- What was planned
- What exists now
- What remains to be built
- Why certain features were deferred

---

## Original Design Vision

### Three-Layer Architecture

**Control Layer (CPU, always-on):**
- EC2 t3.medium
- Handles orchestration, subtitle generation, video assembly
- No AI image generation on this machine

**Burst Layer (GPU, on-demand):**
- EC2 g4dn.xlarge (NVIDIA T4)
- Used ONLY for image generation
- Must be safe to terminate immediately after batch completion

**Storage Layer:**
- AWS S3 as single source of truth
- All assets flow through S3

---

## Implementation Status

### ✅ Implemented

**Control Layer:**
- [x] EC2 t3.medium (Ubuntu 22.04)
- [x] Docker runtime environment
- [x] Bootstrap automation via user_data
- [x] IAM role with S3 access
- [x] SSM access (no SSH)
- [x] CloudWatch logging

**Storage Layer:**
- [x] S3 bucket with versioning
- [x] Private access (IAM-only)
- [x] Directory structure defined
- [x] boto3 integration in application

**Audio Pipeline:**
- [x] Audio input from Telegram
- [x] Whisper transcription (local, CPU)
- [x] Subtitle generation (.srt format)
- [x] Storage in S3

**LLM Mediation:**
- [x] Google Gemini 1.5 Flash integration
- [x] Dialect-aware text mediation
- [x] Structured script generation

**CI/CD:**
- [x] GitHub Actions workflows
- [x] Automated testing (pytest, ruff, black)
- [x] Security scanning (gitleaks, tfsec, pip-audit)
- [x] SSM-based deployment (no SSH)

---

### ❌ Not Yet Implemented

**Burst Layer (GPU):**
- [ ] Terraform module for g4dn.xlarge
- [ ] AUTOMATIC1111 Stable Diffusion WebUI
- [ ] API-driven image generation
- [ ] Batch processing capability
- [ ] Auto-start/stop logic

**Image Generation:**
- [ ] Prompt architecture (base style + per-topic)
- [ ] Template-driven prompt system
- [ ] Deterministic generation (seed support)
- [ ] Image storage in S3

**Video Assembly:**
- [ ] FFmpeg/MoviePy integration
- [ ] Timed image transitions
- [ ] Subtitle burning
- [ ] Multi-format export:
  - [ ] 9:16 (TikTok/Instagram)
  - [ ] 16:9 (YouTube)

**Automation:**
- [ ] Event-driven orchestration
- [ ] Automated monitoring/alerting
- [ ] Cost optimization (spot instances)
- [ ] Auto-scaling

---

## Design Requirements vs. Reality

### Audio Input

**Requirement:** Human-recorded voice (WAV), uploaded to S3.

**Reality:**
✅ Implemented. Audio received via Telegram, stored in S3.
⚠️  Not limited to WAV; accepts MP3 and other formats.

---

### Subtitle Generation

**Requirement:** Whisper (local) → .srt output → S3 storage.

**Reality:**
✅ Fully implemented. Whisper runs on Control VM, outputs stored in S3.

---

### GPU Image Generation

**Requirement:** On-demand EC2 GPU instance, AUTOMATIC1111, API mode.

**Reality:**
❌ Not implemented. No GPU instance provisioned.
**Reason for deferral:** Focus on core transcription/mediation pipeline first.

---

### Prompt Architecture

**Requirement:** Template-driven prompts (base style + per-topic + per-scene modifiers).

**Reality:**
❌ Not implemented. No prompt system exists yet.
**Reason for deferral:** GPU layer dependency.

---

### Video Assembly

**Requirement:** Automated assembly with timed transitions, burned subtitles, multi-format export.

**Reality:**
❌ Not implemented. No video rendering pipeline exists.
**Reason for deferral:** Image generation dependency; focus on script generation first.

---

### Cost Discipline

**Requirement:** GPU instance starts only when needed, terminates immediately after.

**Reality:**
⚠️  Partially implemented. Control VM is always-on (~$33/month).
❌ GPU layer not implemented, so cost optimization is deferred.

---

## Technology Stack Comparison

### As Specified

| Component | Specified Technology |
|-----------|---------------------|
| Infrastructure | Terraform |
| Control VM | Ubuntu 22.04, Python 3.10+ |
| Transcription | Whisper (CPU) |
| Video | FFmpeg, MoviePy |
| Image Generation | AUTOMATIC1111 Stable Diffusion |
| Storage | AWS S3 |
| Access | AWS SSM (no SSH) |

### As Implemented

| Component | Implemented Technology | Notes |
|-----------|------------------------|-------|
| Infrastructure | Terraform ✅ | Fully implemented |
| Control VM | Ubuntu 22.04, Python 3.10+ ✅ | As specified |
| Transcription | Whisper (CPU) ✅ | As specified |
| LLM Mediation | Google Gemini ➕ | Added feature (not in original spec) |
| Video | Not implemented ❌ | Future work |
| Image Generation | Not implemented ❌ | Future work |
| Storage | AWS S3 ✅ | As specified |
| Access | AWS SSM ✅ | As specified |

**➕ Indicates feature added beyond original specification.**

---

## Deferred Features & Rationale

### GPU Burst Layer
**Status:** Deferred
**Reason:** Image generation is not required for current use case (text-based script generation). GPU costs ($0.526/hour) should only be incurred when image pipeline is ready.

### Video Assembly
**Status:** Deferred
**Reason:** Requires GPU layer (images) to be functional first. No value in implementing assembly without source material.

### Event-Driven Orchestration
**Status:** Deferred
**Reason:** Current manual workflow is acceptable for learning/experimentation phase. Automation complexity should be added only when workflows stabilize.

### Cost Optimization
**Status:** Deferred
**Reason:** System is not in production. Optimizing for cost before understanding usage patterns is premature.

### Multi-Region Redundancy
**Status:** Deferred
**Reason:** Not a production system. Single-region deployment is sufficient for demonstration purposes.

---

## Non-Goals (Explicitly Out of Scope)

These were never intended to be implemented:

- ❌ Social media API posting
- ❌ Analytics/metrics collection
- ❌ Facial animation or video synthesis
- ❌ Text-to-speech (audio is human-recorded)
- ❌ SaaS platform features (multi-tenancy, billing, etc.)

---

## Architectural Deviations

### Added: LLM Mediation Layer

**Not in original spec, but added for practical value.**

**Reason:**
Raw transcription requires dialect/language mediation before script generation. Google Gemini 1.5 Flash provides cost-effective text processing (~$0.50/month).

**Impact:**
- Improves output quality
- Minimal cost increase
- No architectural complexity
- Aligns with human-in-the-loop philosophy

---

### Simplified: No Google Speech API

**Original spec mentioned Google Speech as transcription option.**

**Reality:**
Whisper-only implementation. Google Speech integration was removed.

**Reason:**
- Whisper provides sufficient accuracy
- No external API dependency
- Predictable costs (CPU time only)
- Privacy-preserving (data stays on VM)

---

## Future Roadmap (Unscheduled)

These features are **planned but not prioritized**:

### Phase 2: GPU Layer
- Provision g4dn.xlarge via Terraform
- Install AUTOMATIC1111 Stable Diffusion
- Implement API-driven image generation
- Create prompt template system

### Phase 3: Video Assembly
- Integrate FFmpeg/MoviePy
- Implement timed image transitions
- Add subtitle burning
- Support multi-format export (9:16, 16:9)

### Phase 4: Automation
- Add event-driven orchestration (SQS/Lambda)
- Implement auto-start/stop for GPU instances
- Add CloudWatch alarms
- Cost budgets and alerts

**No timeline exists for these phases.**
They will be implemented when learning objectives require them.

---

## Design Principles (Unchanged)

These principles remain intact despite implementation gaps:

✅ **Separation of concerns:** Infrastructure ≠ application ≠ CI
✅ **Security-first:** No secrets in repos, SSM-only access
✅ **Explicit over implicit:** No magic, no abstractions
✅ **Human-in-the-loop:** Manual approval steps preserved
✅ **Replaceable components:** Instances are disposable
✅ **Boring tools:** Terraform, Docker, Python, Whisper

---

## Metrics of Success

### Learning Objectives (Primary Goal)

**Goal:** Demonstrate cloud-native architecture principles for portfolio.

**Status:** ✅ Achieved
- Infrastructure as code (Terraform)
- Secrets management (SSM)
- CI/CD automation (GitHub Actions)
- Observable systems (CloudWatch)
- Security-first design (no SSH, IAM roles)

### Functional Objectives (Secondary Goal)

**Goal:** Build end-to-end content pipeline (audio → script → video).

**Status:** ⚠️  Partially achieved
- ✅ Audio input
- ✅ Transcription
- ✅ Mediation
- ✅ Script generation
- ❌ Image generation (deferred)
- ❌ Video assembly (deferred)

**This is acceptable.** The system demonstrates core principles without requiring full implementation.

---

## Conclusion

This system is **intentionally incomplete**.

The current implementation prioritizes:
- Clarity over completeness
- Learning over production readiness
- Security over convenience
- Understanding over automation

Deferred features are documented explicitly, not hidden.
This is a demonstration of **thoughtful engineering**, not a finished product.

---

## References

**Related Documentation:**
- [ARCHITECTURE.md](ARCHITECTURE.md) — System design
- [IMPLEMENTATION.md](IMPLEMENTATION.md) — Deployed state
- [README.md](README.md) — Documentation overview

**Original Requirements:**
- See [Code.instructions.md](../.github/copilot-instructions.md) for master prompt

---

**Last Updated:** January 2026
