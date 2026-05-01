#!/usr/bin/env bash
# ============================================================
# Task: 2026-04-17-statusline-adoption
# Agent: morpheus (in-session)
# Created: 2026-04-17T17:05
# Last-Updated: 2026-04-17T17:05
# Plan: {{paths.home}}/.claude/plans/eventual-roaming-pumpkin.md (revised after /second-opinion)
# Purpose: Two-line Claude Code statusline — model+folder+branch on line 1; progress bar + ctx% + cost + duration + cache% on line 2.
# Dependencies: bash (Git Bash on Windows), node (v18+), git (optional — for branch display)
# Upstream-Source: trailofbits/claude-code-config scripts/statusline.sh
# Upstream-SHA: 00183c41fe8d4a55e482e525c5e1fcffa08e1832 (2026-02-12, Dan Guido, "Initial commit")
# Adaptation-Notes:
#   - jq → node: jq absent on Goodwin endpoints (see memory/feedback_hooks_goodwin_toolchain.md)
#   - used_percentage preferred over remaining_percentage (matches docs convention; equivalent result)
#   - "null" string sentinel preserved when context_window has no usable data (suppresses bar at session start)
#   - Git lookups cached in /tmp/statusline-git-cache-${session_id} with 5s TTL (per docs §"Cache expensive operations")
#   - set -euo pipefail + [[ ]] + quoted vars per .claude/rules/scripts.md
# Changelog (max 10):
#   2026-04-17T17:05 | 2026-04-17-statusline-adoption | morpheus | Created — port from upstream SHA 00183c41 with jq→node + Morpheus standards + ctx_used null preservation + git cache
# ============================================================

set -euo pipefail

# Read all of stdin from Claude Code (single JSON object per docs)
stdin_data="$(cat)"

# ---------------------------------------------------------------
# Parse 8 fields out of the JSON via Node (jq is absent on Goodwin)
# Output one TSV line: current_dir \t model_name \t cost \t lines_added \t lines_removed \t duration_ms \t ctx_used \t cache_pct \t session_id
# ctx_used emits literal "null" string when no usable context data — preserves upstream's bar-suppression sentinel
# ---------------------------------------------------------------
parsed_line="$(printf '%s' "$stdin_data" | node -e '
let input = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", d => input += d);
process.stdin.on("end", () => {
  let d;
  try { d = JSON.parse(input); } catch (e) { d = {}; }

  // Helper: jq // semantics — fall back when value is null/undefined/false/empty-string
  const jqDefault = (v, def) => (v === null || v === undefined || v === false || v === "") ? def : v;

  const current_dir = jqDefault(d?.workspace?.current_dir ?? d?.cwd, "unknown");
  const model_name  = jqDefault(d?.model?.display_name, "Unknown");

  // cost: round to 2 decimals, mirroring upstream `(. * 100 | floor / 100)`
  let cost = 0;
  try {
    const c = jqDefault(d?.cost?.total_cost_usd, 0);
    const n = Number(c);
    cost = Number.isFinite(n) ? Math.floor(n * 100) / 100 : 0;
  } catch { cost = 0; }

  const lines_added   = jqDefault(d?.cost?.total_lines_added,   0);
  const lines_removed = jqDefault(d?.cost?.total_lines_removed, 0);
  const duration_ms   = jqDefault(d?.cost?.total_duration_ms,   0);

  // ctx_used: prefer used_percentage (docs convention), then 100-remaining_percentage,
  // then manual token math, else literal "null" string (matches upstream sentinel)
  let ctx_used = "null";
  try {
    const cw = d?.context_window;
    if (cw) {
      const up = cw.used_percentage;
      const rp = cw.remaining_percentage;
      const cws = cw.context_window_size;
      const cu = cw.current_usage;
      if (up !== null && up !== undefined && Number.isFinite(Number(up))) {
        ctx_used = String(Math.floor(Number(up)));
      } else if (rp !== null && rp !== undefined && Number.isFinite(Number(rp))) {
        ctx_used = String(100 - Math.floor(Number(rp)));
      } else if (Number(cws) > 0 && cu) {
        const it = Number(jqDefault(cu.input_tokens, 0)) || 0;
        const cct = Number(jqDefault(cu.cache_creation_input_tokens, 0)) || 0;
        const crt = Number(jqDefault(cu.cache_read_input_tokens, 0)) || 0;
        const total = it + cct + crt;
        if (Number(cws) > 0) {
          ctx_used = String(Math.floor(total * 100 / Number(cws)));
        }
      }
    }
  } catch { ctx_used = "null"; }

  // cache_pct: cache_read / (input + cache_read) — guard divide-by-zero
  let cache_pct = 0;
  try {
    const cu = d?.context_window?.current_usage;
    if (cu) {
      const it = Number(jqDefault(cu.input_tokens, 0)) || 0;
      const crt = Number(jqDefault(cu.cache_read_input_tokens, 0)) || 0;
      const denom = it + crt;
      if (denom > 0) cache_pct = Math.floor(crt * 100 / denom);
    }
  } catch { cache_pct = 0; }

  const session_id = jqDefault(d?.session_id, "no-session");

  // Emit TSV (none of these fields should contain literal tabs in normal Claude Code payloads)
  process.stdout.write([
    current_dir, model_name, cost, lines_added, lines_removed,
    duration_ms, ctx_used, cache_pct, session_id
  ].join("\t"));
});
' 2>/dev/null || echo $'unknown\tUnknown\t0\t0\t0\t0\tnull\t0\tno-session')"

IFS=$'\t' read -r current_dir model_name cost lines_added lines_removed duration_ms ctx_used cache_pct session_id <<< "$parsed_line"

# Defensive defaults if parse produced empty fields
: "${current_dir:=unknown}"
: "${model_name:=Unknown}"
: "${cost:=0}"
: "${duration_ms:=0}"
: "${ctx_used:=null}"
: "${cache_pct:=0}"
: "${session_id:=no-session}"

# ---------------------------------------------------------------
# Git info — cached by session_id (5s TTL per docs §"Cache expensive operations")
# ---------------------------------------------------------------
cache_file="/tmp/statusline-git-cache-${session_id}"
cache_max_age=5
git_branch=""
git_root=""

cache_is_stale() {
  if [[ ! -f "$cache_file" ]]; then return 0; fi
  local mtime now
  # Git Bash on Windows: stat -c is GNU stat (works); BSD stat -f is macOS only
  mtime="$(stat -c %Y "$cache_file" 2>/dev/null || echo 0)"
  now="$(date +%s)"
  (( now - mtime > cache_max_age ))
}

if cache_is_stale; then
  if cd "$current_dir" 2>/dev/null; then
    git_branch="$(git -c core.useBuiltinFSMonitor=false branch --show-current 2>/dev/null || echo '')"
    git_root="$(git -c core.useBuiltinFSMonitor=false rev-parse --show-toplevel 2>/dev/null || echo '')"
  fi
  printf '%s\t%s\n' "$git_branch" "$git_root" > "$cache_file" 2>/dev/null || true
else
  IFS=$'\t' read -r git_branch git_root < "$cache_file" || true
fi

# Folder name display (basename of git root if at root, else basename of cwd)
if [[ -n "$git_root" ]]; then
  repo_name="$(basename "$git_root")"
  if [[ "$current_dir" == "$git_root" ]]; then
    folder_name="$repo_name"
  else
    folder_name="$(basename "$current_dir")"
  fi
else
  folder_name="$(basename "$current_dir")"
fi

# ---------------------------------------------------------------
# Progress bar (only when ctx_used is a real number, not the literal "null" string)
# ---------------------------------------------------------------
progress_bar=""
ctx_pct=""
bar_width=12

if [[ "$ctx_used" != "null" ]] && [[ "$ctx_used" =~ ^[0-9]+$ ]]; then
  filled=$(( ctx_used * bar_width / 100 ))
  (( filled < 0 )) && filled=0
  (( filled > bar_width )) && filled=bar_width
  empty=$(( bar_width - filled ))

  if   (( ctx_used < 50 )); then bar_color=$'\033[32m'   # green
  elif (( ctx_used < 80 )); then bar_color=$'\033[33m'   # yellow
  else                            bar_color=$'\033[31m'  # red
  fi

  progress_bar="$bar_color"
  for ((i=0; i<filled; i++)); do progress_bar="${progress_bar}█"; done
  progress_bar="${progress_bar}"$'\033[2m'
  for ((i=0; i<empty; i++));  do progress_bar="${progress_bar}⣿"; done
  progress_bar="${progress_bar}"$'\033[0m'
  ctx_pct="${ctx_used}%"
fi

# ---------------------------------------------------------------
# Session time (human-readable)
# ---------------------------------------------------------------
session_time=""
if [[ "$duration_ms" =~ ^[0-9]+$ ]] && (( duration_ms > 0 )); then
  total_sec=$(( duration_ms / 1000 ))
  hours=$(( total_sec / 3600 ))
  minutes=$(( (total_sec % 3600) / 60 ))
  seconds=$(( total_sec % 60 ))
  if   (( hours > 0 ));   then session_time="${hours}h ${minutes}m"
  elif (( minutes > 0 )); then session_time="${minutes}m ${seconds}s"
  else                          session_time="${seconds}s"
  fi
fi

# ---------------------------------------------------------------
# Render
# ---------------------------------------------------------------
SEP=$'\033[2m│\033[0m'

# Short model: strip "Claude X.Y " prefix or leading "Claude "
short_model="$(printf '%s' "$model_name" | sed -E 's/^Claude [0-9.]+ //; s/^Claude //')"

line1="$(printf '\033[37m[%s]\033[0m \033[94m📁 %s\033[0m' "$short_model" "$folder_name")"
if [[ -n "$git_branch" ]]; then
  line1="${line1} $(printf '%b \033[96m🌿 %s\033[0m' "$SEP" "$git_branch")"
fi

line2=""
if [[ -n "$progress_bar" ]]; then
  line2="$(printf '%b' "$progress_bar")"
fi
if [[ -n "$ctx_pct" ]]; then
  if [[ -n "$line2" ]]; then
    line2="${line2} $(printf '\033[37m%s\033[0m' "$ctx_pct")"
  else
    line2="$(printf '\033[37m%s\033[0m' "$ctx_pct")"
  fi
fi
if [[ -n "$line2" ]]; then
  line2="${line2} $(printf '%b \033[33m$%s\033[0m' "$SEP" "$cost")"
else
  line2="$(printf '\033[33m$%s\033[0m' "$cost")"
fi
if [[ -n "$session_time" ]]; then
  line2="${line2} $(printf '%b \033[36m⏱ %s\033[0m' "$SEP" "$session_time")"
fi
if [[ "$cache_pct" =~ ^[0-9]+$ ]] && (( cache_pct > 0 )); then
  line2="${line2} $(printf ' \033[2m↻%s%%\033[0m' "$cache_pct")"
fi

# Two-line output (multi-line officially supported per docs §"How status lines work")
printf '%b\n%b\n' "$line1" "$line2"
