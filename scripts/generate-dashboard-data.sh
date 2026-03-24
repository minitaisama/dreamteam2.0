#!/usr/bin/env bash
# generate-dashboard-data.sh — Parse workspace data → dashboard-data.json
# Pure bash (POSIX/macOS compatible), idempotent
# Uses temp files instead of associative arrays (bash3 compatible)
set -euo pipefail

WORKSPACE="/Users/agent0/.openclaw/workspace"
RETRO_DIR="$WORKSPACE/memory/retro/daily"
PROCESS_MEM="$WORKSPACE/memory/process/dream-team.md"
PROJECT_STATUS_SCRIPT="$WORKSPACE/scripts/project-status.sh"
OUTPUT_DIR="/Users/agent0/Works/dreamteam-by-taisama/public/data"
OUTPUT_FILE="$OUTPUT_DIR/dashboard-data.json"
TMPDIR_RETRO=$(mktemp -d)

TODAY=$(date +%Y-%m-%d)
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

mkdir -p "$OUTPUT_DIR"

trap 'rm -rf "$TMPDIR_RETRO"' EXIT

# ─── Helpers ───────────────────────────────────────────────────────────

jstr() {
  # Escape string for JSON (read from stdin)
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
  # Escape a single argument for JSON
  printf '%s' "$1" | jstr
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
  echo "0" > "$outdir/done.txt"
  echo "0" > "$outdir/blocked.txt"
  echo "0" > "$outdir/active.txt"

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
        # Count comma-separated agent names
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
      fi
    fi

    # Action items table
    if [[ "$section" == *"🎯"* ]]; then
      if [[ "$line" =~ ^\|[[:space:]]*\#[[:space:]]*\|[[:space:]]*Action ]]; then
        in_action_table=1
        continue
      fi
      if [[ "$line" =~ ^\|[-\[:space:]]*\| ]]; then
        # separator line, skip
        continue
      fi
      if [[ "$line" =~ ^\|[[:space:]]*$ ]]; then
        in_action_table=0
        continue
      fi
      if [[ $in_action_table -eq 1 && "$line" =~ ^\|[[:space:]]*([0-9]+)[[:space:]]*\| ]]; then
        # Parse table row using awk — split on |, handle content with | inside cells
        # Table format: | # | Action | Owner | Due | Status |
        # Columns: 0=empty, 1=id, 2=action, 3=owner, 4=due, 5=status, 6=empty
        local a_id="${BASH_REMATCH[1]}"
        local a_action a_owner a_due a_status_raw a_status
        a_action=$(echo "$line" | awk -F'|' '{print $3}' | sed 's/\*\*//g' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_owner=$(echo "$line" | awk -F'|' '{print $4}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_due=$(echo "$line" | awk -F'|' '{print $5}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_status_raw=$(echo "$line" | awk -F'|' '{print $6}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        a_status="pending"
        if [[ "$a_status_raw" == *"✅"* ]]; then
          a_status="done"
        fi
        [ -n "$a_action" ] && echo "{\"id\":${a_id},\"action\":\"$(jstr_arg "$a_action")\",\"owner\":\"$(jstr_arg "$a_owner")\",\"due\":\"$(jstr_arg "$a_due")\",\"status\":\"${a_status}\"}" >> "$outdir/actions.txt"
      fi
    fi

    # Per-Agent Notes (under ## Per-Agent Notes level-2 header)
    if [[ "$parent_section" == *"Per-Agent"* ]]; then
      if [[ "$section" =~ ^(.+?)[[:space:]]*\( ]]; then
        # Header like "Lebron (Backend)" — extract name before parentheses
        local agent_raw="${BASH_REMATCH[1]}"
      else
        local agent_raw="$section"
      fi
      # Simplified agent key mapping
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
    fi
  done < "$file"
}

for f in "$RETRO_DIR"/*.md; do
  [ -f "$f" ] && parse_retro_file "$f"
done

# ─── Parse project status ─────────────────────────────────────────────

PROJECTS_JSON="[]"

if [ -x "$PROJECT_STATUS_SCRIPT" ]; then
  PROJECT_RAW=$(bash "$PROJECT_STATUS_SCRIPT" 2>/dev/null || echo "{}")
  
  proj_arr=""
  
  # Extract each domain block using a simple state machine
  in_block=0
  current_dom=""
  block_content=""
  
  while IFS= read -r char; do
    # Process character by character is too slow; use line-based
    :
  done <<< ""
  
  # Simpler approach: use grep to find domain entries
  # The output looks like: "domain_name":{"status":"...","files":N,...}
  echo "$PROJECT_RAW" | grep -oE '"[^"]+":\{[^}]+\}' > "$TMPDIR_RETRO/project_blocks.txt"
  
  proj_arr=""
  while IFS= read -r block; do
    # Extract domain name
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
    
    # Extract newest filename
    if [[ "$block" =~ \"newest\":([^,}]+) ]]; then
      raw="${BASH_REMATCH[1]}"
      pnewest=$(echo "$raw" | sed 's|.*/||;s/"//g')
      [ -z "$pnewest" ] && pnewest="null"
    fi
    
    # Extract git commits
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
    
    echo "{\"id\":\"$(jstr_arg "$dom")\",\"name\":\"$(jstr_arg "$dom")\",\"status\":\"${pstatus}\",\"files\":${pfiles},\"newest\":\"$(jstr_arg "$pnewest")\",\"recentCommits\":${pcommits},\"note\":\"$(jstr_arg "$pnote")\"}"
  done < "$TMPDIR_RETRO/project_blocks.txt" > "$TMPDIR_RETRO/projects_raw.txt"
  
  # Collect project JSON lines
  proj_arr=""
  while IFS= read -r pjson; do
    [ -z "$pjson" ] && continue
    [ -n "$proj_arr" ] && proj_arr="$proj_arr,"
    proj_arr="${proj_arr}${pjson}"
  done < "$TMPDIR_RETRO/projects_raw.txt"
  
  [ -n "$proj_arr" ] && PROJECTS_JSON="[$proj_arr]"
fi

# ─── Parse process memory (lessons) ───────────────────────────────────

LESSONS_JSON="[]"

if [ -f "$PROCESS_MEM" ]; then
  local_lessons=""
  in_seeds=0
  
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
      
      [ -n "$local_lessons" ] && local_lessons="$local_lessons,"
      local_lessons="${local_lessons}{\"date\":\"${TODAY}\",\"text\":\"$(jstr_arg "$text")\",\"tag\":\"${tag}\",\"status\":\"${status}\"}"
    fi
  done < "$PROCESS_MEM"
  
  [ -n "$local_lessons" ] && LESSONS_JSON="[$local_lessons]"
fi

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

# Count action items across all retros
TOTAL_PENDING=0
TOTAL_RESOLVED=0
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -f "$datedir/actions.txt" ] && continue
  while IFS= read -r ajson; do
    [ -z "$ajson" ] && continue
    if echo "$ajson" | grep -q '"status":"pending"'; then
      TOTAL_PENDING=$((TOTAL_PENDING + 1))
    elif echo "$ajson" | grep -q '"status":"done"'; then
      TOTAL_RESOLVED=$((TOTAL_RESOLVED + 1))
    fi
  done < "$datedir/actions.txt"
done

# Active agents list
ACTIVE_AGENTS_JSON="[]"
if [ "$TODAY_ACTIVE" -gt 0 ]; then
  ACTIVE_AGENTS_JSON="[\"coach\",\"lebron\",\"bronny\",\"curry\"]"
fi

# ─── Build agents array ───────────────────────────────────────────────

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
  
  # Health
  health="yellow"
  if [ "$TODAY_ACTIVE" -gt 0 ] && [ "$TODAY_DONE" -gt 0 ]; then
    health="green"
  elif [ "$TODAY_BLOCKED" -gt 0 ]; then
    health="red"
  fi
  
  # Status note
  status_note="Idle"
  [ -f "$TMPDIR_RETRO/$TODAY/notes.txt" ] && [ -s "$TMPDIR_RETRO/$TODAY/notes.txt" ] && status_note="Active"
  
  echo "{\"id\":\"${id}\",\"name\":\"${name}\",\"role\":\"${role}\",\"emoji\":\"${emoji}\",\"color\":\"${color}\",\"health\":\"${health}\",\"tasks7d\":${tasks_7d},\"statusNote\":\"${status_note}\",\"feedbackReceived\":0,\"lessonsContributed\":0}"
done > "$TMPDIR_RETRO/agents_raw.txt"

AGENTS_JSON=""
while IFS= read -r line; do
  [ -z "$line" ] && continue
  [ -n "$AGENTS_JSON" ] && AGENTS_JSON="$AGENTS_JSON,"
  AGENTS_JSON="${AGENTS_JSON}${line}"
done < "$TMPDIR_RETRO/agents_raw.txt"

# ─── Build retros object ──────────────────────────────────────────────

RETROS_JSON=""
for datedir in "$TMPDIR_RETRO"/*/; do
  [ ! -d "$datedir" ] && continue
  date=$(basename "$datedir")
  # Skip non-date directories
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
  
  # Actions array
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

# ─── Assemble final JSON ──────────────────────────────────────────────

cat > "$OUTPUT_FILE" << ENDJSON
{
  "meta": {
    "generatedAt": "${NOW}",
    "date": "${TODAY}"
  },
  "scoreboard": {
    "tasksDone": ${TODAY_DONE},
    "tasksBlocked": ${TODAY_BLOCKED},
    "actionPending": ${TOTAL_PENDING},
    "actionResolved": ${TOTAL_RESOLVED},
    "activeAgents": ${ACTIVE_AGENTS_JSON},
    "prevDone": ${PREV_DONE},
    "prevBlocked": ${PREV_BLOCKED}
  },
  "agents": [${AGENTS_JSON}],
  "projects": ${PROJECTS_JSON},
  "retros": {${RETROS_JSON}},
  "feedback": [],
  "trends": {
    "dates": [${TRENDS_DATES}],
    "velocity": [${TRENDS_VELOCITY}],
    "blocked": [${TRENDS_BLOCKED}]
  },
  "lessons": ${LESSONS_JSON}
}
ENDJSON

echo "✅ Generated $OUTPUT_FILE ($(wc -c < "$OUTPUT_FILE" | tr -d ' ') bytes)"
