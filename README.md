# Content Pipeline Documentation

## Overview

This directory contains comprehensive documentation for a cloud-native content pipeline built for learning and demonstration purposes.

The system transforms voice input into structured scripts using AWS infrastructure, Terraform, Docker, and LLM-based mediation.

---

## Documentation Structure

### 📘 Core Documents (`core/`)

Essential documentation for understanding and operating the system.

**[ARCHITECTURE.md](core/ARCHITECTURE.md)**
System design principles, component responsibilities, and architectural philosophy.

**[IMPLEMENTATION.md](core/IMPLEMENTATION.md)**
Current deployed state, operational procedures, and troubleshooting guides.

**[SPECIFICATIONS.md](core/SPECIFICATIONS.md)**
Original requirements compared against current implementation.

### 📚 Reference (`reference/`)

Quick lookup guides and operational runbooks.

**[AWS_PIPELINE_INSTRUCTIONS.md](reference/AWS_PIPELINE_INSTRUCTIONS.md)**
Infrastructure-specific Terraform guidance.

**[QUICK_REFERENCE.md](reference/QUICK_REFERENCE.md)**
Fast command reference.

**[RUNBOOK.md](reference/RUNBOOK.md)**
Operations manual with instance IDs and procedures.

### 📦 Legacy (`legacy/`)

Historical documentation retained for reference.

- `bot-specific/` — EditorBot-specific docs (learning paths, workflow guides)
- `sessions/` — Session logs and notes
- `fixes/` — Historical fix summaries
- Root level — Integration audits and verification docs

**Understand what's missing**
→ See [SPECIFICATIONS.md](SPECIFICATIONS.md) → "Implementation Status"

**Troubleshoot an issue**
→ See [IMPLEMENTATION.md](IMPLEMENTATION.md) → "Troubleshooting Checklist"

**Learn why a feature is absent**
→ See [SPECIFICATIONS.md](SPECIFICATIONS.md) → "Deferred Features & Rationale"

**Understand security model**
→ See [ARCHITECTURE.md](ARCHITECTURE.md) → "Security Model"

---

## Key Concepts

### This System Is...

- A **learning and demonstration artifact**
- Built for **clarity and security**, not scale or cost
- **Intentionally incomplete** (documented explicitly)
- Designed to be **studied, extended, and replaced**

### This System Is NOT...

- A production SaaS
- Optimized for cost or scale
- Fully automated (human-in-the-loop by design)
- A finished product

---

## Document Flow

```
core/
├── ARCHITECTURE.md       → Design principles & system layers
├── IMPLEMENTATION.md     → Current state & operations
└── SPECIFICATIONS.md     → Requirements vs. reality

reference/
├── AWS_PIPELINE_INSTRUCTIONS.md  → Terraform specifics
├── QUICK_REFERENCE.md            → Command lookup
└── RUNBOOK.md                    → Operations manual

legacy/
└── Historical documentation (retained for reference)
```

---

## Current System State

**✅ Operational:** Control VM, S3 storage, Whisper transcription, Gemini mediation, CI/CD
**❌ Deferred:** GPU layer, video assembly, multi-format export

See [SPECIFICATIONS.md](core/SPECIFICATIONS.md) for detailed status.

---

## Infrastructure Repositories

This documentation describes the **infrastructure layer** only.

### Related Repositories

**content-pipeline-infra** (this repository)
- Terraform infrastructure definitions
- No application logic

**editorbot-stack** (separate repository)
- Application services
- DRelated Repositories

**content-pipeline-infra** (this repository) — Terraform infrastructure
**editorbot-stack** (separate) — Application services and CI/CD
The documentation reflects this philosophy: it is explicit, honest, and designed to teach.

---

## Contribution Guidelines

This project is primarily a **learning artifact**.

Contributions welcome in the form of:
- Documentation improvements
- Architectural suggestions
- Security reviews

Large feature additions should be discussed before implementation.


Learning artifact. Contributions welcome: documentation improvements, architectural suggestions, security reviews
2. Follow [IMPLEMENTATION.md](IMPLEMENTATION.md) → "Operational Procedures"
3. Ensure you have:
   - AWS account with appropriate permissions
   - Terraform installed
   - GitHub repository access

---

## Legacy Documentation

The following files are **superseded** by the consolidated documentation:

**New to project:** README → [ARCHITECTURE.md](core/ARCHITECTURE.md) → [IMPLEMENTATION.md](core/IMPLEMENTATION.md) → [SPECIFICATIONS.md](core/SPECIFICATIONS.md)

**Ready to deploy:** [IMPLEMENTATION.md](core/IMPLEMENTATION.md) → Operational Procedures

**Need quick help:** [QUICK_REFERENCE.md](reference/QUICK_REFERENCE.md) or [RUNBOOK.md](reference/RUNBOOK.md)
---

## License

Open for educational and portfolio purposes.

See LICENSE file for details.

---

**Last Updated:** January 2026
**Documentation Version:** 1.0
---

**Last Updated:** January 2026 • **Documentation Version:** 2.0 • [Reorganization Summary](REORGANIZATION_SUMMARY.md)