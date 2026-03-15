# Dream Team v2

A lightweight operating model for:
- Coach (`pm-agent`)
- Lebron (`code-agent`)
- Curry (`qa-agent`)

This version is optimized for:
- **Codex support**
- **lightweight execution**
- **low token burn**
- **clear ownership**

---

## 1. Core idea

Dream Team v2 is **stage-based**, not model-based.

Roles stay the same:
- **Coach** = scope, task framing, workflow, release gate
- **Lebron** = implementation and local execution
- **Curry** = independent validation and release confidence

But model choice is per stage:
- use the best planner/reviewer where needed
- use **Codex as the default executor** for well-scoped coding work
- do not force one model to handle planning, coding, QA, and release in the same thread

---

## 2. Lightweight operating modes

### Mode A — Solo
Use when:
- task is small
- scope is clear
- independent QA is not necessary

Flow:
1. Coach handles directly or sends one bounded task to Lebron
2. Return result

Default examples:
- small fixes
- repo reading
- quick reviews
- doc patches

### Mode B — Build (default)
Use when:
- code changes are needed
- risk is moderate
- lightweight independent QA is useful

Flow:
1. Coach writes tiny task card
2. Lebron implements + runs local verification
3. Curry validates changed surface only
4. Coach sends one synthesized update

This is the **default multi-agent mode**.

### Mode C — Release-critical
Use when:
- auth/payment/core flow changes
- blast radius is large
- release confidence matters
- regression risk is meaningful

Flow:
1. Coach freezes scope
2. Lebron builds
3. Curry validates changed path + one regression path
4. Coach decides `ship | ship_with_risk | hold`

Do not use this mode unless risk justifies it.

---

## 3. Hard learnings from prior projects

### Learning 1 — Never code before scope is frozen
When scope, boundary, and DoD are unclear:
- Lebron overbuilds
- Curry validates the wrong thing
- Coach reframes mid-flight
- token burn rises fast

**Rule:** no coding spawn before a tiny spec exists.

### Learning 2 — Parallelism only helps after clean decomposition
If work is parallelized too early:
- agents overlap
- duplicate analysis appears
- the human has to merge conflicting outputs

**Rule:** parallelize only after independent slices are explicit.

### Learning 3 — QA must validate a fixed contract
QA fails when implementation changes the target while validation is still being defined.

**Rule:** Coach freezes:
- target behavior
- one acceptance check
- one regression watch

Curry validates against that fixed contract.

### Learning 4 — Many failures are not code failures
Past work showed many misses were really:
- parser issues
- scorer/logic issues
- corpus/data-shape issues
- infra/env issues

**Rule:** classify failure type before recoding.

### Learning 5 — Artifact beats transcript
Long chat handoffs cause:
- re-reading
- ambiguity
- accidental drift in source of truth

**Rule:** handoffs should prefer task cards, changed files, test results, and artifact paths.

### Learning 6 — Most token waste comes from re-explaining
Waste usually comes from:
- full-thread forwarding
- repeated analysis by multiple agents
- long narrative updates
- open-ended prompts

**Rule:** use short bounded contracts and role-specific outputs.

---

## 4. Codex support policy

### 4.1 Codex is the default executor
Use Codex for:
- bounded implementation
- patch loops
- local command execution
- repo-local code/test iterations

Do **not** send Codex vague product questions as the default path.

### 4.2 Coach must convert vague asks into bounded task cards first
Raw user asks should not go straight to Lebron/Codex unless ambiguity is already low.

### 4.3 Do not port Claude-style prompts 1:1
Claude-centric long persona prompts should be converted into:
- compact task contract
- explicit scope
- explicit acceptance
- explicit stop condition

### 4.4 Execution backend is replaceable
The team model should assume:
- roles are stable
- model/provider can change
- handoff contract stays the same

---

## 5. Tiny task card (mandatory)

Use this exact minimal format:

```text
Task:
Goal:
Scope:
Non-goals:
Acceptance:
Risk focus:
```

### Example

```text
Task: Patch repo onboarding doc
Goal: clarify first-run setup
Scope: README + setup notes only
Non-goals: no code changes
Acceptance: new user can follow steps without ambiguity
Risk focus: avoid changing actual install behavior
```

---

## 6. Lightweight handoff contracts

### Coach → Lebron
Maximum:
- 1 task title
- 3–6 bullets
- 1 acceptance line
- 1 stop condition

Template:

```text
Task:
- goal
- scope
- touched surfaces
- constraints
Acceptance:
Stop when:
```

### Lebron → Curry
Send only:
- changed files
- commands run
- expected critical path
- known risk

Template:

```text
Changed:
Commands:
Critical path:
Known risk:
```

### Curry → Coach
Send only:
- tested scope
- pass/fail
- remaining risk
- recommendation

Template:

```text
Tested:
Result:
Remaining risk:
Recommendation: ship | ship_with_risk | hold
```

---

## 7. QA rules

### Default QA = changed surface only
Do:
- changed path check
- one regression watch if needed
- one critical-path smoke flow

Do not default to full regression.

### Full QA only when justified
Escalate only when:
- auth/payment/core flow changed
- user-facing high-risk surface changed
- data mutation/concurrency/trust boundary involved
- prior regressions exist in the same area

### Contract checks for backend/UI work
For backend/UI contract changes, require at least:
- **1 pinned API contract test**
- **1 representative UI/render/fixture check**

### Curry signs release confidence, not implementation completion
- Lebron: `implemented + locally verified`
- Curry: `release confidence acceptable / not acceptable`
- Coach: final ship/hold call

---

## 8. Token burn rules

### Rule 1 — No full-history forwarding by default
Only pass:
- task card
- relevant file paths
- current artifact
- exact blocker

### Rule 2 — No duplicate analysis
If Coach already made the product call:
- Lebron should not re-litigate it
- Curry should not reframe it

### Rule 3 — Update only on state change
Valid updates:
- started
- blocked
- risk found
- finished

No filler progress chatter.

### Rule 4 — Keep prompts brutally short
Inter-agent prompts should be:
- direct
- task-shaped
- low-context
- no narrative padding

### Rule 5 — One artifact is better than ten messages
Prefer compact artifacts over long conversational recap.

### Rule 6 — Classify before recoding
Before editing, decide if the failure is:
- code
- parser
- scorer
- corpus/data-shape
- infra/env

This prevents wasted coding cycles.

---

## 9. Source-of-truth rule

If artifacts are used, each should clearly imply or state:
- what it is
- what inputs it came from
- whether it is candidate or approved
- who owns it

At minimum, avoid treating drafts, summaries, or derived outputs as published truth.

---

## 10. Default operating summary

### Small task
- use **Solo**

### Normal coding task
- use **Build**

### Risky / ship-sensitive task
- use **Release-critical**

### Always true
- Coach freezes the task
- Lebron executes bounded work
- Curry validates only when needed
- keep handoffs tiny
- keep QA scoped
- keep token burn low

---

## 11. One-line doctrine

**Dream Team v2 is a lightweight stage-based system where Coach freezes the problem, Lebron/Codex executes bounded work fast, Curry validates with evidence when needed, and every handoff is kept brutally small to minimize token burn.**
