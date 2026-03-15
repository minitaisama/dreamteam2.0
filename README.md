# dream-team

A lightweight multi-agent operating model for software work.

Core roles:
- **Coach** (`pm-agent`) — scope, task framing, workflow, release gate
- **Lebron** (`code-agent`) — implementation and local execution
- **Curry** (`qa-agent`) — independent validation and release confidence

This repo contains the public docs/runbooks for the current Dream Team setup.

---

## What this project is

Dream Team is a practical operating model for running software work across a small set of specialized roles without turning every task into process theater.

The goal is simple:
- keep planning clear
- keep implementation fast
- keep QA independent when needed
- keep token burn low
- keep ownership obvious

Dream Team v2 is intentionally **lightweight**.
It is not trying to be a huge framework or a prompt zoo.
It is a small runbook for getting real work done with clear handoffs.

---

## Inspiration

This project was strongly inspired by **gstack** by Garry Tan:
- repo: <https://github.com/garrytan/gstack>

What gstack got very right:
- explicit workflow gears instead of one mushy assistant mode
- specialized roles/modes for different jobs
- treating AI work as workflow orchestration, not just prompting
- making planning, review, QA, and shipping feel like distinct operating modes

That was the spark.

But Dream Team is **not a copy** of gstack.
It takes the core insight and adapts it to a different environment, different tooling assumptions, and a different set of lessons learned from real project work.

---

## Why Dream Team exists

After running real projects, a few patterns kept repeating:

- coding agents moved too early before scope was frozen
- multiple agents overlapped on the same analysis
- QA sometimes validated a moving target
- long chat handoffs wasted tokens
- full history forwarding made runs expensive and noisy
- one-model-does-everything workflows felt convenient but degraded quality

Dream Team exists to solve those problems with a simpler model.

---

## What changed from the original inspiration

Compared with the original inspiration, this project intentionally changed several things.

### 1. From model-centric to stage-centric
Instead of building around one model personality, Dream Team is built around **stages of work**:
- framing
- execution
- validation
- release decision

Roles are stable.
Model/provider can change.

### 2. Codex support is first-class
Dream Team v2 explicitly treats **Codex** as the default executor for well-scoped coding work.

That means:
- vague asks should not go straight to the executor
- Coach must freeze a tiny task card first
- prompts should be short, bounded, and execution-oriented
- long Claude-style prose prompts should not be ported 1:1

### 3. Lightweight over elaborate
The original inspiration showed the power of explicit modes.
Dream Team pushes that further toward **minimum viable process**.

Only 3 modes are kept:
- **Solo**
- **Build** (default)
- **Release-critical**

This repo deliberately avoids adding too many extra gears.

### 4. Artifact-first handoffs
Instead of “see thread above,” Dream Team prefers:
- tiny task cards
- changed files
- verify results
- concise QA outputs
- compact artifact paths when needed

### 5. Token burn is treated as a first-class design constraint
Dream Team was redesigned around a harsh reality:
most waste does **not** come from hard tasks.
It comes from:
- re-explaining context
- duplicate analysis
- forwarding long histories
- verbose inter-agent chatter

So the runbook now optimizes for **quality per token**, not just quality in the abstract.

---

## What Dream Team improves over the source inspiration

### Improvement 1 — Better fit for Codex-style execution
Dream Team makes Codex the default bounded executor instead of assuming a Claude-shaped workflow.

### Improvement 2 — Simpler operating model
Instead of many cognitive modes, Dream Team v2 reduces the core workflow to 3 practical modes:
- small task
- normal build
- high-risk release

### Improvement 3 — Stronger PM / QA separation
Dream Team makes this explicit:
- **Lebron can finish implementation**
- **Curry decides confidence**
- **Coach decides ship / hold**

This reduces “done but not actually safe” outcomes.

### Improvement 4 — Better handoff discipline
Dream Team uses tiny task cards and fixed response contracts so roles do less re-interpretation.

### Improvement 5 — Lower token burn
Dream Team v2 aggressively avoids:
- full-thread forwarding
- repeated cross-role analysis
- narrative-heavy handoffs
- broad QA on every task

### Improvement 6 — Derived from real failures, not just elegant theory
The runbook was updated after real project pain:
- scope drift
- QA drift
- retrieval/data-shape confusion
- duplicated multi-agent analysis
- expensive context reloads

So the model is less romantic and more battle-tested.

---

## Dream Team v2 at a glance

### Mode A — Solo
Use when:
- task is small
- scope is clear
- independent QA is unnecessary

Flow:
- Coach handles directly or sends one bounded task to Lebron

### Mode B — Build (default)
Use when:
- code changes are needed
- risk is moderate
- lightweight independent QA is useful

Flow:
1. Coach writes tiny task card
2. Lebron implements + locally verifies
3. Curry validates changed surface only when needed
4. Coach synthesizes one update

### Mode C — Release-critical
Use when:
- auth/payment/core-flow changes
- blast radius is high
- release confidence matters

Flow:
1. Coach freezes scope
2. Lebron builds
3. Curry validates changed path + one regression path
4. Coach decides `ship | ship_with_risk | hold`

---

## Core runbook rules

### Tiny task card is mandatory
```text
Task:
Goal:
Scope:
Non-goals:
Acceptance:
Risk focus:
```

### Default handoff philosophy
- short
- explicit
- bounded
- no essay-style backstory unless needed for correctness

### QA philosophy
- validate the fixed contract
- changed surface by default
- full regression only when risk justifies it

### Token philosophy
- no full history forwarding by default
- no duplicate analysis by multiple roles without reason
- updates only when state changed
- artifacts beat long transcripts

---

## Hard learnings behind this runbook

1. **Never code before scope is frozen**
2. **Parallelism only helps after clean decomposition**
3. **QA must validate a fixed contract**
4. **Many failures are parser/data/env issues, not pure code issues**
5. **Artifact beats transcript**
6. **Most token waste comes from re-explaining**

These are the reasons the project looks the way it does now.

---

## Repo contents

- `dream_team_v2.md` — current lightweight runbook
- `agents/pm-agent/AGENT.md` — Coach prompt/role doc
- `agents/code-agent/AGENT.md` — Lebron prompt/role doc
- `agents/qa-agent/AGENT.md` — Curry prompt/role doc

---

## Current status

Dream Team v2 is the current active model.

Its priorities are:
- lightweight execution
- Codex-friendly handoffs
- strict role ownership
- better QA gating
- aggressive token efficiency

---

## Short version

**Dream Team v2 is a lightweight stage-based system where Coach freezes the problem, Lebron/Codex executes bounded work fast, Curry validates with evidence when needed, and every handoff is kept brutally small to minimize token burn.**
