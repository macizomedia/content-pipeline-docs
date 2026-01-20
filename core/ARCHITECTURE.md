# System Architecture

## Purpose

This project is a cloud-native content pipeline designed to transform voice input into structured scripts. It is built as a learning and demonstration artifact, optimized for clarity and security rather than scale or cost.

The architecture deliberately favors:
- explicit wiring over abstraction
- security-first defaults
- reproducibility
- operator understanding

This system is **not** a production SaaS. It is designed to be studied, extended, and replaced.

---

## Design Principles

### Separation of Concerns
Infrastructure, application logic, and CI/CD are managed independently.

- **Infrastructure** (Terraform): defines compute, storage, and permissions
- **Application** (Docker): contains business logic
- **CI/CD** (GitHub Actions): orchestrates testing and deployment

No layer knows implementation details of another.

### Explicit Over Implicit
Configuration is passed via environment variables or SSM parameters.
Secrets never appear in code, images, or repositories.

### Replaceable Components
Instances are disposable. Containers are the deployment unit.
State lives in S3 or managed services, never on VMs.

### Human-in-the-Loop
This pipeline is intentionally **not** fully automated.
Approval steps, manual checks, and operator oversight are preserved.

---

## System Layers

The system consists of three operational layers:

### 1. Infrastructure Layer (Terraform)
Provisions AWS resources via `content-pipeline-infra` repository.

**Responsibilities:**
- EC2 control VM (t3.medium, Ubuntu 22.04)
- S3 bucket (versioned, private)
- IAM roles (least privilege)
- CloudWatch logs
- SSM configuration

**Design decisions:**
- No SSH access (SSM only)
- No inbound network ports
- Remote state (S3 + DynamoDB)
- Security groups with explicit allowlists

Infrastructure provides **places and contracts**, not application logic.

---

### 2. Control Plane (EditorBot)
Dockerized service running on the control VM.

**Responsibilities:**
- Accept voice messages via Telegram
- Transcribe audio (Whisper, local)
- Mediate text via LLM (Google Gemini)
- Generate structured scripts
- Write artifacts to S3

**Does not:**
- Manage infrastructure
- Generate video assets (future capability)
- Store secrets locally

---

### 3. Processing & Data Layer
Stateless compute and durable storage.

**Storage (S3):**
```
s3://content-pipeline/
  audio/raw/
  audio/cleaned/
  scripts/
  subtitles/
  video/short/
  video/long/
```

**Processing:**
- Transcription: Whisper (CPU, local to control VM)
- Mediation: Google Gemini 1.5 Flash (API)
- Future: GPU-based image/video generation (not yet implemented)

S3 acts as the **handoff boundary** between pipeline stages.

---

## Data Flow

Current implementation:

1. User sends voice message (Telegram)
2. Audio downloaded to control VM
3. Transcribed via Whisper (local model)
4. Text sent to LLM for dialect mediation
5. Structured script generated
6. Artifacts written to S3
7. User notified via Telegram

Future stages (not implemented):
- Image generation (GPU, on-demand EC2)
- Video assembly (control VM)
- Multi-format export (9:16, 16:9)

---

## Security Model

### Secrets Management
- No secrets in repositories
- Runtime secrets stored in AWS SSM Parameter Store
- Secrets injected at container startup
- IAM roles grant least-privilege access

### Network Isolation
- Control VM has no inbound SSH
- Access via AWS SSM Session Manager
- Security groups use explicit IPv4/IPv6 allowlists
- No public endpoints

### Credential Lifecycle
- CI uses scoped AWS credentials (GitHub Secrets)
- Application uses IAM role attached to EC2
- API keys rotated via SSM updates (manual)

---

## Deployment Model

Deployment is **push-based** via GitHub Actions and AWS SSM.

**CI (Continuous Integration):**
- Runs on pull requests
- Terraform: `fmt`, `validate` (no backend)
- Python: `pytest`, `ruff`, `black`
- Security: `gitleaks`, `tfsec`, `pip-audit`

**CD (Continuous Deployment):**
- Triggered on merge to main
- Executes via SSM Run Command (no SSH)
- Pulls latest code
- Rebuilds Docker containers
- Restarts services via systemd

Deployments are observable via CloudWatch and reversible via Git.

---

## Known Limitations

This system is deliberately incomplete:

### Not Yet Implemented
- GPU burst layer (image generation)
- Video assembly pipeline
- Multi-format video export
- Cost optimization (spot instances, autoscaling)

### Operational Gaps
- No automated monitoring or alerting
- No graceful degradation
- No multi-region redundancy
- No disaster recovery plan

These are **intentional tradeoffs** to preserve simplicity during the learning phase.

---

## Technology Choices

### Why Terraform?
- Declarative infrastructure
- Version-controlled changes
- Reproducible environments
- Wide community support

### Why Docker?
- Isolated runtime dependencies
- Portable across environments
- Simple deployment unit
- No dependency on host OS

### Why Whisper (local)?
- No external API dependency
- Predictable cost (CPU time)
- Privacy-preserving (data stays on VM)
- Acceptable accuracy for transcription

### Why SSM over SSH?
- No key management
- Auditable access logs
- No exposed ports
- Integrates with IAM

---

## Future Directions

Planned extensions (not prioritized):

- GPU module for image generation (g4dn.xlarge)
- Video assembly stage (FFmpeg + MoviePy)
- Event-driven orchestration (SQS + Lambda)
- Cost monitoring (AWS Budgets)
- Terraform module for GPU burst layer

These are deferred to maintain focus on current goals: **clarity, security, and learning**.

---

## Design Philosophy

This architecture values:

- **Boring tools** over novel ones
- **Explicit wiring** over magic
- **Observable systems** over opaque ones
- **Understanding** before optimization

The system is meant to be **taught, inspected, and extended**, not hidden behind abstractions.

---

## Repository Boundaries

### content-pipeline-infra
- Terraform modules
- IAM policies
- Infrastructure as code
- No application logic

### editorbot-stack
- Application services (Telegram bot, LLM mediator)
- Dockerfiles and compose files
- CI/CD workflows
- No infrastructure definitions

This separation allows independent iteration and clear ownership.
