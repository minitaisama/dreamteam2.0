# Dream Team v3.2

> A 5-role software factory: CEO reframes the problem, Coach locks scope and UX direction, Lebron builds backend, Bronny builds frontend, Curry validates and pressure-tests quality. Multi-agent parallel execution, not single-session slash commands.

---

## What's improved from v2.0 → v3.1 → v3.2

### v2.0
- Established the core multi-agent idea: PM → Dev → QA instead of one overloaded generalist session
- Introduced tiny task cards, artifact-first handoffs, and release-gate thinking
- Proved the value of structured roles over slash-command chaos

### v3.1
- Added **CEO / MiniSama** as the product-reframing layer before PM
- Formalized the 4-agent pipeline: **CEO → PM → Dev → QA**
- Added stronger quality rules: design audit, mode selection, handoff contracts, retros, and stricter runbook discipline

### v3.2
- Split the old Dev lane into **specialized execution lanes**:
  - **Lebron** = Backend Developer (`be-agent`)
  - **Bronny** = Frontend Developer (`fe-agent`)
- Upgraded **Coach** from PM-only to **PM + UI Design direction**
- Made **CEO runbook discipline explicit**: CEO must not jump into coding out of urgency
- Added **Root-cause Debug mode** for hard bugs / scope-out work
- Made **Curry mandatory early** for bug root-cause work, not just end-stage QA
- Clarified **parallel split by specialty**:
  - Coach = direction / scope / hypothesis control
  - Curry = reproduction / evidence / validation

In short:
- **v2.0** = structured team idea
- **v3.1** = CEO-led operating system
- **v3.2** = specialization + better debugging workflow

---

## The idea

Most AI coding setups are a single session with a single model trying to be everything — PM, architect, developer, QA, and release engineer all at once.

Dream Team is different. It's **four specialized agents**, each running independently, coordinated through a structured pipeline:

```
You → CEO (reframe) → PM (spec) → Dev (build) → QA (verify) → PM (synthesize) → You
```

Each agent has one job. They communicate through artifacts (task cards, QA reports, diagrams), not through forwarding chat history. The result: **parallel execution with less token burn and clearer accountability**.

Inspired by [gstack](https://github.com/garrytan/gstack) — we borrowed the "structured roles + review gates" philosophy, then built on top of multi-agent orchestration instead of single-session slash commands.

---

## The team

| Role | Agent | What they do |
|------|-------|-------------|
| **CEO** | MiniSama | Rethink the problem. Find the 10-star product hiding in the request. Set scope mode and protect the runbook. |
| **PM + UI Design** | Coach | Lock the spec. Freeze a tiny task card. Set UX/UI direction. Dispatch work and control hypotheses. |
| **Backend Developer** | Lebron | Build backend/API/auth/data changes. Produce integration contracts when FE depends on BE. |
| **Frontend Developer** | Bronny | Build UI/client states and frontend integration from frozen task cards and contracts. |
| **QA** | Curry | Reproduce, validate, and verify. Test against the frozen contract, not a moving target. Design audit for UI. |

---

## See it work

```
You:      "Build a user profile page"
CEO:      "A profile page is a table. The real job is letting users
           build identity and trust. What if the profile shows
           contribution history, skill endorsements from peers,
           and a verified badge system? That's 10 stars.
           A form with a avatar upload is 3 stars."
           Selective expansion — recommend contributions + endorsements,
           defer verified badges to phase 2.
You:      "Sounds good, defer badges. Keep the rest."
PM:       → Freeze task card
            Task: User profile with identity signals
            Scope: Avatar, bio, contribution history, skill endorsements
            Non-goals: Badges, social links, activity feed
            Acceptance: User can edit profile, view contributions,
                        receive endorsements
            Design: empty state for new users, loading skeleton,
                    edit vs view mode

Dev:      → Diagram before code:
            ┌──────────┐     ┌──────────────────┐
            │ Profile  │────▶│ Contributions     │
            │ (edit)   │     │ (read-only feed)  │
            └────┬─────┘     └──────────────────┘
                 │
                 ▼
            ┌──────────┐     ┌──────────────────┐
            │ Avatar   │     │ Skill Endorsements│
            │ Upload   │     │ (peer actions)    │
            └──────────┘     └──────────────────┘

          → Implement (5 files, 3 tests)

QA:       → Standard QA: contract tests pass ✓
          → Design audit:
            Info Architecture: 8/10 ✓ (clear hierarchy)
            Interaction States: 7/10 ✓ (empty state for new users)
            User Journey: 8/10 ✓ (edit → save → view flow)
            AI Slop Risk: 9/10 ✓ (no generic card grid)
            Design System: 7/10 ✓
            Responsive: 8/10 ✓ (mobile-first)
            Unresolved Decisions: 8/10 ✓
            Overall: 7.9/10 — PASS

PM:       → Synthesize: "Profile shipped. 5 files, 3 tests, design 7.9.
           No blockers. Endorsement API ready for peer integration."
```

One feature. Four agents. Each with the right cognitive mode. That's the difference between an assistant and a team.

---

## Core principles

**Reframe, don't implement literally.** The CEO step catches the gap between what you ask for and what you actually need. "Photo upload" isn't the feature — "helping sellers create listings that sell" is.

**Freeze before coding.** The PM writes a tiny task card with scope, non-goals, acceptance criteria, and DoD. Scope doesn't change after freeze.

**Diagram-first for complexity.** When a task involves async flows, state machines, or multi-component architecture — draw the diagram before writing code. Diagrams expose hidden assumptions that text hides.

**Test against a fixed contract.** QA validates against the frozen task card, not the code as it currently exists. Moving-target QA is the #1 quality killer.

**Design audit before slop ships.** Every UI task gets a 7-dimension design audit: information architecture, interaction states, user journey, AI slop risk, design system, responsive, and unresolved decisions. Rated 0-10.

**Artifact-first handoffs.** Agents communicate through task cards, QA reports, and diagrams — not by forwarding 50 messages of chat history. Less token burn, clearer contracts.

**Quality per token.** The lightest mode that preserves quality. Solo for small tasks. Build for normal work. Release-critical only for auth/payment/core-flow.

---

## Operating modes

| Mode | When | CEO | Diagram | Design audit | QA gate |
|------|------|-----|---------|--------------|---------|
| **Solo** | <30 min, clear scope, low risk | Skip | No | No | Optional |
| **Build** | Normal dev task | Yes | If PM requires | If UI | Yes |
| **Root-cause Debug** | Hard bug, unclear failure path, scope-out needed | Yes | Investigation-driven | If UI | Mandatory early |
| **Release-critical** | Auth, payment, core flow | Yes | PM requires | If UI | `ship` / `ship_with_risk` / `hold` |

---

## Retro dashboard

Every Sunday at 20:00, all three agents submit structured retrospectives. The CEO aggregates them with commentary, trends, and action items.

📊 **Live dashboard:** [dreamteam20.vercel.app](https://dreamteam20.vercel.app)

Tracks: velocity, quality scores, blockers, action items — all visualized with charts over time.

---

## Anti-patterns we avoid

| Pattern | Symptom | Fix |
|---------|---------|-----|
| Literal ticket taking | Implement exactly what was asked, not what was needed | CEO reframe |
| Moving target QA | Testing against code that keeps changing | Frozen task card contract |
| Gold-plating | Adding features not in scope | Scope freeze + QA adherence check |
| AI slop UI | Generic gradients, icon grids, uniform SaaS look | Design audit dimension 4 |
| Premature optimization | Caching/refactoring "just in case" | YAGNI |
| History forwarding | Sending full chat history between agents | Artifact-first handoffs |

---

## Architecture

```
agents/
├── pm-agent/          # Coach — PM + UI design direction
├── be-agent/          # Lebron — backend execution
├── fe-agent/          # Bronny — frontend execution
└── qa-agent/          # Curry — QA / reproduction / validation
data/
└── weeks/             # Retro data (JSON)
index.html             # Retro dashboard
PLAYBOOK.md            # Full runbook (v3.2)
```

> **Note:** CEO (MiniSama) is the orchestrating agent that runs outside this repo — it lives in the OpenClaw workspace and coordinates the pipeline. The `agents/` directory contains the execution lanes Coach dispatches into: PM, BE, FE, and QA.

### Key files

| File | What it covers |
|------|---------------|
| [`PLAYBOOK.md`](./PLAYBOOK.md) | Full runbook: roles, task cards, handoffs, design audit, retro |
| [`dream_team_v2.md`](./dream_team_v2.md) | v2 runbook (archived) |
| [`dream_team_v2_examples.md`](./dream_team_v2_examples.md) | v2 examples (archived) |
| [`handoff_contracts.md`](./handoff_contracts.md) | Handoff format reference |

---

## What's different from gstack

| | gstack | Dream Team |
|--|--------|------------|
| Runtime | Single Claude Code session | 4 independent agents |
| Execution | Sequential slash commands | Parallel multi-agent |
| Orchestration | Manual (you run each command) | Automated pipeline |
| Design review | `/plan-design-review` + `/design-review` | Built into Curry's QA flow |
| Retro | `/retro` on demand | Weekly automated + dashboard |
| Scope | Claude Code only | Any agent runtime (Codex, Claude, etc.) |
| Review gates | Formal dashboard (Eng/CEO/Design) | Lightweight (Curry gate for release-critical) |

We're not competing with gstack. We learned from it: the "structured roles + review gates" philosophy is sound. We just run it across multiple agents instead of one.

---

## License

MIT. Use it, fork it, make it yours.
