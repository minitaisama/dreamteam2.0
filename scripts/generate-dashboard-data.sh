#!/usr/bin/env bash
# generate-dashboard-data.sh — Parse workspace data → dashboard-data.json
# Pure bash (POSIX/macOS compatible), idempotent
# Phase 1-3: Active tasks, feedback feed, priority, lessons, alerts, health, velocity
set -euo pipefail

WORKSPACE="/Users/agent0/.openclaw/workspace"
RETRO_DIR="$WORKSPACE/memory/retro/daily"
PROCESS_MEM="$WORKSPACE/memory/process/dream-team.md"
PROJECT_STATUS_SCRIPT="$WORKSPACE/scripts/project-status.sh"
OUTPUT_DIR="/Users/agent0/Works/dreamteam-by-taisama/public/data"
OUTPUT_FILE="$OUTPUT_DIR/dashboard-data.json"
TMPDIR_RETRO=$(mktemp -d)

TODAY=$(date +%Y-%m-%d)
TODAY_EPOCH=$(date -j -f "%Y-%m-%d" "$TODAY" "+%s" 2>/dev/null || date +%s)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$OUTPUT_DIR"

trap 'rm -rf "$TMPDIR_RETRO"' EXIT

# ─── Helpers ───────────────────────────────────────────────────────────

jstr() {
  local s=""
  while IFS= read -r line || [ -n "$line" ]; do
    [ -n "$s" ] && s="${s}\\n"
    s="${s}${line}"
  done
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//	/\\t}"
  printf '%s' "$s"
}

jstr_arg() {
  printf '%s' "$1" | jstr
}

# Date arithmetic helpers (macOS compatible)
date_to_epoch() {
  date -j -f "%Y-%m-%d" "$1" "+%s" 2>/dev/null || echo "0"
}

epoch_to_short_date() {
  date -j -f "%Y-%m-%d" "$1" "+%m-%d" 2>/dev/null || echo "$1"
}

days_between() {
  local d1="$1" d2="$2"
  local e1 e2
  e1=$(date_to_epoch "$d1")
  e2=$(date_to_epoch "$d2")
  echo $(( (e2 - e1) / 86400 ))
}

# ISO week number (macOS compatible)
iso_week() {
  local d="$1"
  # Use Python for reliable ISO week
  python3 -c "
import datetime
try:
    w = datetime.date.fromisoformat('${d}').isocalendar()[1]
    print(f'W{w:02d}')
except:
    print('W00')
" 2>/dev/null || echo "W00"
}

# ─── Agent roster (static mapping) ────────────────────────────────────

AGENT_MAP='
pm-agent|coach|Coach|PM Agent|📋|purple
be-agent|lebron|Lebron|Backend Engineer|🛠️|blue
fe-agent|bronny|Bronny|Frontend Engineer|🎨|green
qa-agent|curry|Curry|QA Engineer|🔍|orange
tuvi-agent|tuvi|Tu Vi|Domain Specialist|🔮|indigo
laoshi-agent|laoshi|LaoShi|Mandarin Teacher|🧑‍🏫|rose
mini-taisama|minisama|Mini Taisama|CEO|✨|gold
'

CORE_AGENTS="coach lebron bronny curry"

# ─── Parse all retro files ────────────────────────────────────────────

parse_retro_file() {
  local file="$1"
  local bname=$(basename "$file" .md)
  local outdir="$TMPDIR_RETRO/$bname"
  mkdir -p "$outdir"

  local section=""
  local parent_section=""
  local in_action_table=0
  local action_counter=0

  > "$outdir/wins.txt"
  > "$outdir/problems.txt"
  > "$outdir/actions.txt"
  > "$outdir/notes.txt"
  > "$outdir/lessons.txt"
  > "$outdir/feedback.txt"
  > "$outdir/in_progress.txt"
  > "$outdir/next.txt"
  > "$outdir/root_causes.txt"
  echo "0" > "$outdir/done.txt"
  echo "0" > "$outdir/blocked.txt"
  echo "0" > "$outdir/active.txt"
  echo "false" > "$outdir/has_wins.txt"
  echo "false" > "$outdir/has_problems.txt"
  echo "false" > "$outdir/has_root_causes.txt"
  echo "false" > "$outdir/has_action_items.txt"

  while IFS= read -r line || [ -n "$line" ]; do
    # Detect ## level-2 headers (parent sections) — but NOT ### level-3
    if [[ "$line" =~ ^##[[:space:]] ]] && [[ ! "$line" =~ ^### ]]; then
      if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
        local h2="${BASH_REMATCH[1]}"
        if [[ "$h2" == *"Per-Agent"* ]]; then
          parent_section="$h2"
        else
          parent_section=""
        fi
      fi
    fi

    # Detect ### level-3 headers
    if [[ "$line" =~ ^###[[:space:]]+(.+)$ ]]; then
      local header="${BASH_REMATCH[1]}"
      section="$header"
      in_action_table=0
      continue
    fi

    # Summary section
    if [[ "$section" == *"📊"* || "$section" == *"Today"*"Summary"* ]]; then
      if [[ "$line" =~ Tasks\ completed:\*\*[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}" > "$outdir/done.txt"
      fi
      if [[ "$line" =~ Tasks\ blocked:\*\*[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}" > "$outdir/blocked.txt"
      fi
      if [[ "$line" =~ Active\ agents:\*\*[[:space:]]*([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}" > "$outdir/active.txt"
      elif [[ "$line" =~ Active\ agents:\*\*[[:space:]]*([^*]+) ]]; then
        local agents_raw="${BASH_REMATCH[1]}"
        local count=$(echo "$agents_raw" | tr ',' '\n' | grep -c '[a-zA-Z]' || true)
        echo "${count:-0}" > "$outdir/active.txt"
      fi
    fi

    # Wins section
    if [[ "$section" == *"✅"* ]]; then
      if [[ "$line" =~ ^[0-9]+\.\ \*\*(.+)\*\*[[:space:]]*[-—]*[[:space:]]*(.*) ]]; then
        local title="${BASH_REMATCH[1]}"
        local detail="${BASH_REMATCH[2]}"
        local entry="$title"
        [ -n "$detail" ] && entry="$title — $detail"
        echo "$entry" >> "$outdir/wins.txt"
        echo "true" > "$outdir/has_wins.txt"
      fi
    fi

    # Problems section
    if [[ "$section" == *"❌"* ]]; then
      if [[ "$line" =~ ^[0-9]+\.\ \*\*(.+)\*\*[[:space:]]*[-—]*[[:space:]]*(.*) ]]; then
        local title="${BASH_REMATCH[1]}"
        local detail="${BASH_REMATCH[2]}"
        local entry="$title"
        [ -n "$detail" ] && entry="$title — $detail"
        echo "$entry" >> "$outdir/problems.txt"
        echo "true" > "$outdir/has_problems.txt"
      fi
    fi

    # Root Cause section
    if [[ "$section" == *"🔍"* ]]; then
      if [[ "$line" =~ ^-\ \*\*Issue:\*\*[[:space:]]*(.+)$ ]]; then
        echo "${BASH_REMATCH[1]}" >> "$outdir/root_causes.txt"
        echo "true" > "$outdir/has_root_causes.txt"
      elif [[ "$line" =~ ^-\ \*\*Root\ cause.*\*\*[[:space:]]*(.+)$ ]]; then
        echo "RootCause: ${BASH_REMATCH[1]}" >> "$outdir/root_causes.txt"
        echo "true" > "$outdir/has_root_causes.txt"
      fi
    fi

    # In Progress / Next sections (for active tasks)
    if [[ "$section" == *"🔄"* || "$section" == *"In Progress"* || "$section" == *"Next"* ]]; then
      if [[ "$line" =~ ^-[[:space:]]+(.+)$ ]]; then
        local task_text="${BASH_REMATCH[1]}"
        # Clean markdown formatting
        task_text=$(echo "$task_text" | sed 's/\*\*//g')
        if [[ "$section" == *"🔄"* || "$section" == *"In Progress"* ]]; then
          echo "$task_text" >> "$outdir/in_progress.txt"
        else
          echo "$task_text" >> "$outdir/next.txt"
        fi
      fi
    fi

    # Action items table
    if [[ "$section" == *"🎯"* ]]; then
      if [[ "$line" =~ ^\|[[:space:]]*\#[[:space:]]*\|[[:space:]]*Action ]]; then
        in_action_table=1
        continue
      fi
      if [[ "$line" =~ ^\|[-\[:space:]]*\| ]]; then
        continue
      fi
      if [[ "$line" =~ ^\|[[:space:]]*$ ]]; then
        in_action_table=0
        continue
      fi
      if [[ $in_action_table -eq 1 && "$line" =~ ^\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
        local a_id="${BASH_REMATCH[1]}"
        local a_action a_owner a_due a_status_raw a_status a_carried
        a_action=$(echo "$line" | awk -F'|' '{print $3}' | sed 's/\*\*//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_owner=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_due=$(echo "$line" | awk -F'|' '{print $5}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_status_raw=$(echo "$line" | awk -F'|' '{print $6}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_status="pending"
        a_carried="false"
        if [[ "$a_status_raw" == *"✅"* ]]; then
          a_status="done"
        fi
        if [[ "$a_action" == *"[CARRIED]"* ]]; then
          a_carried="true"
        fi
        # Compute age in days
        local age_days
        age_days=$(days_between "$bname" "$TODAY")
        [ "$age_days" -lt 0 ] && age_days=0

        # Compute priority
        local priority="P2"
        if [[ "$a_carried" == "true" ]] && [[ "$a_status" == "pending" ]]; then
          if [ "$age_days" -ge 3 ]; then
            priority="P0"
          elif [ "$age_days" -ge 2 ]; then
            priority="P1"
          fi
        fi

        echo "true" > "$outdir/has_action_items.txt"
        [ -n "$a_action" ] && echo "{\"id\":${a_id},\"action\":\"$(jstr_arg "$a_action")\",\"owner\":\"$(jstr_arg "$a_owner")\",\"due\":\"$(jstr_arg "$a_due")\",\"status\":\"${a_status}\",\"priority\":\"${priority}\",\"ageDays\":${age_days},\"carried\":${a_carried},\"retroDate\":\"${bname}\"}" >> "$outdir/actions.txt"
      fi
    fi

    # Lesson / Rule Update section
    if [[ "$section" == *"💡"* || "$section" == *"Lesson"* ]]; then
      if [[ "$line" =~ ^-\ \*\*Lesson:\*\*[[:space:]]*(.+)$ ]]; then
        local lesson_text="${BASH_REMATCH[1]}"
        # Extract tag
        local tag="process"
        [[ "$lesson_text" =~ [Cc]ron ]] && tag="process"
        [[ "$lesson_text" =~ [Ss]ub-agent|[Ii]njection ]] && tag="technical"
        [[ "$lesson_text" =~ [Ss]cope|[Tt]ask ]] && tag="process"
        [[ "$lesson_text" =~ [Cc]urriculum ]] && tag="domain"
        local status="observing"
        [[ "$line" =~ [Pp]romote[[:space:]]*now ]] && status="promoted"
        echo "${tag}|${status}|$(jstr_arg "$lesson_text")" >> "$outdir/lessons.txt"
      fi
    fi

    # Per-Agent Notes (under ## Per-Agent Notes level-2 header)
    if [[ "$parent_section" == *"Per-Agent"* ]]; then
      if [[ "$section" =~ ^(.+?)[[:space:]]*\( ]]; then
        local agent_raw="${BASH_REMATCH[1]}"
      else
        local agent_raw="$section"
      fi
      local agent_key=$(echo "$agent_raw" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]//g')
      case "$agent_key" in
        coach*) agent_key="coach" ;;
        lebronbackend*) agent_key="lebron" ;;
        lebron*) agent_key="lebron" ;;
        bronnyfrontend*) agent_key="bronny" ;;
        bronny*) agent_key="bronny" ;;
        curryqa*) agent_key="curry" ;;
        curry*) agent_key="curry" ;;
      esac
      if [[ "$line" =~ ^-[[:space:]]*\*\*Note:\*\*[[:space:]]*(.+)$ ]]; then
        local note="${BASH_REMATCH[1]}"
        echo "${agent_key}|$(jstr_arg "$note")" >> "$outdir/notes.txt"
      fi
      # Also capture feedback-like content from per-agent notes
      if [[ "$line" =~ ^-[[:space:]]*(Tasks managed|Tasks built|Tasks reviewed|Validations|Issues|Handoff quality|Scope issues)[^:]*:[[:space:]]*(.+)$ ]]; then
        local note_content="${BASH_REMATCH[2]}"
        # Only capture if it contains actionable feedback
        if [[ "$note_content" =~ [Gg]ap|[Nn]eed|[Ii]dentified|[Bb]ut|[Hh]owever ]]; then
          echo "${agent_key}|$(jstr_arg "$note_content")" >> "$outdir/feedback.txt"
        fi
      fi
    fi
  done < "$file"
}

for f in "$RETRO_DIR"/*.md; do
  [ -f "$f" ] && parse_retro_file "$f"
done

# ─── Parse process memory for feedback and lessons ────────────────────

if [ -f "$PROCESS_MEM" ]; then
  PROC_FB_DIR="$TMPDIR_RETRO/process_feedback"
  mkdir -p "$PROC_FB_DIR"
  > "$PROC_FB_DIR/feedback.txt"
  > "$PROC_FB_DIR/seeds.txt"

  in_seeds=0
  in_feedback=0
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
      header="${BASH_REMATCH[1]}"
      in_seeds=0
      in_feedback=0
      if [[ "$header" == *"seed"* || "$header" == *"Seed"* || "$header" == *"Seeded"* ]]; then
        in_seeds=1
      fi
      if [[ "$header" == *"Feedback"* || "$header" == *"feedback"* ]]; then
        in_feedback=1
      fi
      continue
    fi

    if [[ $in_seeds -eq 1 && "$line" =~ ^-[[:space:]]+(.+)$ ]]; then
      echo "$(jstr_arg "${BASH_REMATCH[1]}")" >> "$PROC_FB_DIR/seeds.txt"
    fi

    if [[ $in_feedback -eq 1 && "$line" =~ ^-[[:space:]]+(.+)$ ]]; then
      echo "$(jstr_arg "${BASH_REMATCH[1]}")" >> "$PROC_FB_DIR/feedback.txt"
    fi
  done < "$PROCESS_MEM"
fi

# ─── Parse project status ─────────────────────────────────────────────

PROJECTS_JSON="[]"

if [ -x "$PROJECT_STATUS_SCRIPT" ]; then
  PROJECT_RAW=$(bash "$PROJECT_STATUS_SCRIPT" 2>/dev/null || echo "{}")
  echo "$PROJECT_RAW" | grep -oE '"[^"]+":\{[^}]+\}' > "$TMPDIR_RETRO/project_blocks.txt"

  proj_arr=""
  while IFS= read -r block; do
    dom=$(echo "$block" | sed 's/"//;s/":{.*//;s/"//')
    [ -z "$dom" ] && continue

    pfiles=0
    pstatus="exists"
    pnewest="null"
    pcommits="[]"

    if [[ "$block" =~ \"files\":([0-9]+) ]]; then
      pfiles="${BASH_REMATCH[1]}"
    fi
    if [[ "$block" =~ \"status\":\"([^\"]+)\" ]]; then
      pstatus="${BASH_REMATCH[1]}"
    fi

    if [[ "$block" =~ \"newest\":([^,}]+) ]]; then
      raw="${BASH_REMATCH[1]}"
      pnewest=$(echo "$raw" | sed 's|.*/||;s/"//g')
      [ -z "$pnewest" ] && pnewest="null"
    fi

    if [[ "$block" =~ \"git\":\[([^\]]*)\] ]]; then
      raw_c="${BASH_REMATCH[1]}"
      c=""
      echo "$raw_c" | tr ',' '\n' > "$TMPDIR_RETRO/git_commits_tmp.txt"
      while IFS= read -r commit; do
        commit=$(echo "$commit" | sed 's/^[[:space:]]*"//;s/"$//;s/^[[:space:]]*//')
        [ -z "$commit" ] && continue
        [ -n "$c" ] && c="$c,"
        c="${c}\"$(jstr_arg "$commit")\""
      done < "$TMPDIR_RETRO/git_commits_tmp.txt"
      [ -n "$c" ] && pcommits="[$c]"
    fi

    pnote="Active"
    [ "$pfiles" -eq 0 ] && pnote="Empty domain"

    phealth=60
    [ "$pfiles" -gt 0 ] && phealth=60
    [ "$pcommits" != "[]" ] && phealth=90
    [ "$pfiles" -eq 0 ] && phealth=20

    pgitstatus="clean"
    pgitdetail=""
    if [ "$pcommits" != "[]" ]; then
      pgitstatus="ahead"
      pgitdetail=$(echo "$pcommits" | sed 's/\[//;s/\]//;s/"//g' | head -c 40)
    fi

    echo "{\"id\":\"$(jstr_arg "$dom")\",\"name\":\"$(jstr_arg "$dom")\",\"status\":\"${pstatus}\",\"files\":${pfiles},\"newestFile\":\"$(jstr_arg "$pnewest")\",\"branch\":\"main\",\"gitStatus\":\"${pgitstatus}\",\"gitDetail\":\"$(jstr_arg "$pgitdetail")\",\"health\":${phealth},\"note\":\"$(jstr_arg "$pnote")\"}"
  done < "$TMPDIR_RETRO/project_blocks.txt" > "$TMPDIR_RETRO/projects_raw.txt"

  proj_arr=""
  while IFS= read -r pjson; do
    [ -z "$pjson" ] && continue
    [ -n "$proj_arr" ] && proj_arr="$proj_arr,"
    proj_arr="${proj_arr}${pjson}"
  done < "$TMPDIR_RETRO/projects_raw.txt"

  [ -n "$proj_arr" ] && PROJECTS_JSON="[$proj_arr]"
fi

# ─── Parse process memory (lessons with adoption tracking) ────────────

LESSONS_JSON="[]"
LESSONS_ADOPTION="{}"

if [ -f "$PROCESS_MEM" ]; then
  local_lessons=""
  in_seeds=0
  lesson_count=0

  # First pass: collect all seeds
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^##[[:space:]]+(.+)$ ]]; then
      header="${BASH_REMATCH[1]}"
      if [[ "$header" == *"seed"* || "$header" == *"Seed"* || "$header" == *"Seeded"* ]]; then
        in_seeds=1
      else
        in_seeds=0
      fi
      continue
    fi

    if [[ $in_seeds -eq 1 && "$line" =~ ^-[[:space:]]+(.+)$ ]]; then
      text="${BASH_REMATCH[1]}"
      tag="process"
      status="observing"
      [[ "$text" =~ [Pp]romote ]] && status="promoted"
      [[ "$text" =~ [Cc]ron ]] && tag="process"
      [[ "$text" =~ [Ss]ub-agent ]] && tag="technical"
      [[ "$text" =~ [Ss]cope|[Tt]ask ]] && tag="process"
      [[ "$text" =~ [Rr]etrieval|[Pp]arser ]] && tag="technical"
      [[ "$text" =~ [Qq][Aa] ]] && tag="process"

      lesson_count=$((lesson_count + 1))
      [ -n "$local_lessons" ] && local_lessons="$local_lessons,"
      local_lessons="${local_lessons}{\"id\":${lesson_count},\"date\":\"${TODAY}\",\"text\":\"$(jstr_arg "$text")\",\"tag\":\"${tag}\",\"status\":\"${status}\",\"adopted\":false,\"mentionedAgainDate\":null}"
    fi
  done < "$PROCESS_MEM"

  # Second pass: check retro lessons for adoption (mentioned in multiple dates)
  retro_lessons_file="$TMPDIR_RETRO/all_retro_lessons.txt"
  > "$retro_lessons_file"
  for datedir in "$TMPDIR_RETRO"/*/; do
    [ ! -d "$datedir" ] && continue
    date=$(basename "$datedir")
    [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue
    [ ! -f "$datedir/lessons.txt" ] && continue
    while IFS='|' read -r rtag rstatus rtext; do
      [ -z "$rtext" ] && continue
      echo "${date}|${rtag}|${rstatus}|${rtext}" >> "$retro_lessons_file"
    done < "$datedir/lessons.txt"
  done

  # Check for cross-date mentions (adoption)
  if [ -f "$retro_lessons_file" ] && [ -s "$retro_lessons_file" ]; then
    # Track which lesson texts appear in multiple dates
    while IFS= read -r rline; do
      [ -z "$rline" ] && continue
      echo "$rline" >> "$TMPDIR_RETRO/retro_lesson_lines.txt"
    done < "$retro_lessons_file"
  fi

  [ -n "$local_lessons" ] && LESSONS_JSON="[$local_lessons]"
fi

# ─── Phase 2: Feedback Feed ───────────────────────────────────────────

FEEDBACK_JSON="[]"

# Collect feedback from retro per-agent notes
fb_arr=""
fb_id=0
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue
  [ ! -f "$datedir/feedback.txt" ] && continue

  while IFS='|' read -r from_agent text; do
    [ -z "$from_agent" ] && [ -z "$text" ] && continue
    fb_id=$((fb_id + 1))
    # Determine type based on content
    fb_type="coaching"
    [[ "$text" =~ [Gg]ood|[Ww]ell|[Gg]reat ]] && fb_type="praise"
    [[ "$text" =~ [Bb]ut|[Hh]owever|[Gg]ap|[Nn]eed ]] && fb_type="coaching"
    [[ "$text" =~ [Vv]iolat|[Bb]roke|[Ff]ail|[Mm]iss ]] && fb_type="correction"

    [ -n "$fb_arr" ] && fb_arr="$fb_arr,"
    fb_arr="${fb_arr}{\"id\":${fb_id},\"date\":\"${date}\",\"from\":\"Coach\",\"to\":\"${from_agent}\",\"text\":\"${text}\",\"type\":\"${fb_type}\"}"
  done < "$datedir/feedback.txt"
done

# Also add feedback from process memory feedback section
if [ -f "$PROC_FB_DIR/feedback.txt" ] && [ -s "$PROC_FB_DIR/feedback.txt" ]; then
  while IFS= read -r fb_line; do
    [ -z "$fb_line" ] && continue
    fb_id=$((fb_id + 1))
    [ -n "$fb_arr" ] && fb_arr="$fb_arr,"
    fb_arr="${fb_arr}{\"id\":${fb_id},\"date\":\"${TODAY}\",\"from\":\"process\",\"to\":\"team\",\"text\":\"${fb_line}\",\"type\":\"coaching\"}"
  done < "$PROC_FB_DIR/feedback.txt"
fi

[ -n "$fb_arr" ] && FEEDBACK_JSON="[$fb_arr]"

# ─── Phase 2: Feedback Matrix ─────────────────────────────────────────

FEEDBACK_MATRIX_JSON="{}"

# Build matrix from feedback feed
fb_matrix=""
for agent in $CORE_AGENTS; do
  row=""
  for target in $CORE_AGENTS; do
    count=0
    if [ -n "$fb_arr" ]; then
      # Count occurrences where from=agent and to=target (case insensitive)
      count=$(echo "$fb_arr" | grep -oi "\"from\":\"[^\"]*${agent}[^\"]*\",\"to\":\"[^\"]*${target}[^\"]*\"" | wc -l | tr -d ' ' || true)
      [ -z "$count" ] && count=0
    fi
    [ -n "$row" ] && row="$row,"
    row="${row}\"${target}\":${count}"
  done
  [ -n "$fb_matrix" ] && fb_matrix="$fb_matrix,"
  fb_matrix="${fb_matrix}\"${agent}\":{${row}}"
done

[ -n "$fb_matrix" ] && FEEDBACK_MATRIX_JSON="{$fb_matrix}"

# ─── Compute scoreboard ───────────────────────────────────────────────

TODAY_DONE=0
TODAY_BLOCKED=0
TODAY_ACTIVE=0
if [ -f "$TMPDIR_RETRO/$TODAY/done.txt" ]; then
  TODAY_DONE=$(cat "$TMPDIR_RETRO/$TODAY/done.txt")
fi
if [ -f "$TMPDIR_RETRO/$TODAY/blocked.txt" ]; then
  TODAY_BLOCKED=$(cat "$TMPDIR_RETRO/$TODAY/blocked.txt")
fi
if [ -f "$TMPDIR_RETRO/$TODAY/active.txt" ]; then
  TODAY_ACTIVE=$(cat "$TMPDIR_RETRO/$TODAY/active.txt")
fi

PREV_DATE=$(date -v-1d +%Y-%m-%d 2>/dev/null || echo "")
PREV_DONE=0
PREV_BLOCKED=0
if [ -n "$PREV_DATE" ] && [ -f "$TMPDIR_RETRO/$PREV_DATE/done.txt" ]; then
  PREV_DONE=$(cat "$TMPDIR_RETRO/$PREV_DATE/done.txt")
fi
if [ -n "$PREV_DATE" ] && [ -f "$TMPDIR_RETRO/$PREV_DATE/blocked.txt" ]; then
  PREV_BLOCKED=$(cat "$TMPDIR_RETRO/$PREV_DATE/blocked.txt")
fi

# Count action items across all retros with new fields
TOTAL_PENDING=0
TOTAL_RESOLVED=0
TOTAL_CARRIED=0
OVERDUE_COUNT=0

for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -f "$datedir/actions.txt" ] && continue
  while IFS= read -r ajson; do
    [ -z "$ajson" ] && continue
    if echo "$ajson" | grep -q '"status":"pending"'; then
      TOTAL_PENDING=$((TOTAL_PENDING + 1))
      if echo "$ajson" | grep -q '"carried":true'; then
        TOTAL_CARRIED=$((TOTAL_CARRIED + 1))
      fi
    elif echo "$ajson" | grep -q '"status":"done"'; then
      TOTAL_RESOLVED=$((TOTAL_RESOLVED + 1))
    fi
  done < "$datedir/actions.txt"
done

ACTIVE_AGENTS_JSON="[]"
if [ "$TODAY_ACTIVE" -gt 0 ]; then
  ACTIVE_AGENTS_JSON="[\"coach\",\"lebron\",\"bronny\",\"curry\"]"
fi

# ─── Phase 1: Compute agent status badges ─────────────────────────────

# For each agent, determine status based on retro mentions
compute_agent_status() {
  local agent_id="$1"
  local retro_date="$2"

  local status="idle"
  local detail=""
  local idle_days=0
  local last_active=""

  # Check retro files from newest to oldest
  for i in $(seq 0 6); do
    local check_date=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || echo "")
    [ -z "$check_date" ] && continue
    [ ! -d "$TMPDIR_RETRO/$check_date" ] && continue

    local found=0
    local found_in_section=""

    # Check if agent mentioned in notes (active today)
    if [ -f "$TMPDIR_RETRO/$check_date/notes.txt" ] && [ -s "$TMPDIR_RETRO/$check_date/notes.txt" ]; then
      if grep -qi "${agent_id}" "$TMPDIR_RETRO/$check_date/notes.txt"; then
        found=1
        found_in_section="notes"
      fi
    fi

    # Check if agent mentioned in wins
    if [ -f "$TMPDIR_RETRO/$check_date/wins.txt" ] && [ -s "$TMPDIR_RETRO/$check_date/wins.txt" ]; then
      if grep -qi "${agent_id}" "$TMPDIR_RETRO/$check_date/wins.txt"; then
        found=1
        found_in_section="wins"
      fi
    fi

    # Check if agent mentioned in problems
    if [ -f "$TMPDIR_RETRO/$check_date/problems.txt" ] && [ -s "$TMPDIR_RETRO/$check_date/problems.txt" ]; then
      if grep -qi "${agent_id}" "$TMPDIR_RETRO/$check_date/problems.txt"; then
        found=1
        found_in_section="problems"
      fi
    fi

    # Check if agent mentioned in action items as owner
    if [ -f "$TMPDIR_RETRO/$check_date/actions.txt" ] && [ -s "$TMPDIR_RETRO/$check_date/actions.txt" ]; then
      if grep -qi "\"owner\":\"[^\"]*${agent_id}[^\"]*\"" "$TMPDIR_RETRO/$check_date/actions.txt"; then
        found=1
        found_in_section="actions"
      fi
    fi

    if [ "$found" -eq 1 ]; then
      last_active="$check_date"
      idle_days=$i
      case "$found_in_section" in
        wins|notes) status="working" ;;
        problems) status="reviewing" ;;
        actions) status="waiting" ;;
        *) status="working" ;;
      esac
      # Get detail from notes
      if [ -f "$TMPDIR_RETRO/$check_date/notes.txt" ] && [ -s "$TMPDIR_RETRO/$check_date/notes.txt" ]; then
        detail=$(grep -i "${agent_id}" "$TMPDIR_RETRO/$check_date/notes.txt" | head -1 | sed 's/^[^|]*|//')
      fi
      if [ -z "$detail" ] && [ -f "$TMPDIR_RETRO/$check_date/in_progress.txt" ] && [ -s "$TMPDIR_RETRO/$check_date/in_progress.txt" ]; then
        detail=$(head -1 "$TMPDIR_RETRO/$check_date/in_progress.txt")
      fi
      [ -z "$detail" ] && detail="Active in retro ${check_date}"
      break
    fi

    idle_days=$((i + 1))
  done

  echo "${status}|${detail}|${idle_days}|${last_active}"
}

# ─── Phase 1: Active Tasks ────────────────────────────────────────────

ACTIVE_TASKS_JSON="[]"

at_arr=""
at_id=0
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

  # Parse in-progress items
  if [ -f "$datedir/in_progress.txt" ] && [ -s "$datedir/in_progress.txt" ]; then
    while IFS= read -r task_line; do
      [ -z "$task_line" ] && continue
      at_id=$((at_id + 1))
      # Try to infer agent from task content
      local_task_agent="team"
      echo "$task_line" | grep -qi "backend\|API\|server\|code" && local_task_agent="lebron"
      echo "$task_line" | grep -qi "frontend\|UI\|dashboard\|HTML\|CSS\|component" && local_task_agent="bronny"
      echo "$task_line" | grep -qi "QA\|test\|validation\|review" && local_task_agent="curry"
      echo "$task_line" | grep -qi "coach\|scope\|task card\|audit" && local_task_agent="coach"
      echo "$task_line" | grep -qi "CEO\|cron\|OAuth" && local_task_agent="minisama"

      [ -n "$at_arr" ] && at_arr="$at_arr,"
      at_arr="${at_arr}{\"id\":${at_id},\"task\":\"$(jstr_arg "$task_line")\",\"agent\":\"${local_task_agent}\",\"startedAt\":\"${date}\",\"status\":\"in-progress\"}"
    done < "$datedir/in_progress.txt"
  fi

  # Parse next items
  if [ -f "$datedir/next.txt" ] && [ -s "$datedir/next.txt" ]; then
    while IFS= read -r task_line; do
      [ -z "$task_line" ] && continue
      at_id=$((at_id + 1))
      [ -n "$at_arr" ] && at_arr="$at_arr,"
      at_arr="${at_arr}{\"id\":${at_id},\"task\":\"$(jstr_arg "$task_line")\",\"agent\":\"team\",\"startedAt\":\"${date}\",\"status\":\"planned\"}"
    done < "$datedir/next.txt"
  fi
done

[ -n "$at_arr" ] && ACTIVE_TASKS_JSON="[$at_arr]"

# ─── Phase 1: Trend Annotations ───────────────────────────────────────

TREND_ANNOTATIONS_JSON="[]"
ta_arr=""
ta_id=0

for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

  d_short=$(epoch_to_short_date "$date")

  # Extract notable events from wins (first win of each day = notable)
  if [ -f "$datedir/wins.txt" ] && [ -s "$datedir/wins.txt" ]; then
    first_win=$(head -1 "$datedir/wins.txt")
    [ -n "$first_win" ] && {
      ta_id=$((ta_id + 1))
      # Truncate long labels
      label=$(echo "$first_win" | head -c 60)
      [ -n "$ta_arr" ] && ta_arr="$ta_arr,"
      ta_arr="${ta_arr}{\"id\":${ta_id},\"date\":\"${d_short}\",\"label\":\"$(jstr_arg "$label")\",\"type\":\"win\"}"
    }
  fi

  # Also note if this is a setup day (0 tasks but has problems/wins about setup)
  local_day_done=$(cat "$datedir/done.txt" 2>/dev/null || echo 0)
  if [ "$local_day_done" -eq 0 ] && [ -s "$datedir/wins.txt" ]; then
    if grep -qi "setup\|config\|infrastructure\|cron\|template" "$datedir/wins.txt"; then
      ta_id=$((ta_id + 1))
      [ -n "$ta_arr" ] && ta_arr="$ta_arr,"
      ta_arr="${ta_arr}{\"id\":${ta_id},\"date\":\"${d_short}\",\"label\":\"Setup/infrastructure day\",\"type\":\"setup\"}"
    fi
  fi
done

[ -n "$ta_arr" ] && TREND_ANNOTATIONS_JSON="[$ta_arr]"

# ─── Phase 2: Resolution SLA ─────────────────────────────────────────

RESOLUTION_SLA_JSON='{"resolved24h":0,"resolved48h":0,"resolved1w":0,"open":0,"overdue":0}'

sla_r24=0
sla_r48=0
sla_r1w=0
sla_open=0
sla_overdue=0

# Collect latest version of each action item (by id) to avoid double counting
# For simplicity, iterate all and count by age
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -f "$datedir/actions.txt" ] && continue
  while IFS= read -r ajson; do
    [ -z "$ajson" ] && continue
    local_a_status=$(echo "$ajson" | grep -o '"status":"[^"]*"' | head -1 | sed 's/"status":"//;s/"//')
    local_a_age=$(echo "$ajson" | grep -o '"ageDays":[0-9]*' | head -1 | sed 's/"ageDays"://')

    if [ "$local_a_status" = "done" ]; then
      if [ "$local_a_age" -le 1 ]; then
        sla_r24=$((sla_r24 + 1))
      elif [ "$local_a_age" -le 2 ]; then
        sla_r48=$((sla_r48 + 1))
      else
        sla_r1w=$((sla_r1w + 1))
      fi
    elif [ "$local_a_status" = "pending" ]; then
      sla_open=$((sla_open + 1))
      if [ "$local_a_age" -gt 3 ]; then
        sla_overdue=$((sla_overdue + 1))
      fi
    fi
  done < "$datedir/actions.txt"
done

RESOLUTION_SLA_JSON="{\"resolved24h\":${sla_r24},\"resolved48h\":${sla_r48},\"resolved1w\":${sla_r1w},\"open\":${sla_open},\"overdue\":${sla_overdue}}"

# ─── Phase 2: Cost Metrics (structure only, real data unavailable) ────

COST_METRICS_JSON=""
cm_agents=""
tasks_completed_total=0
for agent in $CORE_AGENTS; do
  a_tasks=0
  # Count tasks completed (done actions where agent is owner)
  for datedir in "$TMPDIR_RETRO"/*/; do
    [ ! -f "$datedir/actions.txt" ] && continue
    while IFS= read -r ajson; do
      [ -z "$ajson" ] && continue
      if echo "$ajson" | grep -q '"status":"done"' && echo "$ajson" | grep -qi "\"owner\":\"[^\"]*${agent}[^\"]*\""; then
        a_tasks=$((a_tasks + 1))
      fi
    done < "$datedir/actions.txt"
  done
  tasks_completed_total=$((tasks_completed_total + a_tasks))
  [ -n "$cm_agents" ] && cm_agents="$cm_agents,"
  cm_agents="${cm_agents}\"${agent}\":{\"tokens\":0,\"tasks\":${a_tasks}}"
done

cost_per_task=0
[ "$tasks_completed_total" -gt 0 ] && cost_per_task=0  # placeholder

COST_METRICS_JSON="\"totalTokensToday\":0,\"tasksCompleted\":${tasks_completed_total},\"costPerTask\":${cost_per_task},\"agentCosts\":{${cm_agents}}"

# ─── Phase 2: Weekly Insight ─────────────────────────────────────────

WEEKLY_INSIGHT=""

# Compute velocity trend
vel_today=$TODAY_DONE
vel_yesterday=$PREV_DONE
vel_change=$((vel_today - vel_yesterday))

idle_agents=0
for agent in $CORE_AGENTS; do
  agent_status=$(compute_agent_status "$agent" "$TODAY")
  a_status=$(echo "$agent_status" | cut -d'|' -f1)
  [ "$a_status" = "idle" ] && idle_agents=$((idle_agents + 1))
done

insight_parts=""

if [ "$vel_change" -lt 0 ]; then
  insight_parts="Velocity giảm $((vel_change * -1)) tasks so với hôm qua."
elif [ "$vel_change" -gt 0 ]; then
  insight_parts="Velocity tăng ${vel_change} tasks so với hôm qua."
fi

if [ "$sla_overdue" -gt 0 ]; then
  [ -n "$insight_parts" ] && insight_parts="${insight_parts} "
  insight_parts="${insight_parts}${sla_overdue} action items quá hạn chưa resolve."
fi

if [ "$TOTAL_CARRIED" -gt 0 ]; then
  [ -n "$insight_parts" ] && insight_parts="${insight_parts} "
  insight_parts="${insight_parts}${TOTAL_CARRIED} items carried từ ngày trước."
fi

if [ "$idle_agents" -gt 0 ]; then
  [ -n "$insight_parts" ] && insight_parts="${insight_parts} "
  insight_parts="${insight_parts}${idle_agents}/4 core agents đang idle."
fi

if [ -z "$insight_parts" ]; then
  insight_parts="Team hoạt động bình thường. Không có alert đáng chú ý."
fi

WEEKLY_INSIGHT="$insight_parts"

# ─── Phase 3: Retro Quality Scores ───────────────────────────────────

RETRO_QUALITY_JSON="{}"

rq_arr=""
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

  has_wins=$(cat "$datedir/has_wins.txt" 2>/dev/null || echo "false")
  has_problems=$(cat "$datedir/has_problems.txt" 2>/dev/null || echo "false")
  has_rc=$(cat "$datedir/has_root_causes.txt" 2>/dev/null || echo "false")
  has_ai=$(cat "$datedir/has_action_items.txt" 2>/dev/null || echo "false")

  score=0
  [ "$has_wins" = "true" ] && score=$((score + 25))
  [ "$has_problems" = "true" ] && score=$((score + 25))
  [ "$has_rc" = "true" ] && score=$((score + 25))
  [ "$has_ai" = "true" ] && score=$((score + 25))

  label="empty"
  case "$score" in
    100) label="perfect" ;;
    75)  label="good" ;;
    50)  label="partial" ;;
    25)  label="minimal" ;;
    0)   label="empty" ;;
  esac

  [ -n "$rq_arr" ] && rq_arr="$rq_arr,"
  rq_arr="${rq_arr}\"${date}\":{\"hasWins\":${has_wins},\"hasProblems\":${has_problems},\"hasRootCauses\":${has_rc},\"hasActionItems\":${has_ai},\"score\":${score},\"label\":\"${label}\"}"
done

[ -n "$rq_arr" ] && RETRO_QUALITY_JSON="{$rq_arr}"

# ─── Phase 3: Health Scores ───────────────────────────────────────────

HEALTH_SCORES_JSON="[]"

hs_arr=""
for agent in $CORE_AGENTS; do
  agent_id="$agent"

  # Tasks component: normalize based on tasks completed
  a_done_count=0
  for datedir in "$TMPDIR_RETRO"/*/; do
    [ ! -f "$datedir/actions.txt" ] && continue
    while IFS= read -r ajson; do
      [ -z "$ajson" ] && continue
      if echo "$ajson" | grep -q '"status":"done"' && echo "$ajson" | grep -qi "\"owner\":\"[^\"]*${agent_id}[^\"]*\""; then
        a_done_count=$((a_done_count + 1))
      fi
    done < "$datedir/actions.txt"
  done
  tasks_score=50
  [ "$a_done_count" -gt 0 ] && tasks_score=80
  [ "$a_done_count" -gt 2 ] && tasks_score=100

  # Quality: 100 if no problems mention this agent
  quality_score=100
  for datedir in "$TMPDIR_RETRO"/*/; do
    [ ! -f "$datedir/problems.txt" ] && continue
    if grep -qi "${agent_id}" "$datedir/problems.txt" 2>/dev/null; then
      quality_score=60
      break
    fi
  done

  # Feedback response: 100 if agent has notes/feedback in recent retros
  fb_response=50
  if [ -f "$TMPDIR_RETRO/$TODAY/notes.txt" ] && grep -qi "${agent_id}" "$TMPDIR_RETRO/$TODAY/notes.txt"; then
    fb_response=100
  elif [ -n "$PREV_DATE" ] && [ -f "$TMPDIR_RETRO/$PREV_DATE/notes.txt" ] && grep -qi "${agent_id}" "$TMPDIR_RETRO/$PREV_DATE/notes.txt"; then
    fb_response=80
  fi

  # Lesson adoption: 100 if contributed lessons
  lesson_adopt=50
  for datedir in "$TMPDIR_RETRO"/*/; do
    [ ! -f "$datedir/lessons.txt" ] && continue
    if [ -s "$datedir/lessons.txt" ]; then
      lesson_adopt=80
      break
    fi
  done

  # Overall score: average of 4 components
  overall_score=$(( (tasks_score + quality_score + fb_response + lesson_adopt) / 4 ))

  # Trend: compare with previous day (simplified — use active status)
  trend="stable"
  agent_status_result=$(compute_agent_status "$agent_id" "$TODAY")
  a_status=$(echo "$agent_status_result" | cut -d'|' -f1)
  case "$a_status" in
    working) trend="up" ;;
    reviewing) trend="down" ;;
    idle) trend="down" ;;
    waiting) trend="stable" ;;
  esac

  # Agent display name
  case "$agent_id" in
    coach) a_name="Coach" ;;
    lebron) a_name="Lebron" ;;
    bronny) a_name="Bronny" ;;
    curry) a_name="Curry" ;;
    *) a_name="$agent_id" ;;
  esac

  [ -n "$hs_arr" ] && hs_arr="$hs_arr,"
  hs_arr="${hs_arr}{\"agentId\":\"${agent_id}\",\"name\":\"${a_name}\",\"score\":${overall_score},\"trend\":\"${trend}\",\"components\":{\"tasks\":${tasks_score},\"quality\":${quality_score},\"feedbackResponse\":${fb_response},\"lessonAdoption\":${lesson_adopt}}}"
done

[ -n "$hs_arr" ] && HEALTH_SCORES_JSON="[$hs_arr]"

# ─── Phase 3: Alerts ──────────────────────────────────────────────────

ALERTS_JSON="[]"
al_arr=""
al_id=0

# Check overdue action items
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -f "$datedir/actions.txt" ] && continue
  while IFS= read -r ajson; do
    [ -z "$ajson" ] && continue
    local_a_status=$(echo "$ajson" | grep -o '"status":"[^"]*"' | head -1 | sed 's/"status":"//;s/"//')
    local_a_age=$(echo "$ajson" | grep -o '"ageDays":[0-9]*' | head -1 | sed 's/"ageDays"://')
    local_a_id=$(echo "$ajson" | grep -o '"id":[0-9]*' | head -1 | sed 's/"id"://')
    local_a_action=$(echo "$ajson" | grep -o '"action":"[^"]*"' | head -1 | sed 's/"action":"//;s/"//')
    local_a_owner=$(echo "$ajson" | grep -o '"owner":"[^"]*"' | head -1 | sed 's/"owner":"//;s/"//')

    if [ "$local_a_status" = "pending" ]; then
      if [ "$local_a_age" -gt 7 ]; then
        al_id=$((al_id + 1))
        [ -n "$al_arr" ] && al_arr="$al_arr,"
        al_arr="${al_arr}{\"id\":${al_id},\"severity\":\"critical\",\"type\":\"overdue_item\",\"message\":\"Action item #${local_a_id} quá ${local_a_age} ngày chưa resolve\",\"agent\":\"${local_a_owner}\"}"
      elif [ "$local_a_age" -gt 3 ]; then
        al_id=$((al_id + 1))
        [ -n "$al_arr" ] && al_arr="$al_arr,"
        al_arr="${al_arr}{\"id\":${al_id},\"severity\":\"warning\",\"type\":\"overdue_item\",\"message\":\"Action item #${local_a_id} quá ${local_a_age} ngày chưa resolve\",\"agent\":\"${local_a_owner}\"}"
      fi
    fi
  done < "$datedir/actions.txt"
done

# Check idle agents
for agent in $CORE_AGENTS; do
  agent_status_result=$(compute_agent_status "$agent" "$TODAY")
  a_status=$(echo "$agent_status_result" | cut -d'|' -f1)
  a_idle=$(echo "$agent_status_result" | cut -d'|' -f3)

  if [ "$a_idle" -gt 2 ]; then
    al_id=$((al_id + 1))
    a_display=$(echo "$agent" | sed 's/.*/\u&/')
    [ -n "$al_arr" ] && al_arr="$al_arr,"
    al_arr="${al_arr}{\"id\":${al_id},\"severity\":\"warning\",\"type\":\"idle_agent\",\"message\":\"${a_display} idle ${a_idle} ngày liên tiếp\",\"agent\":\"${a_display}\"}"
  fi
done

# Check incomplete retros
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

  has_ai=$(cat "$datedir/has_action_items.txt" 2>/dev/null || echo "false")
  if [ "$has_ai" = "false" ]; then
    al_id=$((al_id + 1))
    [ -n "$al_arr" ] && al_arr="$al_arr,"
    al_arr="${al_arr}{\"id\":${al_id},\"severity\":\"warning\",\"type\":\"incomplete_retro\",\"message\":\"Retro ${date} thiếu action items\",\"agent\":\"team\"}"
  fi
done

[ -n "$al_arr" ] && ALERTS_JSON="[$al_arr]"

# ─── Phase 3: Improvement Velocity ────────────────────────────────────

IMPROVEMENT_VELOCITY_JSON="{\"weeklyData\":[]}"

iv_arr=""

# Use temp files instead of associative arrays (bash3 compatible)
WEEK_DATA_DIR="$TMPDIR_RETRO/week_data"
mkdir -p "$WEEK_DATA_DIR"

# Count from retro lessons
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

  week=$(iso_week "$date")
  [ "$week" = "W00" ] && continue

  # Initialize week counts if not exist
  [ ! -f "$WEEK_DATA_DIR/${week}_obs" ] && echo "0" > "$WEEK_DATA_DIR/${week}_obs"
  [ ! -f "$WEEK_DATA_DIR/${week}_prom" ] && echo "0" > "$WEEK_DATA_DIR/${week}_prom"
  [ ! -f "$WEEK_DATA_DIR/${week}_fb" ] && echo "0" > "$WEEK_DATA_DIR/${week}_fb"

  if [ -f "$datedir/lessons.txt" ] && [ -s "$datedir/lessons.txt" ]; then
    while IFS='|' read -r ltag lstatus ltext; do
      [ -z "$ltext" ] && continue
      if [ "$lstatus" = "promoted" ]; then
        cur=$(cat "$WEEK_DATA_DIR/${week}_prom")
        echo $((cur + 1)) > "$WEEK_DATA_DIR/${week}_prom"
      else
        cur=$(cat "$WEEK_DATA_DIR/${week}_obs")
        echo $((cur + 1)) > "$WEEK_DATA_DIR/${week}_obs"
      fi
    done < "$datedir/lessons.txt"
  fi

  # Count feedback items per week
  if [ -f "$datedir/feedback.txt" ] && [ -s "$datedir/feedback.txt" ]; then
    fb_count=$(wc -l < "$datedir/feedback.txt" | tr -d ' ')
    cur=$(cat "$WEEK_DATA_DIR/${week}_fb")
    echo $((cur + fb_count)) > "$WEEK_DATA_DIR/${week}_fb"
  fi
done

# Build weekly data (unique weeks)
for wf in "$WEEK_DATA_DIR"/*_obs; do
  [ ! -f "$wf" ] && continue
  week=$(basename "$wf" _obs)
  w_obs=$(cat "$WEEK_DATA_DIR/${week}_obs")
  w_prom=$(cat "$WEEK_DATA_DIR/${week}_prom")
  w_fb=$(cat "$WEEK_DATA_DIR/${week}_fb")

  [ -n "$iv_arr" ] && iv_arr="$iv_arr,"
  iv_arr="${iv_arr}{\"week\":\"${week}\",\"lessonsObserved\":${w_obs},\"lessonsPromoted\":${w_prom},\"rulesAdded\":${w_prom},\"feedbackClosed\":${w_fb}}"
done

[ -n "$iv_arr" ] && IMPROVEMENT_VELOCITY_JSON="{\"weeklyData\":[${iv_arr}]}"

# ─── Build agents array (with Phase 1 status badges) ──────────────────

AGENTS_JSON=""
echo "$AGENT_MAP" | grep '|' | while IFS='|' read -r folder id name role emoji color; do
  [ -z "$id" ] && continue

  # Tasks 7d (distribute total across core team)
  total_tasks=0
  for datedir in "$TMPDIR_RETRO"/*/; do
    [ ! -f "$datedir/done.txt" ] && continue
    d=$(cat "$datedir/done.txt")
    total_tasks=$((total_tasks + d))
  done

  tasks_7d=0
  case "$id" in
    coach|lebron|bronny|curry) tasks_7d=$((total_tasks / 4)) ;;
  esac

  # Health (number 0-100 for bar)
  health_num=50
  if [ "$TODAY_ACTIVE" -gt 0 ] && [ "$TODAY_DONE" -gt 0 ]; then
    health_num=80
  elif [ "$TODAY_BLOCKED" -gt 0 ]; then
    health_num=30
  fi

  # Phase 1: Status badge
  status="idle"
  [ -f "$TMPDIR_RETRO/$TODAY/notes.txt" ] && [ -s "$TMPDIR_RETRO/$TODAY/notes.txt" ] && status="active"
  [ "$TODAY_ACTIVE" -gt 0 ] && status="active"

  # Phase 1: Compute enhanced status
  status_result=$(compute_agent_status "$id" "$TODAY")
  status_badge=$(echo "$status_result" | cut -d'|' -f1)
  status_detail=$(echo "$status_result" | cut -d'|' -f2)
  idle_days=$(echo "$status_result" | cut -d'|' -f3)
  last_active=$(echo "$status_result" | cut -d'|' -f4)
  [ -z "$last_active" ] && last_active="$TODAY"

  # Role-specific metrics
  metric1_label=""
  metric1_val=""
  metric2_label=""
  metric2_val=""
  bar_pct=""
  health_label="Health"
  main_value=""
  main_label=""

  case "$id" in
    coach)
      metric1_label="Tasks handled"
      metric1_val="${tasks_7d}"
      metric2_label="Action items"
      metric2_val="${TOTAL_PENDING}"
      bar_pct=${health_num}
      health_label="Tasks/week"
      ;;
    lebron)
      metric1_label="Tasks shipped"
      metric1_val="${tasks_7d}"
      metric2_label="Lessons"
      metric2_val="0"
      bar_pct=${health_num}
      health_label="Tasks/week"
      ;;
    bronny)
      metric1_label="Tasks shipped"
      metric1_val="${tasks_7d}"
      metric2_label="Components"
      metric2_val="0"
      bar_pct=${health_num}
      health_label="Tasks/week"
      ;;
    curry)
      metric1_label="Tasks reviewed"
      metric1_val="${tasks_7d}"
      metric2_label="Issues found"
      metric2_val="0"
      bar_pct=${health_num}
      health_label="Tasks/week"
      ;;
    tuvi)
      main_value="Domain"
      main_label="Specialist"
      ;;
    laoshi)
      main_value="Mandarin"
      main_label="Teacher"
      ;;
    minisama)
      main_value="CEO"
      main_label="Operations"
      ;;
  esac

  echo "{\"id\":\"${id}\",\"name\":\"${name}\",\"role\":\"${role}\",\"emoji\":\"${emoji}\",\"color\":\"${color}\",\"status\":\"${status}\",\"health\":${health_num},\"healthLabel\":\"${health_label}\",\"metric1Label\":\"${metric1_label}\",\"metric1\":${metric1_val:-0},\"metric2Label\":\"${metric2_label}\",\"metric2\":${metric2_val:-0},\"barPct\":${bar_pct:-0},\"mainValue\":\"${main_value}\",\"mainLabel\":\"${main_label}\",\"statusBadge\":\"${status_badge}\",\"statusDetail\":\"$(jstr_arg "$status_detail")\",\"idleDays\":${idle_days},\"lastActiveDate\":\"${last_active}\"}"
done > "$TMPDIR_RETRO/agents_raw.txt"

AGENTS_JSON=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  [ -n "$AGENTS_JSON" ] && AGENTS_JSON="$AGENTS_JSON,"
  AGENTS_JSON="${AGENTS_JSON}${line}"
done < "$TMPDIR_RETRO/agents_raw.txt"

# ─── Build retros object (with enhanced action items) ─────────────────

RETROS_JSON=""
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

  local_done=$(cat "$datedir/done.txt" 2>/dev/null || echo 0)
  local_blocked=$(cat "$datedir/blocked.txt" 2>/dev/null || echo 0)
  local_active=$(cat "$datedir/active.txt" 2>/dev/null || echo 0)

  # Wins array
  local_wins_json="[]"
  if [ -s "$datedir/wins.txt" ]; then
    w=""
    while IFS= read -r wline; do
      [ -z "$wline" ] && continue
      [ -n "$w" ] && w="$w,"
      w="${w}\"$(jstr_arg "$wline")\""
    done < "$datedir/wins.txt"
    [ -n "$w" ] && local_wins_json="[$w]"
  fi

  # Problems array
  local_problems_json="[]"
  if [ -s "$datedir/problems.txt" ]; then
    p=""
    while IFS= read -r pline; do
      [ -z "$pline" ] && continue
      [ -n "$p" ] && p="$p,"
      p="${p}\"$(jstr_arg "$pline")\""
    done < "$datedir/problems.txt"
    [ -n "$p" ] && local_problems_json="[$p]"
  fi

  # Actions array (with new fields: priority, ageDays)
  local_actions_json="[]"
  if [ -s "$datedir/actions.txt" ]; then
    a=""
    while IFS= read -r aline; do
      [ -z "$aline" ] && continue
      [ -n "$a" ] && a="$a,"
      a="${a}${aline}"
    done < "$datedir/actions.txt"
    [ -n "$a" ] && local_actions_json="[$a]"
  fi

  # Agent notes object
  local_notes_json="{}"
  if [ -s "$datedir/notes.txt" ]; then
    n=""
    while IFS='|' read -r nkey nval; do
      [ -z "$nkey" ] && continue
      [ -n "$n" ] && n="$n,"
      n="${n}\"${nkey}\":\"${nval}\""
    done < "$datedir/notes.txt"
    [ -n "$n" ] && local_notes_json="{$n}"
  fi

  [ -n "$RETROS_JSON" ] && RETROS_JSON="$RETROS_JSON,"
  RETROS_JSON="${RETROS_JSON}\"${date}\":{\"summary\":{\"tasksCompleted\":${local_done},\"tasksBlocked\":${local_blocked},\"activeAgents\":${local_active}},\"wins\":${local_wins_json},\"problems\":${local_problems_json},\"actionItems\":${local_actions_json},\"agentNotes\":${local_notes_json}}"
done

# ─── Build trends (7-day window) ──────────────────────────────────────

TRENDS_DATES=""
TRENDS_VELOCITY=""
TRENDS_BLOCKED=""

for i in $(seq 0 6); do
  d=$(date -v-${i}d +%Y-%m-%d 2>/dev/null || echo "")
  [ -z "$d" ] && continue
  d_short=$(echo "$d" | sed 's/^[0-9]\{4\}-//')

  v=0
  b=0
  if [ -f "$TMPDIR_RETRO/$d/done.txt" ]; then
    v=$(cat "$TMPDIR_RETRO/$d/done.txt")
  fi
  if [ -f "$TMPDIR_RETRO/$d/blocked.txt" ]; then
    b=$(cat "$TMPDIR_RETRO/$d/blocked.txt")
  fi

  [ -n "$TRENDS_DATES" ] && TRENDS_DATES="$TRENDS_DATES,"
  TRENDS_DATES="${TRENDS_DATES}\"${d_short}\""
  [ -n "$TRENDS_VELOCITY" ] && TRENDS_VELOCITY="$TRENDS_VELOCITY,"
  TRENDS_VELOCITY="${TRENDS_VELOCITY}${v}"
  [ -n "$TRENDS_BLOCKED" ] && TRENDS_BLOCKED="$TRENDS_BLOCKED,"
  TRENDS_BLOCKED="${TRENDS_BLOCKED}${b}"
done

# ─── Build weekly summary (aggregate from retros) ─────────────────────

WEEKLY_JSON="{}"

WEEKLY_WINS=""
WEEKLY_IMPROVEMENTS=""
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  [[ ! "$date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && continue

  if [ -s "$datedir/wins.txt" ]; then
    while IFS= read -r wline; do
      [ -z "$wline" ] && continue
      [ -n "$WEEKLY_WINS" ] && WEEKLY_WINS="$WEEKLY_WINS,"
      WEEKLY_WINS="${WEEKLY_WINS}\"$(jstr_arg "$wline")\""
    done < "$datedir/wins.txt"
  fi

  if [ -s "$datedir/problems.txt" ]; then
    while IFS= read -r pline; do
      [ -z "$pline" ] && continue
      [ -n "$WEEKLY_IMPROVEMENTS" ] && WEEKLY_IMPROVEMENTS="$WEEKLY_IMPROVEMENTS,"
      WEEKLY_IMPROVEMENTS="${WEEKLY_IMPROVEMENTS}\"$(jstr_arg "$pline")\""
    done < "$datedir/problems.txt"
  fi
done

if [ -n "$WEEKLY_WINS" ] || [ -n "$WEEKLY_IMPROVEMENTS" ]; then
  WEEKLY_JSON="{\"status\":\"Weekly\",\"wins\":[${WEEKLY_WINS}],\"improvements\":[${WEEKLY_IMPROVEMENTS}]}"
fi

# ─── Assemble final JSON ──────────────────────────────────────────────

cat > "$OUTPUT_FILE" << ENDJSON
{
  "meta": {
    "generatedAt": "${NOW}",
    "date": "${TODAY}"
  },
  "scoreboard": {
    "tasksCompleted": ${TODAY_DONE},
    "tasksCompletedTrend": $((TODAY_DONE - PREV_DONE)),
    "tasksBlocked": ${TODAY_BLOCKED},
    "tasksBlockedTrend": $((TODAY_BLOCKED - PREV_BLOCKED)),
    "actionItemsOpen": ${TOTAL_PENDING},
    "actionItemsOpenTrend": 0,
    "activeAgents": ${TODAY_ACTIVE},
    "tokensToday": 0,
    "tokensTrend": 0
  },
  "agents": [${AGENTS_JSON}],
  "projects": ${PROJECTS_JSON},
  "retros": {${RETROS_JSON}},
  "feedback": [],
  "trends": {
    "dates": [${TRENDS_DATES}],
    "velocity": [${TRENDS_VELOCITY}],
    "blocked": [${TRENDS_BLOCKED}],
    "quality": [${TRENDS_BLOCKED}],
    "annotations": ${TREND_ANNOTATIONS_JSON}
  },
  "lessons": ${LESSONS_JSON},
  "weeklySummary": ${WEEKLY_JSON},
  "activeTasks": ${ACTIVE_TASKS_JSON},
  "feedbackFeed": ${FEEDBACK_JSON},
  "feedbackMatrix": ${FEEDBACK_MATRIX_JSON},
  "costMetrics": {${COST_METRICS_JSON}},
  "resolutionSLA": ${RESOLUTION_SLA_JSON},
  "weeklyInsight": "$(jstr_arg "$WEEKLY_INSIGHT")",
  "healthScores": ${HEALTH_SCORES_JSON},
  "alerts": ${ALERTS_JSON},
  "improvementVelocity": ${IMPROVEMENT_VELOCITY_JSON},
  "retroQualityScores": ${RETRO_QUALITY_JSON}
}
ENDJSON

echo "✅ Generated $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | tr -d ' ') bytes)"
