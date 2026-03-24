# Task Card — Dashboard Cleanup (6AM Auto-Review)

**Scope:** Fix data rác + feature rác on dashboard per CEO review
**Working dir:** /Users/agent0/Works/dreamteam-by-taisama
**Files:** public/index.html, scripts/generate-dashboard-data.sh
**Deploy:** Vercel (auto-deploy on push to main)

---

## PART 1: Lebron (Data Layer — generate-dashboard-data.sh)

### 1A. Fix SLA JSON key mismatch
- JSON outputs `"resolutionSLA": {...}` but HTML reads `DASHBOARD_DATA?.sla`
- **Fix:** Rename `"resolutionSLA"` → `"sla"` in the output JSON (line ~1363)

### 1B. Remove self-feedback from feedbackFeed
- Currently feedbackFeed has 3 items all from "Coach" to "coach" (self-feedback = data rác)
- The script already filters self-feedback at line ~490 but it's not working correctly
- **Fix:** Ensure the filter `if [[ "${from_lower}" == "${to_lower}" ]]; then continue; fi` actually works. Check case sensitivity. Self-feedback (from == to) must be EXCLUDED.
- If after filtering there's zero feedback, output empty array `[]` — that's fine, UI handles empty state.

### 1C. Regenerate data after fixes
```bash
bash scripts/generate-dashboard-data.sh
```

---

## PART 2: Bronny (UI Layer — public/index.html)

### 2A. Remove dead nav items
- Desktop sidebar: Remove "Hiệu suất" nav link (it's a dead `#` link, Week tab already covers this)
- Keep only "Tổng quan" in sidebar
- Mobile bottom nav: keep "Tổng quan" + "Tuần" only (already done, just verify)

### 2B. Remove/hide Cost Metrics section when no real data
- Week tab has "Hiệu quả chi phí" section. Currently when all zeros, it replaces with "Chi phí chưa track được" text.
- **Fix:** The section should be FULLY HIDDEN (not just replaced with text) when allZero is true. Use `display:none` or remove the section entirely. OpenClaw can't track per-agent token costs — this section is useless until it can.

### 2C. Fix "Tốc độ xử lý" SLA section
- Today tab + Week tab both show SLA grid. Currently shows "Chưa có dữ liệu SLA" when all zeros.
- **Fix:** When SLA data key is `resolutionSLA` (currently broken), it falls back to `null` and shows the empty state message. After Lebron fixes the key name, this should work. But when ALL values are zero, HIDE the entire "Tốc độ xử lý" section (both tabs) instead of showing empty placeholder.

### 2D. Remove "Tu Vi" and "LaoShi" from secondary agents
- These are domain specialists, not core Dream Team agents. They clutter the UI with zero-value cards.
- **Fix:** Change `secondaryNames` filter to empty array, or remove the secondary agents section entirely. These agents should only appear if they have real activity.

### 2E. Hide Feedback Matrix when all cells are "—"
- Week tab shows a 7×7 matrix (all agents) with all dashes. It's noise.
- **Fix:** When ALL cells would show "—" (no cross-agent feedback exists), show the empty state instead of the matrix table.

### 2F. Make MiniSama CEO card more compact
- Currently shows "N/A" text which looks broken
- **Fix:** Remove the "N/A" text. Just show name + CEO badge + status badge. If status is "idle", just show "🟢 Hoạt động" (or don't show status at all for CEO).

---

## ACCEPTANCE CRITERIA
1. No dead nav links anywhere (desktop sidebar + mobile bottom nav)
2. No sections showing all-zeros or "chưa track được" placeholders — hide them
3. No self-feedback in feedbackFeed (Coach→coach must be excluded)
4. SLA data key mismatch fixed (`sla` not `resolutionSLA`)
5. Cost Metrics section hidden when no real data
6. Feedback Matrix hidden when no cross-agent feedback
7. Secondary agent cards (TuVi, LaoShi) hidden when no real activity
8. MiniSama card shows no "N/A" text
9. Dashboard loads clean without any broken-looking empty sections

## STOP CONDITION
- All acceptance criteria met
- `generate-dashboard-data.sh` runs without errors
- Dashboard loads at localhost with no console errors
