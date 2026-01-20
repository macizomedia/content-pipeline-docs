# Documentation Structure

## Overview

Documentation is organized into three primary categories:

```
content-pipeline-docs/
│
├── 📘 core/              → Essential documentation (actively maintained)
│   ├── ARCHITECTURE.md   → System design and principles
│   ├── IMPLEMENTATION.md → Deployed state and operations
│   └── SPECIFICATIONS.md → Requirements vs. reality
│
├── 📚 reference/         → Quick lookup and operational guides
│   ├── AWS_PIPELINE_INSTRUCTIONS.md
│   ├── QUICK_REFERENCE.md
│   └── RUNBOOK.md
│
├── 📦 legacy/           → Historical documentation (archived)
│   ├── bot-specific/
│   ├── sessions/
│   ├── fixes/
│   └── *.md
│
├── 📄 Root Level
│   ├── README.md         → Documentation overview (START HERE)
│   ├── START_HERE.md     → Quick summary
│   └── CONSOLIDATION_NOTES.md → Consolidation details
│
└── .archive/            → Old archive structure (deprecated)
```

## Navigation

### New to the Project?
1. [README.md](README.md)
2. [core/ARCHITECTURE.md](core/ARCHITECTURE.md)
3. [core/IMPLEMENTATION.md](core/IMPLEMENTATION.md)
4. [core/SPECIFICATIONS.md](core/SPECIFICATIONS.md)

### Need Quick Help?
- [reference/QUICK_REFERENCE.md](reference/QUICK_REFERENCE.md)
- [reference/RUNBOOK.md](reference/RUNBOOK.md)

### Want Historical Context?
- [legacy/README.md](legacy/README.md)

## Document Purposes

| Document | Purpose | Audience |
|----------|---------|----------|
| ARCHITECTURE.md | Design principles, system layers, philosophy | Architects, reviewers |
| IMPLEMENTATION.md | Deployed state, operations, troubleshooting | Operators, deployers |
| SPECIFICATIONS.md | Requirements vs. reality, gaps | Stakeholders, portfolio viewers |
| AWS_PIPELINE_INSTRUCTIONS.md | Terraform-specific guidance | Infrastructure engineers |
| QUICK_REFERENCE.md | Command lookup, quick answers | All users |
| RUNBOOK.md | Instance IDs, secrets, procedures | Operations team |

## Maintenance

**Core documents** → Update when system changes
**Reference documents** → Update when procedures change
**Legacy documents** → Never modify; add new dated files if needed

## Version

**Documentation Version:** 2.0
**Last Reorganization:** January 2026
**Status:** Organized and de-duplicated
