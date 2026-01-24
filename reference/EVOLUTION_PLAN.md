# EditorBot Evolution Plan
## Design-Driven Development & Release Strategy

**Date:** January 24, 2026
**Goal:** Elevate bot UX using Don Norman principles + Design Thinking + Proper versioning

---

## Phase 1: Stop the Conflict ⚠️ (5 minutes)

### Problem
Two bots using same Telegram token (local Docker + cloud EC2) causes conflicts.

### Solution Options

**Option A: Stop Local Docker** (Recommended)
```bash
cd editorbot-stack
docker compose -f editorBot/docker-compose.yml down
```
- Use cloud bot for real Telegram testing
- Use CLI for local development/debugging
- No token conflicts

**Option B: Create Dev Bot**
```bash
# 1. Message @BotFather on Telegram
# 2. Send /newbot
# 3. Name it "EditorBot Dev" or similar
# 4. Get new token
# 5. Update local .env with dev token
# 6. Keep production token in cloud
```
- Separate dev/prod environments
- Can test both simultaneously
- More realistic staging setup

**Decision:** [ ] Option A (simpler) | [ ] Option B (proper staging)

**Status:** 🔴 BLOCKED - Must resolve before continuing

---

## Phase 2: UX Audit with Don Norman Principles (2-3 hours)

### Objective
Evaluate current bot experience using Norman's design principles.

### Don Norman's 6 Principles

#### 1. **Visibility** - Can users see their options?
**Current State Audit:**
- [ ] Initial contact: Is /start clear?
- [ ] Voice upload: Do users know to send voice?
- [ ] Mediated text: Is enhanced text visible for review?
- [ ] Template selection: Are options clear and descriptive?
- [ ] Soundtrack selection: Do users understand choices?
- [ ] Progress: Can users see where they are in workflow?

**Pain Points to Document:**
-
-
-

#### 2. **Feedback** - Do users know what happened?
**Current State Audit:**
- [ ] Voice processing: "Transcribing..." message shown?
- [ ] Mediation: "Enhancing text..." message shown?
- [ ] Script generation: Clear confirmation?
- [ ] Render plan: Summary of what will be rendered?
- [ ] Errors: Clear, actionable error messages?

**Pain Points to Document:**
-
-
-

#### 3. **Constraints** - Are invalid actions prevented?
**Current State Audit:**
- [ ] Can user skip steps in wrong order?
- [ ] Can user send voice twice in same session?
- [ ] Are text commands limited to valid states?
- [ ] Are button clicks validated?

**Pain Points to Document:**
-
-
-

#### 4. **Mapping** - Do controls match expectations?
**Current State Audit:**
- [ ] OK/EDITAR/CANCELAR buttons intuitive?
- [ ] Template names descriptive of output?
- [ ] Soundtrack names match vibe?
- [ ] Workflow order logical?

**Pain Points to Document:**
-
-
-

#### 5. **Consistency** - Is behavior predictable?
**Current State Audit:**
- [ ] Button labels consistent?
- [ ] Message formatting consistent?
- [ ] Error handling consistent?
- [ ] Tone/voice consistent?

**Pain Points to Document:**
-
-
-

#### 6. **Affordances** - Is it obvious what to do?
**Current State Audit:**
- [ ] Voice upload: Users know to click mic icon?
- [ ] Text input: Clear when to type?
- [ ] Buttons: Obviously clickable?
- [ ] Commands: Discoverable?

**Pain Points to Document:**
-
-
-

### Audit Method

```bash
# Test full workflow with CLI + Telegram
cd editorbot-stack/editorBot

# 1. Document each interaction
# 2. Screenshot each step
# 3. Note confusion points
# 4. Record error scenarios
# 5. Time each step

# Use structured logging to understand flow
editorbot-cli --verbose 2>&1 | tee sandbox/audit_logs/norman_audit_$(date +%Y%m%d).log
```

### Deliverable
`sandbox/audit_logs/NORMAN_AUDIT_REPORT.md` with:
- Current UX screenshots
- Principle violations
- User friction points
- Prioritized improvements

**Status:** 🟡 READY (after Phase 1)

---

## Phase 3: Design Thinking Cycle (3-5 hours)

Apply 5-stage Design Thinking process to identified pain points.

### Stage 1: Empathize (30 min)
**Goal:** Understand user needs

**User Persona:**
- **Who:** Content creator (Spanish speaker, non-technical)
- **Goal:** Create short social media videos quickly
- **Context:** On phone, time-constrained, impatient
- **Pain:** Complex video editing tools
- **Need:** Voice → Video in <5 minutes

**Empathy Activities:**
- [ ] Test bot on phone (not desktop)
- [ ] Test in noisy environment
- [ ] Test with different voice qualities
- [ ] Test with interruptions
- [ ] Time full workflow

**Document:** `sandbox/audit_logs/USER_RESEARCH.md`

### Stage 2: Define (30 min)
**Goal:** Synthesize insights into problem statements

**Problem Statement Template:**
```
[User persona] needs [user need]
because [insight]
but [current limitation]
```

**Example:**
```
Content creators need instant feedback on voice quality
because they're often in sub-optimal recording conditions
but the bot doesn't validate audio until transcription fails
```

**Deliverable:**
- 3-5 prioritized problem statements
- Clear success criteria for each

**Document:** `sandbox/audit_logs/PROBLEM_STATEMENTS.md`

### Stage 3: Ideate (1 hour)
**Goal:** Generate solutions (quantity over quality)

**Brainstorming Rules:**
1. No criticism during ideation
2. Build on others' ideas
3. Wild ideas encouraged
4. Visual thinking

**Focus Areas (from Norman audit):**
- Improve visibility (progress indicators?)
- Better feedback (loading states?)
- Prevent errors (validation earlier?)
- Clearer affordances (onboarding flow?)

**Methods:**
- Sketch UI flows
- Write user stories
- Design alternate interactions
- Prototype button labels

**Deliverable:** 20+ ideas (even bad ones)

**Document:** `sandbox/audit_logs/IDEATION.md`

### Stage 4: Prototype (1-2 hours)
**Goal:** Quick, testable versions of top ideas

**Low-Fidelity Prototypes:**
- [ ] New message templates (Markdown mockups)
- [ ] Revised button labels (text file)
- [ ] Onboarding sequence (flow diagram)
- [ ] Error message rewrites (examples)
- [ ] Progress indicators (ASCII mockups)

**Implementation Priorities:**
1. Quick wins (copy changes, message tweaks)
2. Medium effort (new buttons, validation)
3. High effort (state machine changes, new features)

**Deliverable:** `sandbox/prototypes/` folder with mockups

### Stage 5: Test (1 hour)
**Goal:** Validate improvements with real usage

**Test Protocol:**
1. Implement quick wins first
2. Test with CLI (simulate user)
3. Deploy to dev bot (if created)
4. Get external feedback (friends/colleagues)
5. Measure improvements:
   - Time to complete workflow
   - Error rate
   - User satisfaction (informal)

**Deliverable:** `sandbox/audit_logs/TEST_RESULTS.md`

**Status:** 🟡 READY (after Phase 2)

---

## Phase 4: Version Control Strategy (1 hour)

### Current State
- Main branch deployed to EC2
- No formal releases
- No rollback strategy

### Proposed Strategy

#### Semantic Versioning
```
v<MAJOR>.<MINOR>.<PATCH>

v0.1.0 - Initial working bot (current)
v0.2.0 - UX improvements (Phase 3 output)
v1.0.0 - Production-ready release
```

#### Branching Model
```
main          - Production (EC2)
develop       - Integration branch
feature/*     - New features
hotfix/*      - Urgent fixes
release/*     - Release candidates
```

#### Release Process
1. **Feature Development**
   ```bash
   git checkout -b feature/better-feedback develop
   # Make changes
   git commit -m "Add progress indicators"
   git push origin feature/better-feedback
   # Create PR to develop
   ```

2. **Release Candidate**
   ```bash
   git checkout -b release/v0.2.0 develop
   # Update version in code
   # Test thoroughly
   git checkout main
   git merge release/v0.2.0
   git tag -a v0.2.0 -m "UX improvements"
   git push origin main --tags
   ```

3. **Deploy**
   - GitHub Actions auto-deploys tagged releases
   - OR manual deploy with version tracking

#### Canary Deployment (Future)

**Option A: Terraform Multi-Instance**
```hcl
# Two EC2 instances
resource "aws_instance" "editorbot_stable" {
  # v1.0.0 - 90% traffic
}

resource "aws_instance" "editorbot_canary" {
  # v1.1.0-rc - 10% traffic
}
```

**Option B: Docker Tags**
```yaml
# Current
docker pull editorbot:stable

# Canary (for testing)
docker pull editorbot:canary
```

**For Now:** Single instance, manual rollback if needed.

**Status:** 🟡 READY (after Phase 3)

---

## Phase 5: Implementation Roadmap (2-5 days)

### Week 1: Quick Wins
- [ ] Improve message copy (visibility)
- [ ] Add progress indicators (feedback)
- [ ] Better error messages (feedback)
- [ ] Validate audio early (constraints)

**Effort:** 4-6 hours
**Impact:** High (immediate UX improvement)

### Week 2: Medium Improvements
- [ ] Onboarding flow (/start command)
- [ ] Help command with examples
- [ ] State recovery (if user interrupted)
- [ ] Better template descriptions

**Effort:** 8-12 hours
**Impact:** Medium-High

### Week 3: Structural Changes
- [ ] Refactor state machine for clarity
- [ ] Add undo/redo capability
- [ ] Preview mode before final render
- [ ] User preferences (language, style)

**Effort:** 16-20 hours
**Impact:** Medium (foundation for future)

### Release Schedule
- **v0.2.0** (Week 1) - UX quick wins
- **v0.3.0** (Week 2) - Onboarding + help
- **v1.0.0** (Week 3) - Production-ready

---

## Implementation Tracking

### Todo List Template
```markdown
## Phase 1: Resolve Conflict
- [ ] Choose Option A or B
- [ ] Stop local bot OR create dev bot
- [ ] Verify only one bot responding

## Phase 2: Norman Audit
- [ ] Test full workflow
- [ ] Document visibility issues
- [ ] Document feedback gaps
- [ ] Document constraint failures
- [ ] Document mapping problems
- [ ] Document inconsistencies
- [ ] Document affordance issues
- [ ] Write audit report

## Phase 3: Design Thinking
- [ ] Complete empathy research
- [ ] Define problem statements
- [ ] Ideate solutions (20+)
- [ ] Create prototypes
- [ ] Test improvements

## Phase 4: Version Control
- [ ] Tag current code as v0.1.0
- [ ] Create develop branch
- [ ] Document versioning strategy
- [ ] Update CI/CD for tags

## Phase 5: Implementation
- [ ] Implement quick wins
- [ ] Test and iterate
- [ ] Release v0.2.0
```

---

## Tools & Resources

### Design Audit
- CLI for detailed logging
- Telegram app (mobile + desktop)
- Screen recording for user testing
- Markdown for documentation

### Prototyping
- Text files for message templates
- Mermaid diagrams for flows
- ASCII art for UI mockups
- Git branches for experiments

### Version Control
- Git tags for releases
- GitHub releases for notes
- Semantic versioning
- CHANGELOG.md maintenance

---

## Success Metrics

### UX Improvements
- [ ] Reduced confusion (qualitative)
- [ ] Faster workflow (<5 min target)
- [ ] Lower error rate (measure with logs)
- [ ] Higher completion rate

### Technical Health
- [ ] Clear version history
- [ ] Rollback capability
- [ ] Documented changes
- [ ] Testable releases

---

## Next Actions (Right Now)

1. **Decide:** Option A (stop local) or B (dev bot)?
2. **Execute:** Resolve token conflict
3. **Begin:** Norman audit with test workflow
4. **Document:** Findings in sandbox/audit_logs/

**Est. Time to First Insights:** 3-4 hours
**Est. Time to First Improvements:** 1-2 days
**Est. Time to v1.0.0:** 2-3 weeks
