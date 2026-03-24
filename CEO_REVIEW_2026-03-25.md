# CEO Auto-Review — 2026-03-25 02:00 AM

## Audit Summary

Reviewed live site: https://dreamteam-by-taisama.vercel.app/
Date: 24/03/2026 (data generated at 2026-03-24T15:52:17Z)

---

## 🔴 CRITICAL ISSUES (must fix)

### 1. All KPI metrics show 0 — dashboard looks broken on first load
**Location:** Top KPI cards + Agent card metrics
**Problem:** `tasksCompleted=0`, `tasksBlocked=0`, `activeAgents=0`, `tokensToday=0`. Agent cards show `Tasks handled: 0`, `Tasks shipped: 0`, `Lessons: 0`, `Issues found: 0`. 
**Impact:** Dashboard looks like nothing works. First impression = broken.
**Fix:** When value is 0, show `—` (already partially done for top KPIs but NOT for agent expanded metrics). Also, the top KPI "Bị chặn" shows `0` in the screenshot — fix to show `—` when 0.

### 2. 8px font sizes remain — accessibility violation
**Location:** Week tab: lesson tags (`process`, `technical`), date labels (`03-23`)
**Problem:** QA Batch 2 already flagged this. Still not fixed. WCAG requires minimum 10px for readable text.
**Fix:** Change all `text-[8px]` to `text-[10px]` minimum.

### 3. Sidebar nav items are dead links / useless
**Location:** Desktop sidebar — "Hiệu suất" (insights) and mobile "Hỗ trợ" (help)
**Problem:** "Hiệu suất" links to `#` with no functionality. "Hỗ trợ" shows toast "Tính năng đang phát triển" — placeholder. These are FEATURES RÁC per the review criteria.
**Fix:** 
- Remove "Hiệu suất" nav item entirely (Week tab already covers this)
- Replace "Hỗ trợ" with something useful like "What's new today" that shows the latest retro highlights for today
- Or just remove both and keep sidebar clean with only "Tổng quan"

---

## 🟡 IMPORTANT ISSUES (should fix)

### 4. "Tốc độ xử lý" section is noise — shows all zeros with generic message
**Location:** Bottom of Today tab
**Problem:** "Dữ liệu sẽ tự động cập nhật khi action items được resolve." — This is DATA RÁC. It's a generic message with no actual data. SLA metrics are all 0.
**Fix:** Either hide this section when there's no real SLA data, or repurpose it to show something useful (e.g., "Last retro: X hours ago", "Next retro: in Y hours").

### 5. Feedback section is empty — Coach→coach self-feedback looks fake
**Location:** Feedback feed (Today tab, collapsed)
**Problem:** `feedbackFeed` has 3 items, all from "Coach" to "coach" (self-feedback). This looks like DATA RÁC. The `feedback: []` array is empty (the actual feed uses `feedbackFeed` key but the section renders from `DASHBOARD_DATA.feedback` which is empty).
**Fix:** 
- Fix the data feed key mismatch: HTML reads `DASHBOARD_DATA?.feedback` but data is in `feedbackFeed`
- Remove self-feedback (Coach→coach). Real feedback is between different agents.
- If no real cross-agent feedback exists, show empty state properly.

### 6. Weekly tab Trends chart is almost entirely flat zeros
**Location:** Week tab — "Biểu đồ xu hướng"
**Problem:** velocity = [0,3,0,0,0,0,0], quality = [0,1,0,0,0,0,0]. Chart is basically empty lines. Not useful.
**Fix:** Hide trends chart when data is too sparse (< 2 non-zero data points). Show a meaningful message instead.

### 7. Cost Metrics section is useless placeholder
**Location:** Week tab — "Hiệu quả chi phí"
**Problem:** All values are 0. `$0` cost per task, `0` tokens. This is DATA RÁC because the system can't actually track real token costs.
**Fix:** Remove this entire section. OpenClaw doesn't expose per-agent token costs to the dashboard generator. Either implement real tracking or remove the dead section.

---

## 🟢 NICE TO HAVE

### 8. Project health scores are arbitrary
**Problem:** Health = 60 for "has files", 90 for "has commits", 20 for "no files". These are made-up numbers, not real health metrics.
**Fix:** At minimum, label them as "Status indicators" not "Health". Better: compute from actual signals (last commit date, CI status, etc.).

### 9. "Hôm nay" tab shows yesterday's data (retro fires at 23:59)
**Problem:** Today is 25/03 but data is from 24/03. Date picker shows 24/03. Today's retro hasn't fired yet.
**Fix:** This is by design (retro fires at 23:59). But the "Hôm nay" tab should make this clear — show "Last retro: 24/03 (yesterday)" prominently.

### 10. MiniSama CEO card takes up too much space for no real info
**Problem:** CEO card shows "CEO", "Operations", health=—, metrics all empty. It's decorative.
**Fix:** Make CEO card compact — just name + role + status. Don't give it a full hero section when there's nothing to show.

---

## TASK CARD FOR LEBRON + BRONNY

### Priority 1 (Lebron — data layer):
1. Fix `feedback` key mismatch: `DASHBOARD_DATA.feedback` → should read from `feedbackFeed` or rename in data
2. Remove self-feedback (Coach→coach) from generate script
3. Fix all zero-metrics: agent expanded metrics should show `—` when 0
4. Fix top KPI "Bị chặn" showing 0 instead of `—`

### Priority 2 (Bronny — UI layer):
1. Change all `text-[8px]` to `text-[10px]` minimum
2. Remove "Hiệu suất" sidebar nav item (dead link)
3. Replace "Hỗ trợ" with useful content or remove it
4. Hide "Tốc độ xử lý" section when no real SLA data
5. Hide Trends chart when data too sparse
6. Remove or hide Cost Metrics section (no real data)
7. Make CEO card more compact

### Acceptance:
- No 8px text anywhere on the page
- No dead/placeholder nav items
- No sections showing all-zeros with no data
- No self-feedback in feed
- Dashboard looks useful when opened with current data state
