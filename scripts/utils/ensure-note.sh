#!/usr/bin/env bash
# =============================================================================
# ensure-note.sh — Auto-create notes from templates with date placeholders
#                   + task rollover with priority tiers and stale tagging
# =============================================================================
# Called by SessionStart hook and before agent dispatch.
# Creates daily, weekly, monthly, quarterly, and yearly notes if they don't
# already exist, using templates from hub/templates/.
#
# Task rollover: reads the most recent previous daily note, extracts incomplete
# tasks from each priority tier, applies stale tagging, deduplicates, and
# inserts into today's note.
#
# CHANGELOG (max 10):
# 2026-04-08 | daily-notes-upgrade | builder | Added task rollover, stale tagging, nav links, new sections
# 2026-04-07 | morpheus-foundation | builder | Initial creation — Wave 4.6
# =============================================================================

set -euo pipefail

# Resolve base directory (repo root = parent of scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

TEMPLATE_DIR="$BASE_DIR/hub/templates"
NOTES_DIR="$BASE_DIR/notes"

# --- Date computations ---
TODAY=$(date +%Y-%m-%d)
YEAR=$(date +%Y)
MONTH=$(date +%m)
MONTH_NAME=$(date +%B)
DAY_OF_WEEK=$(date +%A)
WEEK_NUM=$(date +%V)
QUARTER=$(( (10#$MONTH - 1) / 3 + 1 ))

# Navigation dates
PREV_DATE=$(date -d "$TODAY -1 day" +%Y-%m-%d 2>/dev/null || date -v-1d +%Y-%m-%d 2>/dev/null || echo "$TODAY")
NEXT_DATE=$(date -d "$TODAY +1 day" +%Y-%m-%d 2>/dev/null || date -v+1d +%Y-%m-%d 2>/dev/null || echo "$TODAY")

# Quarter start/end months
Q_START_MONTH=$(printf "%02d" $(( (QUARTER - 1) * 3 + 1 )))
Q_END_MONTH=$(printf "%02d" $(( QUARTER * 3 )))

# Week boundaries (Monday to Friday of current week)
WEEK_MON=$(date -d "$TODAY -$(( ($(date +%u) - 1) )) days" +%Y-%m-%d 2>/dev/null || echo "$TODAY")
WEEK_FRI=$(date -d "$WEEK_MON +4 days" +%Y-%m-%d 2>/dev/null || echo "$TODAY")

# --- Stale tagging thresholds (days) ---
STALE_14=14
STALE_30=30
STALE_60=60
STALE_90=90

# --- Helper: find most recent previous daily note ---
find_previous_note() {
    local search_date="$TODAY"
    local i=1
    while [[ $i -le 7 ]]; do
        search_date=$(date -d "$search_date -1 day" +%Y-%m-%d 2>/dev/null || date -v-1d -jf "%Y-%m-%d" "$search_date" +%Y-%m-%d 2>/dev/null || break)
        local s_year="${search_date:0:4}"
        local s_month="${search_date:5:2}"
        local candidate="$NOTES_DIR/$s_year/$s_month/$search_date.md"
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
        i=$((i + 1))
    done
    return 1
}

# --- Helper: extract incomplete tasks from a priority section ---
# Usage: extract_tasks "file" "### Section Name"
extract_tasks() {
    local file="$1"
    local section="$2"
    local in_section=0
    local tasks=""

    while IFS= read -r line; do
        if [[ "$line" == "$section"* ]]; then
            in_section=1
            continue
        fi
        if [[ $in_section -eq 1 ]] && [[ "$line" == "###"* || "$line" == "##"* || "$line" == "---" ]]; then
            break
        fi
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*-\ \[\ \] ]]; then
            # Skip blank/empty tasks (just "- [ ] " with nothing after)
            local task_text
            task_text=$(echo "$line" | sed 's/^[[:space:]]*- \[ \][[:space:]]*//')
            if [[ -n "$task_text" ]]; then
                tasks+="$line"$'\n'
            fi
        fi
    done < "$file"

    echo -n "$tasks"
}

# --- Helper: extract unchecked items from a section (for Ideas, Tomorrow's Prep) ---
extract_unchecked_items() {
    local file="$1"
    local section="$2"
    local in_section=0
    local items=""

    while IFS= read -r line; do
        if [[ "$line" == "$section"* ]]; then
            in_section=1
            continue
        fi
        if [[ $in_section -eq 1 ]] && [[ "$line" == "##"* || "$line" == "---" ]]; then
            break
        fi
        if [[ $in_section -eq 1 ]] && [[ "$line" =~ ^[[:space:]]*-\ \[\ \] ]]; then
            local item_text
            item_text=$(echo "$line" | sed 's/^[[:space:]]*- \[ \][[:space:]]*//')
            if [[ -n "$item_text" ]]; then
                items+="$line"$'\n'
            fi
        fi
    done < "$file"

    echo -n "$items"
}

# --- Helper: apply stale tags to a task line ---
apply_stale_tag() {
    local line="$1"
    # Check for existing origin comment
    local origin_date=""
    if [[ "$line" =~ \<!--\ origin:\ ([0-9]{4}-[0-9]{2}-[0-9]{2})\ --\> ]]; then
        origin_date="${BASH_REMATCH[1]}"
    else
        # No origin — this is the first rollover, tag with today's previous note date
        origin_date="$TODAY"
    fi

    # Calculate age in days
    local origin_epoch today_epoch age_days
    origin_epoch=$(date -d "$origin_date" +%s 2>/dev/null || echo 0)
    today_epoch=$(date -d "$TODAY" +%s 2>/dev/null || echo 0)
    if [[ $origin_epoch -eq 0 ]] || [[ $today_epoch -eq 0 ]]; then
        echo "$line"
        return
    fi
    age_days=$(( (today_epoch - origin_epoch) / 86400 ))

    # Strip existing stale markers
    local clean_line
    clean_line=$(echo "$line" | sed 's/ [⏰⚠️🔴💀]//g')

    # Apply appropriate stale tag
    local marker=""
    if [[ $age_days -ge $STALE_90 ]]; then
        marker=" 💀"
    elif [[ $age_days -ge $STALE_60 ]]; then
        marker=" 🔴"
    elif [[ $age_days -ge $STALE_30 ]]; then
        marker=" ⚠️"
    elif [[ $age_days -ge $STALE_14 ]]; then
        marker=" ⏰"
    fi

    # Ensure origin comment exists
    if [[ ! "$clean_line" =~ \<!--\ origin: ]]; then
        clean_line="$clean_line <!-- origin: $origin_date -->"
    fi

    # Insert marker before the origin comment if needed
    if [[ -n "$marker" ]]; then
        clean_line=$(echo "$clean_line" | sed "s/ <!-- origin:/${marker} <!-- origin:/")
    fi

    echo "$clean_line"
}

# --- Helper: deduplicate tasks by text content ---
deduplicate_tasks() {
    local tasks="$1"
    local seen=""
    local result=""

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        # Normalize: strip checkbox, stale markers, origin comments for comparison
        local normalized
        normalized=$(echo "$line" | sed 's/^[[:space:]]*- \[ \][[:space:]]*//' | sed 's/ [⏰⚠️🔴💀]//g' | sed 's/ <!-- origin: [0-9-]* -->//g' | sed 's/[[:space:]]*$//')
        if [[ "$seen" != *"|$normalized|"* ]]; then
            seen+="|$normalized|"
            result+="$line"$'\n'
        fi
    done <<< "$tasks"

    echo -n "$result"
}

# --- Helper: insert tasks into a section of the note ---
insert_tasks_into_section() {
    local note_path="$1"
    local section_header="$2"
    local tasks="$3"

    [[ -z "$tasks" ]] && return

    # Use awk to insert tasks after the section header (and its comment line if present)
    local tmp_file="${note_path}.tmp"
    awk -v section="$section_header" -v tasks="$tasks" '
    BEGIN { found=0; inserted=0 }
    {
        print
        if ($0 == section && !inserted) {
            found=1
        } else if (found && !inserted) {
            # Skip comment lines
            if ($0 ~ /^<!-- /) {
                # do nothing, already printed
            } else {
                # Insert tasks before first non-comment content
                printf "%s", tasks
                inserted=1
            }
        }
    }
    ' "$note_path" > "$tmp_file" && mv "$tmp_file" "$note_path"
}

# --- Helper: create note from template ---
create_note() {
    local note_type="$1"
    local note_path="$2"
    local template_path="$3"
    local date_label="$4"

    if [[ -f "$note_path" ]]; then
        echo "[HOOK:SessionStart] SKIPPED — $note_type note already exists: $note_path"
        return 0
    fi

    # Ensure parent directory
    mkdir -p "$(dirname "$note_path")"

    # Copy template and fill placeholders
    cp "$template_path" "$note_path"

    # Common replacements
    sed -i "s/{{YYYY-MM-DD}}/$TODAY/g" "$note_path"
    sed -i "s/{{YYYY}}/$YEAR/g" "$note_path"
    sed -i "s/{{Day-of-week}}/$DAY_OF_WEEK/g" "$note_path"
    sed -i "s/{{Day}}/$DAY_OF_WEEK/g" "$note_path"
    sed -i "s/{{YYYY-MM}}/$YEAR-$MONTH/g" "$note_path"
    sed -i "s/{{Month-Name}}/$MONTH_NAME/g" "$note_path"
    sed -i "s/{{YYYY-WNN}}/$YEAR-W$WEEK_NUM/g" "$note_path"
    sed -i "s/{{Mon-date}}/$WEEK_MON/g" "$note_path"
    sed -i "s/{{Fri-date}}/$WEEK_FRI/g" "$note_path"
    sed -i "s/{{YYYY-QN}}/$YEAR-Q$QUARTER/g" "$note_path"
    sed -i "s/{{Q-start}}/$YEAR-$Q_START_MONTH/g" "$note_path"
    sed -i "s/{{Q-end}}/$YEAR-$Q_END_MONTH/g" "$note_path"
    sed -i "s/{{N}}/$QUARTER/g" "$note_path"
    sed -i "s/{{NN}}/$WEEK_NUM/g" "$note_path"

    # Navigation placeholders (daily note)
    sed -i "s/{{PREV-DATE}}/$PREV_DATE/g" "$note_path"
    sed -i "s/{{NEXT-DATE}}/$NEXT_DATE/g" "$note_path"

    # Compute weekday date placeholders for weekly template
    if [[ "$note_type" == "weekly" ]]; then
        local tue=$(date -d "$WEEK_MON +1 day" +%Y-%m-%d 2>/dev/null || echo "")
        local wed=$(date -d "$WEEK_MON +2 days" +%Y-%m-%d 2>/dev/null || echo "")
        local thu=$(date -d "$WEEK_MON +3 days" +%Y-%m-%d 2>/dev/null || echo "")
        sed -i "s/{{Tue-date}}/$tue/g" "$note_path"
        sed -i "s/{{Wed-date}}/$wed/g" "$note_path"
        sed -i "s/{{Thu-date}}/$thu/g" "$note_path"
    fi

    # Quarterly template: fill month-specific placeholders
    if [[ "$note_type" == "quarterly" ]]; then
        local m1=$(printf "%02d" $(( (QUARTER - 1) * 3 + 1 )))
        local m2=$(printf "%02d" $(( (QUARTER - 1) * 3 + 2 )))
        local m3=$(printf "%02d" $(( (QUARTER - 1) * 3 + 3 )))
        sed -i "s/{{YYYY-MM-1}}/$YEAR-$m1/g" "$note_path"
        sed -i "s/{{YYYY-MM-2}}/$YEAR-$m2/g" "$note_path"
        sed -i "s/{{YYYY-MM-3}}/$YEAR-$m3/g" "$note_path"
    fi

    echo "[HOOK:SessionStart] FIRED — Created $note_type note for $date_label: $note_path"

    # --- Task rollover (daily notes only) ---
    if [[ "$note_type" == "daily" ]]; then
        local prev_note
        prev_note=$(find_previous_note) || true

        if [[ -n "$prev_note" ]]; then
            echo "[HOOK:SessionStart] Rolling over tasks from: $prev_note"

            # Extract incomplete tasks from each tier
            local secondary_tasks tertiary_tasks other_tasks
            secondary_tasks=$(extract_tasks "$prev_note" "### Secondary Priority")
            tertiary_tasks=$(extract_tasks "$prev_note" "### Tertiary Priority")
            other_tasks=$(extract_tasks "$prev_note" "### Other Tasks")

            # Apply stale tags to each task
            local tagged_secondary="" tagged_tertiary="" tagged_other=""

            while IFS= read -r task; do
                [[ -z "$task" ]] && continue
                tagged_secondary+="$(apply_stale_tag "$task")"$'\n'
            done <<< "$secondary_tasks"

            while IFS= read -r task; do
                [[ -z "$task" ]] && continue
                tagged_tertiary+="$(apply_stale_tag "$task")"$'\n'
            done <<< "$tertiary_tasks"

            while IFS= read -r task; do
                [[ -z "$task" ]] && continue
                tagged_other+="$(apply_stale_tag "$task")"$'\n'
            done <<< "$other_tasks"

            # Deduplicate
            tagged_secondary=$(deduplicate_tasks "$tagged_secondary")
            tagged_tertiary=$(deduplicate_tasks "$tagged_tertiary")
            tagged_other=$(deduplicate_tasks "$tagged_other")

            # Insert into today's note
            insert_tasks_into_section "$note_path" "### Secondary Priority" "$tagged_secondary"
            insert_tasks_into_section "$note_path" "### Tertiary Priority" "$tagged_tertiary"
            insert_tasks_into_section "$note_path" "### Other Tasks" "$tagged_other"

            # Carry forward unchecked ideas
            local ideas
            ideas=$(extract_unchecked_items "$prev_note" "## Ideas & Insights")
            if [[ -n "$ideas" ]]; then
                insert_tasks_into_section "$note_path" "## Ideas & Insights" "$ideas"
                echo "[HOOK:SessionStart] Carried forward ideas from previous note"
            fi

            # Carry forward Tomorrow's Prep into Top Priority
            local prep_items
            prep_items=$(extract_unchecked_items "$prev_note" "## Tomorrow's Prep")
            if [[ -n "$prep_items" ]]; then
                insert_tasks_into_section "$note_path" "### Top Priority" "$prep_items"
                echo "[HOOK:SessionStart] Carried forward Tomorrow's Prep into Top Priority"
            fi

            # Count rollovers
            local count=0
            [[ -n "$tagged_secondary" ]] && count=$((count + $(echo "$tagged_secondary" | grep -c '^\- \[ \]' || true)))
            [[ -n "$tagged_tertiary" ]] && count=$((count + $(echo "$tagged_tertiary" | grep -c '^\- \[ \]' || true)))
            [[ -n "$tagged_other" ]] && count=$((count + $(echo "$tagged_other" | grep -c '^\- \[ \]' || true)))
            echo "[HOOK:SessionStart] Rolled over $count tasks"
        else
            echo "[HOOK:SessionStart] No previous daily note found (last 7 days) — skipping rollover"
        fi
    fi
}

# --- Create each note type ---

# Daily: notes/YYYY/MM/YYYY-MM-DD.md
create_note "daily" \
    "$NOTES_DIR/$YEAR/$MONTH/$TODAY.md" \
    "$TEMPLATE_DIR/daily-note.md" \
    "$TODAY"

# Weekly: notes/YYYY/YYYY-WNN.md
create_note "weekly" \
    "$NOTES_DIR/$YEAR/$YEAR-W$WEEK_NUM.md" \
    "$TEMPLATE_DIR/weekly-note.md" \
    "$YEAR-W$WEEK_NUM"

# Monthly: notes/YYYY/YYYY-MM.md
create_note "monthly" \
    "$NOTES_DIR/$YEAR/$YEAR-$MONTH.md" \
    "$TEMPLATE_DIR/monthly-note.md" \
    "$YEAR-$MONTH"

# Quarterly: notes/YYYY/YYYY-QN.md
create_note "quarterly" \
    "$NOTES_DIR/$YEAR/$YEAR-Q$QUARTER.md" \
    "$TEMPLATE_DIR/quarterly-note.md" \
    "$YEAR-Q$QUARTER"

# Yearly: notes/YYYY/YYYY.md
create_note "yearly" \
    "$NOTES_DIR/$YEAR/$YEAR.md" \
    "$TEMPLATE_DIR/yearly-note.md" \
    "$YEAR"

echo "ensure-note.sh complete."
