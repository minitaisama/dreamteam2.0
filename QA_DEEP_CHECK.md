# QA Deep Check — Dream Team Dashboard

**URL:** https://dreamteam-by-taisama.vercel.app/  
**Checked:** 2026-03-24 23:12 GMT+7  
**Viewport(s):** Desktop 1440x900, Mobile 375x812

## Artifacts

- Desktop full page: `qa-screenshots/desktop-fullpage-1440x900.jpg`
- Desktop top viewport: `qa-screenshots/desktop-viewport-top.jpg`
- Desktop mid 1: `qa-screenshots/desktop-mid-1.jpg`
- Desktop mid 2: `qa-screenshots/desktop-mid-2.jpg`
- Desktop bottom: `qa-screenshots/desktop-bottom.jpg`
- Desktop weekly tab: `qa-screenshots/desktop-tuan-tab-active.jpg`
- Desktop bottom sections: `qa-screenshots/desktop-homnay-bottom-sections.jpg`
- Desktop datepicker click: `qa-screenshots/desktop-datepicker-click.jpg`
- Desktop retro collapse check: `qa-screenshots/desktop-retro-collapsed.jpg`
- Mobile top: `qa-screenshots/mobile-top-375x812.jpg`
- Mobile full page: `qa-screenshots/mobile-fullpage-375x812.jpg`
- Mobile KPI area: `qa-screenshots/mobile-kpi-area.jpg`
- Mobile bottom nav: `qa-screenshots/mobile-bottom-nav.jpg`

---

## Executive Summary

The dashboard is visually close, but **data binding and mobile usability still have several real defects**.

Most important findings:
1. **Tu Vi agent is missing from UI** even though it exists in data.
2. **Feedback feed is incorrectly empty** because UI reads the wrong JSON field.
3. **Resolution SLA is incorrectly empty** because UI reads the wrong JSON field.
4. **Daily Retro collapsible is not collapsed by default on mobile** and collapse behavior is inconsistent with requirements.
5. **Primary agent names are truncated on mobile** (Coach/Lebron/Bronny/Curry not fully readable).
6. **Project health shows literal `null` to users** for `pkm-auction` newest file.

There were **no browser console errors** during the check. Only one non-blocking console warning appeared: Tailwind CDN should not be used in production.

---

## Issue List

### 1) [HIGH] Secondary agent **Tu Vi** is missing from rendered UI
- **Section:** Team / Secondary agents
- **Description:** Data JSON contains 7 agents including `Tu Vi`, but the page renders only `LaoShi` in the secondary section. `Tu Vi` is not visible on desktop or mobile.
- **Evidence:** Data file includes agent name `"Tu Vi"`; UI does not show it.
- **Root cause:** In `public/index.html`, secondary filter uses `['tuvi', 'laoshi']` with `a.name.toLowerCase().includes(n)`. `"tu vi".includes("tuvi") === false`, so Tu Vi is filtered out.
- **Screenshot path:** `qa-screenshots/desktop-viewport-top.jpg`
- **Fix instructions:**
  - Normalize spaces when matching agent names, e.g. compare `a.name.toLowerCase().replace(/\s+/g, '')`.
  - Or filter by stable `id` (`tuvi`, `laoshi`) instead of partial name matching.
  - Add a render test asserting both secondary agents appear.

### 2) [HIGH] Feedback feed shows **“Chưa có feedback”** even though data exists
- **Section:** Feedback gần đây
- **Description:** UI shows empty-state feedback, but JSON contains 3 records in `feedbackFeed`.
- **Evidence:** `public/data/dashboard-data.json` has `feedbackFeed` with 3 items; screen shows `Chưa có feedback`.
- **Root cause:** `init()` calls `renderFeedbackFeed(DASHBOARD_DATA?.feedback)`, but `feedback` is an empty array. Real data is in `feedbackFeed`.
- **Screenshot path:** `qa-screenshots/desktop-homnay-bottom-sections.jpg`
- **Fix instructions:**
  - Change render call from `renderFeedbackFeed(DASHBOARD_DATA?.feedback)` to `renderFeedbackFeed(DASHBOARD_DATA?.feedbackFeed)`.
  - Add a fixture test with non-empty feedback to prevent regression.
  - Verify timeline layout after binding real data.

### 3) [HIGH] Resolution SLA shows **empty state** although SLA data exists
- **Section:** Resolution SLA
- **Description:** UI shows `Chưa có dữ liệu SLA`, but JSON has `resolutionSLA` values.
- **Evidence:** JSON includes `resolved24h`, `resolved48h`, `resolved1w`, `open`, `overdue`; UI renders empty.
- **Root cause:** `init()` calls `renderSLA(DASHBOARD_DATA?.sla)` and `renderSLAWeek(DASHBOARD_DATA?.sla)`, but JSON uses `resolutionSLA`, not `sla`.
- **Screenshot path:** `qa-screenshots/desktop-homnay-bottom-sections.jpg`
- **Fix instructions:**
  - Pass `DASHBOARD_DATA?.resolutionSLA` into SLA renderers.
  - Update `renderSLAWeek()` mapping to use `resolved1w` as well as `resolvedWeek/withinWeek`.
  - Add a unit/render check for populated SLA boxes.

### 4) [HIGH] Primary agent names are truncated on mobile
- **Section:** Team / Primary agent cards / Mobile
- **Description:** On mobile, names for Coach, Lebron, Bronny, Curry are not fully readable. Computed widths show severe truncation.
- **Evidence:** Measured widths: `Coach/Lebron/Bronny/Curry` headings render at ~20px width with ellipsis.
- **Impact:** Fails explicit requirement: “All agent cards visible with full names (no truncation)”.
- **Screenshot path:** `qa-screenshots/mobile-top-375x812.jpg`
- **Fix instructions:**
  - Remove `truncate` from mobile card title or allow 2-line wrapping.
  - Increase available text width by reducing icon/health circle footprint.
  - Use responsive typography/layout for small screens.
  - Add a mobile visual regression test for all four names.

### 5) [MEDIUM] Daily Retro is expanded by default on mobile
- **Section:** Daily Retro / Mobile collapsibles
- **Description:** Requirement says collapsible sections should default collapsed on mobile. Action Items and Feedback are collapsed, but Daily Retro starts expanded.
- **Screenshot path:** `qa-screenshots/mobile-fullpage-375x812.jpg`
- **Fix instructions:**
  - Ensure `#retro-body` does not receive `.open` on initial render.
  - If desktop should remain expanded, make the behavior responsive by viewport.
  - Add a mobile startup assertion for all collapsibles.

### 6) [MEDIUM] Daily Retro collapse behavior is inconsistent / not clearly collapsing after interaction
- **Section:** Daily Retro interaction
- **Description:** Clicking Daily Retro did not produce a clear collapsed state during check; content remained effectively expanded from a behavior standpoint.
- **Evidence:** `#retro-body` still measured large height during interaction checks.
- **Screenshot path:** `qa-screenshots/desktop-retro-collapsed.jpg`
- **Fix instructions:**
  - Verify `toggleCollapsible()` is targeting the correct body and chevron IDs.
  - Confirm no later render step or CSS transition is re-expanding `#retro-body`.
  - Add a click test asserting `max-height` transitions between `0` and expanded state.

### 7) [MEDIUM] KPI cards do not show visible trend arrows
- **Section:** KPI cards
- **Description:** Requirement asked for trend arrows. KPI values render, but no visible up/down trend arrow indicators were found in desktop view.
- **Screenshot path:** `qa-screenshots/desktop-fullpage-1440x900.jpg`
- **Fix instructions:**
  - Render trend deltas from `tasksCompletedTrend`, `tasksBlockedTrend`, `actionItemsOpenTrend`, `tokensTrend`.
  - Show arrow icon + signed delta with semantic color.
  - Hide gracefully only when trend data is truly unavailable.

### 8) [MEDIUM] Project health exposes literal `null` string to users
- **Section:** Project health / `pkm-auction`
- **Description:** `pkm-auction` shows `Mới nhất: null` to users.
- **Evidence:** JSON stores `newestFile: "null"` as a literal string.
- **Screenshot path:** `qa-screenshots/desktop-fullpage-1440x900.jpg`
- **Fix instructions:**
  - Fix data generator to emit `null` or empty value, not string `"null"`.
  - In UI, render fallback label like `Chưa có file` when value is null/empty/string-"null".
  - Add sanitization helper for placeholder-like strings.

### 9) [MEDIUM] Feedback matrix appears empty / all dashes despite feedback data existing elsewhere
- **Section:** Tuần tab / Ma trận Feedback
- **Description:** Weekly feedback matrix is visible, but cells appear as all dashes. This makes the matrix look unpopulated.
- **Evidence:** Weekly tab visually shows `—` in cells.
- **Note:** JSON does contain `feedbackMatrix`, so this needs verification against intended mapping.
- **Screenshot path:** `qa-screenshots/desktop-tuan-tab-active.jpg`
- **Fix instructions:**
  - Verify matrix renderer uses actual matrix values instead of placeholder fallback.
  - Check key normalization between agent ids/names (`coach`, `curry`, `Tu Vi`, `LaoShi`, `Mini Taisama`).
  - Add a test fixture where at least one matrix cell is > 0 and must render numerically.

### 10) [LOW] Tailwind production warning in console
- **Section:** Console / Frontend setup
- **Description:** No runtime errors found, but browser console shows Tailwind CDN warning.
- **Evidence:** `cdn.tailwindcss.com should not be used in production`.
- **Screenshot path:** N/A
- **Fix instructions:**
  - Replace CDN Tailwind with a build-time Tailwind/PostCSS setup for production deploys.
  - Keep CDN only for prototype/dev if intentionally temporary.

---

## Checks That Passed

### Desktop
- Header title **Dream Team** is readable.
- Date input is visible and clickable.
- KPI cards render and appear equal height.
- Mini Taisama CEO card is prominent and health score is visible.
- Primary agent cards for Coach, Lebron, Bronny, Curry are present on desktop.
- LaoShi secondary agent is visible.
- Project health shows **5 projects**.
- Weekly tab contains:
  - Weekly insight
  - Trend chart
  - Lessons
  - Improvement velocity
  - Feedback matrix
  - Cost metrics
  - Weekly summary
- No horizontal overflow found on mobile.
- Bottom nav bar exists on mobile with **3 items**.
- KPI row is horizontally scrollable on mobile.
- Project health is rendered as stacked cards on mobile, not a table.
- No visible `coming soon` or `TODO` strings surfaced to users.
- No browser console errors.

---

## Data Integrity Review

Fetched from: `https://dreamteam-by-taisama.vercel.app/data/dashboard-data.json`

### Verified structure
- Agents: **7** ✅
  - Coach
  - Lebron
  - Bronny
  - Curry
  - Tu Vi
  - LaoShi
  - Mini Taisama
- Projects: **5** ✅
- Retro dates: **2** ✅ (`2026-03-23`, `2026-03-24`)
- Health scores array present ✅
- Alerts field present ✅ (empty array)
- Feedback feed present ✅ (`feedbackFeed` has 3 items)

### Data issues found
1. `feedback` is empty while `feedbackFeed` holds the real records.
2. `resolutionSLA` exists, but UI expects `sla`.
3. `pkm-auction.newestFile` is literal string `"null"`.
4. Several summary metrics are zero (`tasksCompleted`, `tasksBlocked`, `activeAgents`, `tokensToday`) — these may be legitimate for the selected date, but should be confirmed against intended source freshness.
5. Cost metrics are all zero; if real pipeline has not been connected yet, that should be marked as real empty state, not simulated productivity data.

---

## Requirement-by-Requirement Status

### Desktop 1440x900
- Header readable: **PASS**
- Date picker works/clickable: **PASS**
- KPI equal height: **PASS**
- KPI trend arrows showing: **FAIL**
- MiniSama CEO card prominent: **PASS**
- Health score visible: **PASS**
- Coach/Lebron/Bronny/Curry visible: **PASS**
- Expand/collapse works: **PARTIAL**
- Secondary agents visible (tuvi, laoshi): **FAIL**
- 5 projects shown: **PASS**
- Project data correct: **PARTIAL** (`null` exposed)
- Retro detail collapsible/readable: **PARTIAL**
- Action items priority badges/age display: **PARTIAL** (priority visible; age not clearly surfaced in UI)
- Feedback feed timeline format: **FAIL** (wrong empty state)
- Resolution SLA numbers showing: **FAIL**
- Tuần tab sections present: **PASS**

### Mobile 375x812
- Full page screenshot: **PASS**
- Bottom nav visible with 3 items: **PASS**
- All agent cards visible with full names: **FAIL**
- KPI row horizontally scrollable: **PASS**
- Project health stacked: **PASS**
- Collapsible sections default collapsed: **FAIL** (Daily Retro expanded)
- No horizontal overflow: **PASS**
- Touch targets >= 44px: **PASS** on major tab/collapse controls observed
- Text readable: **PARTIAL** (agent names too truncated)

---

## Recommended Fix Order

1. **Fix data binding mismatches**
   - `feedbackFeed` vs `feedback`
   - `resolutionSLA` vs `sla`
2. **Fix Tu Vi rendering**
   - Match by `id` or normalized name
3. **Fix mobile agent card layout**
   - Remove truncation / allow wrapping
4. **Fix project fallback rendering**
   - Stop showing literal `null`
5. **Fix collapsible default state + toggle behavior**
6. **Add KPI trend indicators**
7. **Verify feedback matrix numeric rendering**
8. **Move off Tailwind CDN for production**

---

## Suggested Regression Tests

- Render test: all 7 agents appear, including `Tu Vi` and `LaoShi`.
- Render test: feedback feed displays items from `feedbackFeed`.
- Render test: SLA boxes display values from `resolutionSLA`.
- Mobile snapshot test: agent names fully readable at 375px width.
- Project card fallback test: `null`/empty newest file renders as friendly empty state.
- Interaction test: Daily Retro / Action Items / Feedback collapse and expand correctly.
- KPI test: trend indicators render when trend values are present.

---

## Final QA Verdict

**Status:** `ship_with_risk`

Reason: site is usable and visually coherent, but there are still **real data/UI correctness bugs** affecting trustworthiness:
- missing Tu Vi,
- missing feedback feed,
- missing SLA,
- mobile name truncation,
- visible `null` data.

These should be fixed before calling the dashboard fully production-ready.
