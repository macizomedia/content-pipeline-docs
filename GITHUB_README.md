# Content Pipeline Documentation

[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://github.com/macizomedia/content-pipeline-docs)
[![Version](https://img.shields.io/badge/version-2.0-green.svg)](https://github.com/macizomedia/content-pipeline-docs/releases)
[![License](https://img.shields.io/badge/license-Educational-lightgrey.svg)](LICENSE)

Consolidated documentation for a cloud-native content production pipeline. Built as a learning and demonstration artifact, optimized for clarity and security.

---

## 🚀 Quick Start

**New to project?** → [Start with README](README.md)

**Need specific info?**
- System design → [core/ARCHITECTURE.md](core/ARCHITECTURE.md)
- Operations → [core/IMPLEMENTATION.md](core/IMPLEMENTATION.md)
- Status & gaps → [core/SPECIFICATIONS.md](core/SPECIFICATIONS.md)
- Quick commands → [reference/QUICK_REFERENCE.md](reference/QUICK_REFERENCE.md)

---

## 📂 Repository Structure

```
content-pipeline-docs/
├── core/              → Essential documentation (actively maintained)
├── reference/         → Quick lookup guides
├── legacy/           → Historical documentation (archived)
├── README.md         → Documentation overview
└── START_HERE.md     → Quick summary
```

See [STRUCTURE.md](STRUCTURE.md) for detailed organization.

---

## 🔗 Related Repositories

- **[aws-content-pipeline](https://github.com/macizomedia/aws-content-pipeline)** — Terraform infrastructure
- **[editorbot-stack](https://github.com/macizomedia/editorbot-stack)** — Application services
- **content-pipeline-docs** (this repo) — Documentation

---

## 🎯 What This Project Is

- Learning and demonstration artifact
- Built for **clarity and security**, not scale or cost
- **Intentionally incomplete** (documented explicitly)
- Designed to be studied, extended, and replaced

### What It's NOT

- Production SaaS
- Optimized for scale
- Fully automated
- A finished product

---

## 📊 Current System State

**✅ Operational:** Control VM, S3 storage, Whisper transcription, Gemini mediation, CI/CD
**❌ Deferred:** GPU layer, video assembly, multi-format export

See [core/SPECIFICATIONS.md](core/SPECIFICATIONS.md) for detailed status.

---

## 🏗️ System Architecture

Three-layer cloud-native pipeline:
- **Control Layer** (CPU, always-on) — EC2 t3.medium
- **Burst Layer** (GPU, on-demand) — Not yet implemented
- **Storage Layer** — S3 versioned bucket

See [core/ARCHITECTURE.md](core/ARCHITECTURE.md) for design principles.

---

## 💰 Cost Profile

**Current:** ~$33/month (Control VM + S3 + CloudWatch + Gemini API)
**Projected with GPU:** ~$38/month

See [core/IMPLEMENTATION.md](core/IMPLEMENTATION.md) for breakdown.

---

## 🛠️ Technology Stack

- **Infrastructure:** Terraform, AWS (EC2, S3, IAM, SSM, CloudWatch)
- **Runtime:** Docker, Ubuntu 22.04
- **Processing:** Whisper (transcription), Google Gemini (mediation)
- **CI/CD:** GitHub Actions, AWS SSM

---

## 🎨 Design Philosophy

**Boring tools** • **Explicit wiring** • **Observable systems** • **Understanding before optimization**

This architecture values:
- Clarity over completeness
- Security over convenience
- Learning over production readiness
- Honesty about limitations

---

## 📚 Documentation Principles

- **Honest about limitations** — Gaps explicitly documented
- **Calm, professional tone** — No hype, no defensiveness
- **Explicit over implicit** — Clear explanations
- **Designed for learning** — Educational value preserved

---

## 🤝 Contribution

Learning artifact. Contributions welcome:
- Documentation improvements
- Architectural suggestions
- Security reviews

Large feature additions should be discussed first.

---

## 📄 License

Open for educational and portfolio purposes.

**Do not reuse production identifiers or credentials.**

---

## 📞 Contact

Questions or suggestions:
- Open an issue in this repository
- Review related repositories for context

---

**Version:** 2.0 • **Last Updated:** January 2026

[📖 Full Documentation](README.md) • [🏗️ Architecture](core/ARCHITECTURE.md) • [⚙️ Implementation](core/IMPLEMENTATION.md)
