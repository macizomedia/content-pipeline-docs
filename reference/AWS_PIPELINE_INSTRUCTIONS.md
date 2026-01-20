# Project Instructions & Context

## 1. Purpose of This Project

This repository defines the **infrastructure layer** of a modular content pipeline.
Infrastructure is managed **exclusively with Terraform**.

This repo does NOT contain application logic.
It provisions and wires together environments where services run.

Primary goals:
- Reproducibility
- Clarity
- Low cognitive overhead
- Safe iteration and destruction

Terraform is the source of truth for:
- Compute (VMs, containers)
- Networking
- Storage
- IAM / permissions
- Service boundaries

---

## 2. System Overview (Mental Model)

This project is part of a **hybrid, modular pipeline** composed of multiple independent services:

- Telegram Bot (voice → text → mediated text)
- Video Generation Service (script → visuals → render)
- Supporting services (queues, storage, GPU compute)
- Infrastructure (this repo)

Each service:
- Lives in its own repository
- Is independently versioned
- Is deployed via Terraform-defined infrastructure

Terraform does not “know” business logic.
Terraform only knows **resources and contracts**.

---

## 3. Architectural Principles (Non-Negotiable)

### Separation of Concerns
- Terraform defines *where* things run
- Docker defines *what* runs
- Application code defines *how* things behave

No application logic in Terraform.
No infrastructure logic in application code.

---

### Clean Architecture Mindset
- Infrastructure is disposable
- State is explicit
- Dependencies point inward
- Human control is preserved at key steps

---

### Human-in-the-Loop by Design
This system is intentionally NOT fully automated.

Approval steps are first-class concepts.
Infrastructure must support pauses, retries, and inspection.

---

## 4. What Terraform Is Allowed to Do Here

Terraform MAY:
- Create VPCs / subnets
- Create EC2 instances or container runtimes
- Create S3 buckets and storage
- Attach IAM roles and policies
- Define security groups
- Provision GPU or CPU nodes
- Bootstrap machines via user_data scripts
- Define outputs for other services to consume

Terraform MUST:
- Be destroyable without fear
- Use minimal permissions
- Be explicit rather than clever
- Prefer simplicity over abstraction

---

## 5. What Terraform Must NOT Do

Terraform must NOT:
- Contain application secrets directly
- Hardcode API keys
- Encode business rules
- Replace configuration management logic
- Become a deployment script for app code

Terraform sets the stage.
Applications perform.

---

## 6. Repository Structure (Expected)

