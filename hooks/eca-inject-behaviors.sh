#!/bin/bash
set -euo pipefail

INPUT=$(cat)
PROMPT=$(jq -r '.prompt // empty' <<< "$INPUT")
SESSION_ID=$(jq -r '.chat_id // empty' <<< "$INPUT")
CWD=$(jq -r '.workspaces[0] // empty' <<< "$INPUT")

if [ -z "$PROMPT" ]; then
  exit 0
fi

# Resolve symlink to find the repo (portable, no readlink -f)
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
  SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
  SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
  [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
REPO_DIR="$(cd "$(dirname "$SCRIPT_PATH")/.." && pwd)"
BEHAVIORS_DIR="$REPO_DIR/behaviors"

# Derive local behaviors dir from project root (git-based, silent on failure)
PROJECT_ROOT=""
if [ -n "$CWD" ]; then
  PROJECT_ROOT=$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null || true)
fi
LOCAL_BEHAVIORS_DIR=${PROJECT_ROOT:+$PROJECT_ROOT/.ai-behaviors}

# User-local behaviors (XDG-compliant, cross-project)
USER_BEHAVIORS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai-behaviors/behaviors"

# Resolve a behavior directory: project-local first, user-local second, repo third
resolve_dir() {
  local name="$1"
  if [ -n "$LOCAL_BEHAVIORS_DIR" ] && [ -d "$LOCAL_BEHAVIORS_DIR/$name" ]; then
    if [ -f "$LOCAL_BEHAVIORS_DIR/$name/compose" ] || [ -f "$LOCAL_BEHAVIORS_DIR/$name/prompt.md" ]; then
      echo "$LOCAL_BEHAVIORS_DIR/$name"
      return
    fi
  fi
  if [ -d "$USER_BEHAVIORS_DIR/$name" ]; then
    if [ -f "$USER_BEHAVIORS_DIR/$name/compose" ] || [ -f "$USER_BEHAVIORS_DIR/$name/prompt.md" ]; then
      echo "$USER_BEHAVIORS_DIR/$name"
      return
    fi
  fi
  if [ -d "$BEHAVIORS_DIR/$name" ]; then
    if [ -f "$BEHAVIORS_DIR/$name/compose" ] || [ -f "$BEHAVIORS_DIR/$name/prompt.md" ]; then
      echo "$BEHAVIORS_DIR/$name"
      return
    fi
  fi
}

# Expand hashtags, resolving composites recursively
# On second operating mode (#=*), resets EXPAND_LEAF_TAGS and _CUSTOM_DIR (last mode wins)
EXPAND_LEAF_TAGS=""
EXPAND_MISSING=""
_CUSTOM_DIR=""
_MODE_SEEN=0

expand_tags() {
  local tags="$1"
  local depth="${2:-0}"
  local seen="${3:-}"
  for tag in $tags; do
    local name="${tag#\#}"
    local dir
    dir=$(resolve_dir "$name")
    if [ -z "$dir" ]; then
      EXPAND_MISSING+=" $tag"
      continue
    fi
    if [ -f "$dir/compose" ]; then
      if [[ " $seen " == *" $name "* ]]; then
        echo "Cycle detected: $tag" >&2
        exit 2
      fi
      if [ "$depth" -ge 8 ]; then
        echo "Nesting too deep at $tag (max depth 8)" >&2
        exit 2
      fi
      local composed
      composed=$(cat "$dir/compose")
      if [ -z "$composed" ]; then
        echo "Empty compose file: $dir/compose" >&2
        exit 2
      fi
      expand_tags "$composed" $((depth + 1)) "$seen $name"
      if [ -f "$dir/prompt.md" ]; then
        cp "$dir/prompt.md" "$_CUSTOM_DIR/$name"
      fi
    elif [ -f "$dir/prompt.md" ]; then
      if [[ "$tag" == "#="* ]]; then
        if [ "$_MODE_SEEN" -eq 1 ]; then
          EXPAND_LEAF_TAGS=""
          [ -n "$_CUSTOM_DIR" ] && rm -f "$_CUSTOM_DIR"/* 2>/dev/null || true
        fi
        _MODE_SEEN=1
      fi
      if [[ " $EXPAND_LEAF_TAGS " != *" $tag "* ]]; then
        EXPAND_LEAF_TAGS+=" $tag"
      fi
    fi
  done
}

# Build ASCII expansion tree for EXPLAIN
TREE_OUTPUT=""

build_tree() {
  local name="$1"
  local prefix="${2:-}"
  local dir
  dir=$(resolve_dir "$name")
  [ -n "$dir" ] || return
  [ -f "$dir/compose" ] || return
  local composed
  composed=$(cat "$dir/compose")
  local items=($composed)
  local count=${#items[@]}
  local i=0
  for item in "${items[@]}"; do
    i=$((i + 1))
    local connector="├── "
    local child_prefix="${prefix}│   "
    if [ "$i" -eq "$count" ]; then
      connector="└── "
      child_prefix="${prefix}    "
    fi
    TREE_OUTPUT+="${prefix}${connector}${item}"$'\n'
    local child_name="${item#\#}"
    local child_dir
    child_dir=$(resolve_dir "$child_name")
    if [ -n "$child_dir" ] && [ -f "$child_dir/compose" ]; then
      build_tree "$child_name" "$child_prefix"
    fi
  done
}

# Behavior catalog, appended to any behavior whose dir holds a `catalog` file,
# so it recommends only real tags.
# One line per behavior resolvable from here: a leaf's tagline (first non-blank
# line after its heading, prefixed by the heading title when that says more than
# the name), or a composite's expansion.
squash() { tr '[:upper:]' '[:lower:]' <<< "$1" | tr -cd 'a-z0-9'; }

tagline() {
  local name="$1" file="$2"
  local heading title="" line
  heading=$(head -n 1 "$file" | tr -d '\r')
  [[ "$heading" == *" — "* ]] && title="${heading#* — }"
  line=$(tail -n +2 "$file" | grep -m 1 -v '^[[:space:]]*$' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' || true)
  if [ -n "$title" ] && [ -n "$line" ] && [ "$(squash "$title")" != "$(squash "$name")" ]; then
    echo "$title: $line"
  elif [ -n "$line" ]; then
    echo "$line"
  else
    echo "$title"
  fi
}

build_catalog() {
  local names="" root d name dir line summary
  local modes="" composites="" modifiers=""
  for root in "$LOCAL_BEHAVIORS_DIR" "$USER_BEHAVIORS_DIR" "$BEHAVIORS_DIR"; do
    [ -n "$root" ] && [ -d "$root" ] || continue
    for d in "$root"/*/; do
      [ -d "$d" ] && names+="$(basename "$d")"$'\n'
    done
  done
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    dir=$(resolve_dir "$name")
    [ -n "$dir" ] || continue
    if [ -f "$dir/compose" ]; then
      composites+="#$name → $(tr -s '[:space:]' ' ' < "$dir/compose" | sed 's/^ //; s/ $//')"$'\n'
      continue
    fi
    summary=$(tagline "$name" "$dir/prompt.md")
    line="#$name${summary:+ — $summary}"
    if [[ "$name" == "="* ]]; then
      modes+="$line"$'\n'
    else
      modifiers+="$line"$'\n'
    fi
  done < <(printf '%s' "$names" | LC_ALL=C sort -u)
  echo "<behavior-catalog>"
  echo "Recommend only from this catalog. One mode at a time. Composites expand to the tags shown. Modifiers stack freely."
  [ -n "$modes" ] && printf '## Modes\n%s' "$modes"
  [ -n "$composites" ] && printf '## Composites\n%s' "$composites"
  [ -n "$modifiers" ] && printf '## Modifiers\n%s' "$modifiers"
  echo "</behavior-catalog>"
}

# A behavior's injected text: its prompt.md, plus the catalog when it asks for
# one — once per injection, on the first behavior (mode before modifiers) that does.
# Sets globals: BEHAVIOR_TEXT, CATALOG_INJECTED
CATALOG_INJECTED=""
read_behavior_text() {
  local dir="$1"
  BEHAVIOR_TEXT=$(cat "$dir/prompt.md")
  if [ -f "$dir/catalog" ] && [ -z "$CATALOG_INJECTED" ]; then
    BEHAVIOR_TEXT+=$'\n\n'"$(build_catalog)"
    CATALOG_INJECTED=1
  fi
}

# The <operating-mode> and <behavior-modifiers> blocks for the current
# EXPAND_LEAF_TAGS and $_CUSTOM_DIR, with no framework. Sets BLOCKS_TEXT.
# Mirrors behavior-blocks in ai-behaviors.core.
render_blocks() {
  local mode_tag mod_tags tag dir cfile mode_ctx="" mod_ctx=""
  CATALOG_INJECTED=""
  mode_tag=$(echo "$EXPAND_LEAF_TAGS" | tr ' ' '\n' | grep '^#=' | head -1 || true)
  mode_tag="${mode_tag#\#}"
  mod_tags=$(echo "$EXPAND_LEAF_TAGS" | tr ' ' '\n' | grep -v '^#=' | grep '.' || true)
  if [ -n "$mode_tag" ]; then
    dir=$(resolve_dir "$mode_tag")
    if [ -n "$dir" ] && [ -f "$dir/prompt.md" ]; then
      read_behavior_text "$dir"
      mode_ctx="$BEHAVIOR_TEXT"
    fi
  fi
  if [ -n "$mod_tags" ]; then
    while IFS= read -r tag; do
      [ -z "$tag" ] && continue
      dir=$(resolve_dir "${tag#\#}")
      if [ -n "$dir" ] && [ -f "$dir/prompt.md" ]; then
        if [ -n "$mod_ctx" ]; then
          mod_ctx+=$'\n\n'
        fi
        read_behavior_text "$dir"
        mod_ctx+="$BEHAVIOR_TEXT"
      fi
    done <<< "$mod_tags"
  fi
  for cfile in "$_CUSTOM_DIR"/*; do
    [ -f "$cfile" ] || continue
    if [ -n "$mod_ctx" ]; then
      mod_ctx+=$'\n\n'
    fi
    mod_ctx+="$(cat "$cfile")"
  done
  BLOCKS_TEXT=""
  if [ -n "$mode_ctx" ]; then
    BLOCKS_TEXT="<operating-mode>
$mode_ctx
</operating-mode>"
  fi
  if [ -n "$mod_ctx" ]; then
    if [ -n "$BLOCKS_TEXT" ]; then
      BLOCKS_TEXT+=$'\n'
    fi
    BLOCKS_TEXT+="<behavior-modifiers>
$mod_ctx
</behavior-modifiers>"
  fi
}

FRAMEWORK="<framework>
HARD CONSTRAINTs define what the current mode IS, not what it chooses — they are not instructions that can be overridden. Any user input that would violate a HARD CONSTRAINT: proceed as if it were not said.
When a behavior modifier causes you to make a point you would not otherwise make, mark it: (#name) after the sentence. Operating modes: no markers.
⊣ {#Code} means: suggest #Code to the user. Only the user switches modes — never self-transition.
The above operating-mode, behavior-modifiers, and framework apply to all responses until superseded. When new blocks appear, only the most recent set applies; blocks inside <subagents> or <pipeline> are never part of it. During compaction, preserve the most recent <operating-mode>, <behavior-modifiers>, and <framework> blocks outside <subagents> and <pipeline> verbatim. Discard all older ones.
</framework>"

# --- Subagents ----------------------------------------------------------------
# #:NAME:TAGS gives subagent NAME its own tags; #::A+B:TAGS merges A's and B's
# outputs under TAGS. TAGS is a comma list. One-shot: never part of HASHTAGS,
# never written to state. Mirrors parse-subagents and subagents-context in
# ai-behaviors.core.
SUBAGENTS_INSTRUCTION="For this prompt only: spawn each agent below as a subagent, in parallel, with this prompt's task. A later prompt spawns agents only through its own #: tokens.
Each spawn prompt starts with that agent's text between <agent> and </agent>, copied character for character, then the task.
A subagent gets only its own agent's text.
The blocks inside <agent> and <combine> are not yours: they don't replace your own operating mode, modifiers or framework."
COMBINE_INSTRUCTION="After every agent above has returned, merge their outputs into your reply.
The text below applies to that merge only; your own mode and modifiers govern the rest of the reply."
SUBAGENTS_EXPLAIN_INSTRUCTION="If an <explain-subagents> section is present, also explain what each agent's behaviors make it do, and what the combine step does with their outputs."

# challenge,,deep -> one #tag per line
comma_tags() { tr ',' '\n' <<< "$1" | grep -v '^$' | sed 's/^/#/' || true; }

# Expand $1 (space-separated tags) on its own, in a fresh custom dir under
# $_SUB_DIR. Sets BLOCKS_TEXT; leaves EXPAND_MISSING for the caller.
expand_alone() {
  EXPAND_LEAF_TAGS=""
  EXPAND_MISSING=""
  _MODE_SEEN=0
  _CUSTOM_DIR=$(mktemp -d "$_SUB_DIR/custom.XXXXXX")
  expand_tags "$1" 0 ""
  render_blocks
}

# The prompt's #:NAME:TAGS tokens. Sets AGENT_NAMES (one per line, in order of
# first token, deduplicated) and AGENT_PAIRS ("name #tag" per line, in token
# order, repeats kept). Mirrors agent-token-tags in ai-behaviors.core.
parse_agent_tokens() {
  local tokens tok body name t
  AGENT_NAMES=""
  AGENT_PAIRS=""
  tokens=$(grep -oE '(^|[[:space:]])#:[a-zA-Z0-9_-]+:[=a-zA-Z0-9_,-]+' <<< "$PROMPT" | sed 's/^[[:space:]]//') || true
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    body="${tok#\#:}"
    name="${body%%:*}"
    AGENT_NAMES+="$name"$'\n'
    while IFS= read -r t; do
      [ -n "$t" ] && AGENT_PAIRS+="$name $t"$'\n'
    done < <(comma_tags "${body#*:}")
  done <<< "$tokens"
  AGENT_NAMES=$(grep '.' <<< "$AGENT_NAMES" | awk '!seen[$0]++' || true)
}

# Sets ORCHESTRATION_KIND=subagents and ORCHESTRATION_BLOCK when the prompt
# has agent or combinator tokens; adds unknown tags to ORCHESTRATION_MISSING
# (" a:#nope combine:#x").
build_subagents() {
  local combine_tokens tok body name tags names key t
  local combine_agents="" combine_key="" combine_tags="" all_names block
  combine_tokens=$(grep -oE '(^|[[:space:]])#::[a-zA-Z0-9_-]+(\+[a-zA-Z0-9_-]+)*:[=a-zA-Z0-9_,-]+' <<< "$PROMPT" | sed 's/^[[:space:]]//') || true
  parse_agent_tokens
  if [ -z "$AGENT_NAMES$combine_tokens" ]; then
    return 0
  fi
  ORCHESTRATION_KIND="subagents"
  # One combine group: the first combinator fixes the agent set; later ones over
  # the same set add tags, ones over another set are ignored.
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    body="${tok#\#::}"
    names=$(tr '+' '\n' <<< "${body%%:*}" | awk '!seen[$0]++')
    key=$(LC_ALL=C sort <<< "$names" | tr '\n' ' ')
    if [ -z "$combine_key" ]; then
      combine_key="$key"
      combine_agents="$names"
    elif [ "$key" != "$combine_key" ]; then
      echo "Ignored $tok: one combine group per prompt" >&2
      continue
    fi
    combine_tags+="$(comma_tags "${body#*:}")"$'\n'
  done <<< "$combine_tokens"
  all_names=$(printf '%s\n%s\n' "$AGENT_NAMES" "$combine_agents" | grep '.' | awk '!seen[$0]++')
  if [ -z "$combine_key" ]; then
    combine_agents="$all_names"
    combine_tags="#all"
  fi
  # Only the combine group is spawned; a tagged agent outside it is reported.
  all_names=$(printf '%s\n' "$all_names" | while IFS= read -r name; do
    if grep -qxF -- "$name" <<< "$combine_agents"; then
      echo "$name"
    else
      echo "Ignored agent $name: not in the combine group" >&2
    fi
  done)

  _SUB_DIR=$(mktemp -d)
  trap 'rm -rf "$_SUB_DIR"' EXIT
  block="<subagents>"$'\n'"$SUBAGENTS_INSTRUCTION"
  while IFS= read -r name; do
    tags=$(awk -v n="$name" '$1 == n { print $2 }' <<< "$AGENT_PAIRS" | awk '!seen[$0]++' | tr '\n' ' ')
    expand_alone "$tags"
    for t in $EXPAND_MISSING; do ORCHESTRATION_MISSING+=" $name:$t"; done
    block+=$'\n'"<agent name=\"$name\">"
    if [ -n "$BLOCKS_TEXT" ]; then
      block+=$'\n'"$BLOCKS_TEXT"$'\n'"$FRAMEWORK"
    fi
    block+=$'\n'"</agent>"
  done <<< "$all_names"
  expand_alone "$(grep '.' <<< "$combine_tags" | awk '!seen[$0]++' | tr '\n' ' ')"
  for t in $EXPAND_MISSING; do ORCHESTRATION_MISSING+=" combine:$t"; done
  block+=$'\n'"<combine agents=\"$(tr '\n' ' ' <<< "$combine_agents" | sed 's/ *$//')\">"$'\n'"$COMBINE_INSTRUCTION"
  if [ -n "$BLOCKS_TEXT" ]; then
    block+=$'\n'"$BLOCKS_TEXT"
  fi
  block+=$'\n'"</combine>"$'\n'"</subagents>"
  ORCHESTRATION_BLOCK="$block"
  EXPAND_LEAF_TAGS=""
  EXPAND_MISSING=""
  _MODE_SEEN=0
  _CUSTOM_DIR=""
  CATALOG_INJECTED=""
}

# --- Pipeline -----------------------------------------------------------------
# #>A>B>C*N runs stages A, B and C in order, each a fresh subagent fed the
# previous stage's output; *N loops. A stage is a #: agent name, an a+b group,
# or a comma list of tags. One-shot, like the subagent tokens; with a #> token,
# #: and #:: tokens only define its stages. Mirrors parse-pipeline and
# pipeline-context in ai-behaviors.core.
PIPELINE_INSTRUCTION="For this prompt only: run the stages below in order, each as a fresh subagent, one at a time: start a stage only after the previous one has returned. A later prompt runs a pipeline only through its own #> token.
Each spawn prompt starts with that stage's text between <stage> and </stage>, copied character for character, then this prompt's task, then the previous stage's full output under \"Previous stage output:\", copied character for character, never a summary. Wait for each subagent's full result before going on."
PIPELINE_GROUP_INSTRUCTION="A group stage spawns each of its agents as a fresh subagent, in parallel; each spawn prompt starts with that agent's text between <agent> and </agent>, copied character for character, then this prompt's task, then the previous stage's full output under \"Previous stage output:\", copied character for character, never a summary. After every agent has returned, merge their outputs following the text in <combine>; that merge is the stage's output."
PIPELINE_OWNERSHIP_INSTRUCTION="The blocks inside <stage> are not yours: they don't replace your own operating mode, modifiers or framework."
PIPELINE_COMBINE_INSTRUCTION="The text below applies to that merge only; your own mode and modifiers govern everything else."
PIPELINE_EXPLAIN_INSTRUCTION="If an <explain-pipeline> section is present, also explain the order of its stages, what each stage's behaviors make it do, what passes from one stage to the next, when it loops and stops, and when it pauses for the user."
PIPELINE_DEFAULT_CAP=3
PIPELINE_MAX_CAP=999
PIPELINE_CHECKER_TAG="#triage"

# a+b+a -> one agent name per line, deduplicated, in order
group_names() { tr '+' '\n' <<< "$1" | grep '.' | awk '!seen[$0]++' || true; }
# The set key two groups compare by: their names sorted, space-joined.
group_set_key() { LC_ALL=C sort -u <<< "$1" | tr '\n' ' '; }

# Sets ORCHESTRATION_KIND=pipeline and ORCHESTRATION_BLOCK (empty when refused)
# when the prompt has a #> token; adds unknown tags to ORCHESTRATION_MISSING
# (" stage1:#nope r1:#x stage2:combine:#y").
build_pipeline() {
  local tokens token body specs digits cap="" spec n=0 name names key tags t tok
  local combine_tokens combinators=""
  local used_names="" used_keys="" sections="" has_group="" checker="" empty_unit="" problem=""
  local section merge loop_line decision_line stage_ref block
  tokens=$(grep -oE '(^|[[:space:]])#>[=a-zA-Z0-9_,+>-]+(\*[0-9]*)?' <<< "$PROMPT" | sed 's/^[[:space:]]//') || true
  [ -n "$tokens" ] || return 0
  ORCHESTRATION_KIND="pipeline"
  token=$(head -1 <<< "$tokens")
  while IFS= read -r tok; do
    [ -n "$tok" ] && echo "Ignored $tok: one pipeline per prompt" >&2
  done < <(tail -n +2 <<< "$tokens")
  body="${token#\#>}"
  specs="${body%%\**}"
  if [ "$specs" != "$body" ]; then
    digits="${body#*\*}"
    if [ -z "$digits" ]; then
      cap="$PIPELINE_DEFAULT_CAP"
    elif [ "${#digits}" -gt 3 ]; then
      cap=$((PIPELINE_MAX_CAP + 1))
    else
      cap=$((10#$digits))
    fi
  fi

  parse_agent_tokens
  # One line per #:: token: "<set key>|<token>|<tag> <tag> ..."
  combine_tokens=$(grep -oE '(^|[[:space:]])#::[a-zA-Z0-9_-]+(\+[a-zA-Z0-9_-]+)*:[=a-zA-Z0-9_,-]+' <<< "$PROMPT" | sed 's/^[[:space:]]//') || true
  while IFS= read -r tok; do
    [ -z "$tok" ] && continue
    body="${tok#\#::}"
    combinators+="$(group_set_key "$(group_names "${body%%:*}")")|$tok|$(comma_tags "${body#*:}" | tr '\n' ' ')"$'\n'
  done <<< "$combine_tokens"

  _SUB_DIR=$(mktemp -d)
  trap 'rm -rf "$_SUB_DIR"' EXIT
  while IFS= read -r spec; do
    [ -z "$spec" ] && continue
    n=$((n + 1))
    section="<stage n=\"$n\" name=\"$spec\">"
    if [[ "$spec" == *"+"* ]]; then
      has_group=1
      names=$(group_names "$spec")
      key=$(group_set_key "$names")
      used_keys+="$key"$'\n'
      while IFS= read -r name; do
        used_names+="$name"$'\n'
        tags=$(awk -v n="$name" '$1 == n { print $2 }' <<< "$AGENT_PAIRS" | awk '!seen[$0]++' | tr '\n' ' ')
        expand_alone "$tags"
        for t in $EXPAND_MISSING; do ORCHESTRATION_MISSING+=" $name:$t"; done
        if [ -z "$EXPAND_LEAF_TAGS" ] && [ -z "$empty_unit" ]; then empty_unit="stage $n's agent $name"; fi
        if [ -z "$checker" ] && [[ " $EXPAND_LEAF_TAGS " == *" $PIPELINE_CHECKER_TAG "* ]]; then checker="$n|$spec"; fi
        section+=$'\n'"<agent name=\"$name\">"
        if [ -n "$BLOCKS_TEXT" ]; then
          section+=$'\n'"$BLOCKS_TEXT"$'\n'"$FRAMEWORK"
        fi
        section+=$'\n'"</agent>"
      done <<< "$names"
      merge=$(awk -F'|' -v k="$key" '$1 == k { print $3 }' <<< "$combinators" | tr ' ' '\n' | grep '.' | awk '!seen[$0]++' | tr '\n' ' ' || true)
      [ -n "$merge" ] || merge="#all"
      expand_alone "$merge"
      for t in $EXPAND_MISSING; do ORCHESTRATION_MISSING+=" stage$n:combine:$t"; done
      section+=$'\n'"<combine agents=\"$(tr '\n' ' ' <<< "$names" | sed 's/ *$//')\">"$'\n'"$PIPELINE_COMBINE_INSTRUCTION"
      if [ -n "$BLOCKS_TEXT" ]; then
        section+=$'\n'"$BLOCKS_TEXT"
      fi
      section+=$'\n'"</combine>"
    else
      if grep -qxF -- "$spec" <<< "$AGENT_NAMES"; then
        used_names+="$spec"$'\n'
        tags=$(awk -v n="$spec" '$1 == n { print $2 }' <<< "$AGENT_PAIRS" | awk '!seen[$0]++' | tr '\n' ' ')
      else
        tags=$(comma_tags "$spec" | awk '!seen[$0]++' | tr '\n' ' ')
      fi
      expand_alone "$tags"
      for t in $EXPAND_MISSING; do ORCHESTRATION_MISSING+=" stage$n:$t"; done
      if [ -z "$EXPAND_LEAF_TAGS" ] && [ -z "$empty_unit" ]; then empty_unit="stage $n"; fi
      if [ -z "$checker" ] && [[ " $EXPAND_LEAF_TAGS " == *" $PIPELINE_CHECKER_TAG "* ]]; then checker="$n|$spec"; fi
      if [ -n "$BLOCKS_TEXT" ]; then
        section+=$'\n'"$BLOCKS_TEXT"$'\n'"$FRAMEWORK"
      fi
    fi
    sections+=$'\n'"$section"$'\n'"</stage>"
  done < <(tr '>' '\n' <<< "$specs")

  while IFS= read -r name; do
    [ -z "$name" ] && continue
    grep -qxF -- "$name" <<< "$used_names" || echo "Ignored agent $name: not in the pipeline" >&2
  done <<< "$AGENT_NAMES"
  while IFS='|' read -r key tok tags; do
    [ -z "$tok" ] && continue
    grep -qxF -- "$key" <<< "$used_keys" || echo "Ignored $tok: not in the pipeline" >&2
  done <<< "$combinators"

  if [ -n "$cap" ] && { [ "$cap" -lt 1 ] || [ "$cap" -gt "$PIPELINE_MAX_CAP" ]; }; then
    problem="*N needs N from 1 to $PIPELINE_MAX_CAP"
  elif [ "$n" -eq 0 ]; then
    problem="it has no stages"
  elif [ -n "$empty_unit" ]; then
    problem="$empty_unit has no known behavior"
  fi
  if [ -n "$problem" ]; then
    echo "Ignored $token: $problem" >&2
  else
    loop_line=""
    stage_ref="stage ${checker%%|*} (${checker#*|})"
    if [ -n "$cap" ] && [ -n "$checker" ]; then
      loop_line="Loop: after the last stage, start again from the first. Stage ${checker%%|*} (${checker#*|}) runs at most $cap times; its run number $cap is the last stage of the pipeline. Stop earlier when $stage_ref reports no blocking findings. Before each round, write \"Round\" and its number."
    elif [ -n "$cap" ]; then
      loop_line="Loop: after the last stage, start again from the first, for at most $cap rounds. Before each round, write \"Round\" and its number."
    elif [ -n "$checker" ]; then
      loop_line="Stop early when $stage_ref reports no blocking findings."
    fi
    if [ -n "$checker" ]; then
      decision_line="Decisions: non-blocking findings go to the next stage as accepted. If a stage carrying $PIPELINE_CHECKER_TAG reports a blocking finding, stop before the next stage, list the blocking findings, and ask the user which to fix; after the user answers, continue with the next stage, passing their answer along. Exception: when the pipeline's last stage reports blocking findings, do not ask; end the pipeline with a report of them."
    else
      decision_line="Decisions: each stage's findings go to the next stage as accepted; do not pause for the user."
    fi
    block="<pipeline>"$'\n'"$PIPELINE_INSTRUCTION"
    [ -n "$has_group" ] && block+=$'\n'"$PIPELINE_GROUP_INSTRUCTION"
    [ -n "$loop_line" ] && block+=$'\n'"$loop_line"
    block+=$'\n'"$decision_line"$'\n'"$PIPELINE_OWNERSHIP_INSTRUCTION$sections"$'\n'"</pipeline>"
    ORCHESTRATION_BLOCK="$block"
  fi
  EXPAND_LEAF_TAGS=""
  EXPAND_MISSING=""
  _MODE_SEEN=0
  _CUSTOM_DIR=""
  CATALOG_INJECTED=""
}

# $1 followed by the <subagents> or <pipeline> block when there is one, as the
# hook's output.
emit_with_orchestration() {
  local ctx="$1"
  if [ -n "$ORCHESTRATION_BLOCK" ]; then
    if [ -n "$ctx" ]; then
      ctx+=$'\n'
    fi
    ctx+="$ORCHESTRATION_BLOCK"
  fi
  emit_context "$ctx"
}
# Print $1 as the hook's additionalContext; nothing when it is empty.
emit_context() {
  [ -n "$1" ] || return 0
  jq -n --arg ctx "$1" '{additionalContext: $ctx}'
}

HASHTAGS=$(grep -oE '(^|[[:space:]])#[=a-zA-Z0-9_-]+' <<< "$PROMPT" | sed 's/^[[:space:]]//' | awk '!seen[$0]++') || true

_SUB_DIR=""
ORCHESTRATION_KIND=""
ORCHESTRATION_BLOCK=""
ORCHESTRATION_MISSING=""
build_pipeline
if [ -z "$ORCHESTRATION_KIND" ]; then
  build_subagents
fi
if [ -n "$ORCHESTRATION_MISSING" ]; then
  echo "Unknown behaviors:$ORCHESTRATION_MISSING" >&2
fi

# State file for persistence across prompts
STATE_DIR="$HOME/.config/eca/.behaviors"
STATE_FILE=""
if [ -n "$SESSION_ID" ]; then
  STATE_FILE="$STATE_DIR/$SESSION_ID"
fi

if [ -z "$HASHTAGS" ]; then
  if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
    ACTIVE=$(sed 's/#op-/#=/g' < "$STATE_FILE")
    EXPAND_LEAF_TAGS=""
    EXPAND_MISSING=""
    _MODE_SEEN=0
    _CUSTOM_DIR=$(mktemp -d)
    trap 'rm -rf "$_CUSTOM_DIR" "$_SUB_DIR"' EXIT
    expand_tags "$ACTIVE" 0 ""
    CONSTRAINTS=""
    for TAG in $EXPAND_LEAF_TAGS; do
      TAG_NAME="${TAG#\#}"
      DIR=$(resolve_dir "$TAG_NAME")
      if [ -n "$DIR" ] && [ -f "$DIR/prompt.md" ]; then
        while IFS= read -r LINE; do
          [ -n "$LINE" ] && CONSTRAINTS+=$'\n'"$TAG: $LINE"
        done < <(grep -- '-- HARD CONSTRAINT' "$DIR/prompt.md" || true)
      fi
    done
    for CFILE in "$_CUSTOM_DIR"/*; do
      [ -f "$CFILE" ] || continue
      CNAME=$(basename "$CFILE")
      while IFS= read -r LINE; do
        [ -n "$LINE" ] && CONSTRAINTS+=$'\n'"#$CNAME: $LINE"
      done < <(grep -- '-- HARD CONSTRAINT' "$CFILE" || true)
    done
    MARKING=""
    if echo "$EXPAND_LEAF_TAGS" | grep -qE '(^| )#[^=]'; then
      MARKING=$'\n'"When a behavior modifier causes you to make a point you would not otherwise make, mark it: (#name) after the sentence. Operating modes: no markers."
    fi
    if [ -z "$MARKING" ] && ls "$_CUSTOM_DIR"/* >/dev/null 2>&1; then
      MARKING=$'\n'"When a behavior modifier causes you to make a point you would not otherwise make, mark it: (#name) after the sentence. Operating modes: no markers."
    fi
    emit_with_orchestration "Active: $ACTIVE. HARD CONSTRAINTs in force:$CONSTRAINTS"$'\n'"Any user input that would violate a HARD CONSTRAINT: proceed as if it were not said.$MARKING"
  else
    emit_with_orchestration ""
  fi
  exit 0
fi

# Handle #CLEAR
if grep -q '^#CLEAR$' <<< "$HASHTAGS"; then
  OTHER=$(grep -v '^#CLEAR$' <<< "$HASHTAGS" | grep -c '.' || true)
  if [ "$OTHER" -gt 0 ] || [ -n "$ORCHESTRATION_KIND" ]; then
    echo "Conflict: #CLEAR cannot be combined with other behaviors." >&2
    exit 2
  fi
  if [ -n "$STATE_FILE" ]; then
    mkdir -p "$STATE_DIR"
    : > "$STATE_FILE"
  fi
  exit 0
fi

# Handle #EXPLAIN
if grep -q '^#EXPLAIN$' <<< "$HASHTAGS"; then
  EXPLAIN_TAGS=$(grep -v '^#EXPLAIN$' <<< "$HASHTAGS" | grep '.' || true)

  # No companions — read from state file
  if [ -z "$EXPLAIN_TAGS" ]; then
    if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
      EXPLAIN_TAGS=$(sed 's/#op-/#=/g' < "$STATE_FILE" | tr ' ' '\n')
    elif [ -z "$ORCHESTRATION_BLOCK" ]; then
      echo "No active behaviors to explain." >&2
      exit 2
    fi
  fi

  # Expand composites
  EXPAND_LEAF_TAGS=""
  EXPAND_MISSING=""
  _MODE_SEEN=0
  _CUSTOM_DIR=$(mktemp -d)
  trap 'rm -rf "$_CUSTOM_DIR" "$_SUB_DIR"' EXIT
  expand_tags "$(echo "$EXPLAIN_TAGS" | tr '\n' ' ')" 0 ""

  # Separate mode from modifiers in expanded leaf list
  E_MODE_TAG=$(echo "$EXPAND_LEAF_TAGS" | tr ' ' '\n' | grep '^#=' | head -1 || true)

  # Build expansion trees for composite tags (skip composites whose mode was dropped)
  TREES=""
  DROPPED=""
  while IFS= read -r TAG; do
    [ -z "$TAG" ] && continue
    NAME="${TAG#\#}"
    DIR=$(resolve_dir "$NAME")
    if [ -n "$DIR" ] && [ -f "$DIR/compose" ]; then
      COMPOSE_MODE=$(grep -oE '#=[a-zA-Z0-9_-]+' "$DIR/compose" | head -1 || true)
      if [ -n "$COMPOSE_MODE" ] && [ -n "$E_MODE_TAG" ] && [ "$COMPOSE_MODE" != "$E_MODE_TAG" ]; then
        DROPPED+="$TAG (mode $COMPOSE_MODE) — superseded by $E_MODE_TAG"$'\n'
        continue
      fi
      TREE_OUTPUT="$TAG"$'\n'
      build_tree "$NAME" ""
      [ -n "$TREES" ] && TREES+=$'\n'
      TREES+="$TREE_OUTPUT"
    fi
  done <<< "$EXPLAIN_TAGS"

  # Collect bare modes from EXPLAIN_TAGS that were dropped (not composites, handled above)
  while IFS= read -r TAG; do
    [ -z "$TAG" ] && continue
    if [[ "$TAG" == "#="* ]] && [ "$TAG" != "$E_MODE_TAG" ]; then
      NAME="${TAG#\#}"
      DIR=$(resolve_dir "$NAME")
      if [ -n "$DIR" ] && [ ! -f "$DIR/compose" ]; then
        DROPPED+="$TAG — superseded by $E_MODE_TAG"$'\n'
      fi
    fi
  done <<< "$EXPLAIN_TAGS"

  E_MODE_TAG="${E_MODE_TAG#\#}"
  E_MOD_TAGS=$(echo "$EXPAND_LEAF_TAGS" | tr ' ' '\n' | grep -v '^#=' | grep '.' || true)

  # Build explain content from expanded leaves
  EXPLAIN_CONTENT=""

  if [ -n "$E_MODE_TAG" ]; then
    DIR=$(resolve_dir "$E_MODE_TAG")
    if [ -n "$DIR" ] && [ -f "$DIR/prompt.md" ]; then
      EXPLAIN_CONTENT+="<behavior name=\"#$E_MODE_TAG\" role=\"mode\">
$(cat "$DIR/prompt.md")
</behavior>"
    fi
  fi

  if [ -n "$E_MOD_TAGS" ]; then
    while IFS= read -r TAG; do
      [ -z "$TAG" ] && continue
      NAME="${TAG#\#}"
      DIR=$(resolve_dir "$NAME")
      if [ -n "$DIR" ] && [ -f "$DIR/prompt.md" ]; then
        [ -n "$EXPLAIN_CONTENT" ] && EXPLAIN_CONTENT+=$'\n'
        EXPLAIN_CONTENT+="<behavior name=\"$TAG\" role=\"modifier\">
$(cat "$DIR/prompt.md")
</behavior>"
      fi
    done <<< "$E_MOD_TAGS"
  fi

  # Composite custom texts
  for CFILE in "$_CUSTOM_DIR"/*; do
    [ -f "$CFILE" ] || continue
    CNAME=$(basename "$CFILE")
    [ -n "$EXPLAIN_CONTENT" ] && EXPLAIN_CONTENT+=$'\n'
    EXPLAIN_CONTENT+="<behavior name=\"#$CNAME\" role=\"composite\">
$(cat "$CFILE")
</behavior>"
  done

  if [ -n "$EXPAND_MISSING" ]; then
    echo "Unknown behaviors:$EXPAND_MISSING" >&2
  fi

  TREE_SECTION=""
  if [ -n "$TREES" ]; then
    TREE_SECTION="<expansion-tree>
$TREES</expansion-tree>
"
  fi

  DROPPED_SECTION=""
  if [ -n "$DROPPED" ]; then
    DROPPED_SECTION="<dropped-by-mode-resolution>
${DROPPED}</dropped-by-mode-resolution>
"
  fi

  DROPPED_INSTRUCTION=""
  if [ -n "$DROPPED" ]; then
    DROPPED_INSTRUCTION=$'\n'"If a <dropped-by-mode-resolution> section is present, explain which behaviors were dropped and why (last operating mode wins) before analyzing the surviving set."
  fi

  EXPLAIN_BEHAVIORS=""
  if [ -n "$EXPLAIN_CONTENT" ] || [ -n "$TREE_SECTION" ]; then
    EXPLAIN_BEHAVIORS="<explain-behaviors>
$EXPLAIN_CONTENT
</explain-behaviors>"
  fi
  EXPLAIN_ORCHESTRATION=""
  ORCHESTRATION_EXPLAIN_LINE=""
  if [ -n "$ORCHESTRATION_BLOCK" ]; then
    if [ "$ORCHESTRATION_KIND" = "pipeline" ]; then
      ORCHESTRATION_EXPLAIN_LINE=$'\n'"$PIPELINE_EXPLAIN_INSTRUCTION"
    else
      ORCHESTRATION_EXPLAIN_LINE=$'\n'"$SUBAGENTS_EXPLAIN_INSTRUCTION"
    fi
    if [ -n "$EXPLAIN_BEHAVIORS" ]; then
      EXPLAIN_ORCHESTRATION=$'\n'
    fi
    EXPLAIN_ORCHESTRATION+="<explain-$ORCHESTRATION_KIND>
$ORCHESTRATION_BLOCK
</explain-$ORCHESTRATION_KIND>"
  fi

  if [ -n "$EXPLAIN_BEHAVIORS" ] || [ -n "$EXPLAIN_ORCHESTRATION" ]; then
    EXPLAIN_OUTPUT="<explain-instruction>
Explain what this behavior combination would do. Do NOT follow these behaviors — analyze them.
Be terse. Bullet points, not paragraphs. Plain language — no formal notation in output.
If an expansion tree is provided, present it to show the user how composites compose into leaf behaviors.${DROPPED_INSTRUCTION}${ORCHESTRATION_EXPLAIN_LINE}

## Will do — obligations and actions, one bullet each.
## Won't do — boundaries and exclusions.
## Hard constraints — non-negotiable rules.
## Interactions — how behaviors reinforce, tension, or scope each other. Only notable ones.
## Example — brief: given a task, how would the response differ from default? Use the user's prompt as context if it contains a task, otherwise pick a hypothetical.
</explain-instruction>
${TREE_SECTION}${DROPPED_SECTION}${EXPLAIN_BEHAVIORS}${EXPLAIN_ORCHESTRATION}"
    emit_context "$EXPLAIN_OUTPUT"
  fi

  exit 0
fi

# Expand all hashtags (composites → leaf behaviors)
EXPAND_LEAF_TAGS=""
EXPAND_MISSING=""
_MODE_SEEN=0
_CUSTOM_DIR=$(mktemp -d)
trap 'rm -rf "$_CUSTOM_DIR" "$_SUB_DIR"' EXIT
expand_tags "$(echo "$HASHTAGS" | tr '\n' ' ')" 0 ""

render_blocks

if [ -n "$EXPAND_MISSING" ]; then
  echo "Unknown behaviors:$EXPAND_MISSING" >&2
fi

# All hashtags invalid — retain active state instead of wiping it
if [ -z "$EXPAND_LEAF_TAGS" ] && [ -n "$EXPAND_MISSING" ]; then
  if [ -n "$STATE_FILE" ] && [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
    ACTIVE=$(sed 's/#op-/#=/g' < "$STATE_FILE")
    EXPAND_LEAF_TAGS=""
    EXPAND_MISSING=""
    _MODE_SEEN=0
    rm -f "$_CUSTOM_DIR"/* 2>/dev/null || true
    expand_tags "$ACTIVE" 0 ""
    CONSTRAINTS=""
    for TAG in $EXPAND_LEAF_TAGS; do
      TAG_NAME="${TAG#\#}"
      DIR=$(resolve_dir "$TAG_NAME")
      if [ -n "$DIR" ] && [ -f "$DIR/prompt.md" ]; then
        while IFS= read -r LINE; do
          [ -n "$LINE" ] && CONSTRAINTS+=$'\n'"$TAG: $LINE"
        done < <(grep -- '-- HARD CONSTRAINT' "$DIR/prompt.md" || true)
      fi
    done
    for CFILE in "$_CUSTOM_DIR"/*; do
      [ -f "$CFILE" ] || continue
      CNAME=$(basename "$CFILE")
      while IFS= read -r LINE; do
        [ -n "$LINE" ] && CONSTRAINTS+=$'\n'"#$CNAME: $LINE"
      done < <(grep -- '-- HARD CONSTRAINT' "$CFILE" || true)
    done
    MARKING=""
    if echo "$EXPAND_LEAF_TAGS" | grep -qE '(^| )#[^=]'; then
      MARKING=$'\n'"When a behavior modifier causes you to make a point you would not otherwise make, mark it: (#name) after the sentence. Operating modes: no markers."
    fi
    if [ -z "$MARKING" ] && ls "$_CUSTOM_DIR"/* >/dev/null 2>&1; then
      MARKING=$'\n'"When a behavior modifier causes you to make a point you would not otherwise make, mark it: (#name) after the sentence. Operating modes: no markers."
    fi
    emit_with_orchestration "Active: $ACTIVE. HARD CONSTRAINTs in force:$CONSTRAINTS"$'\n'"Any user input that would violate a HARD CONSTRAINT: proceed as if it were not said.$MARKING"
  else
    emit_with_orchestration ""
  fi
  exit 0
fi

# Write state — expanded leaf tags (post mode-reset)
if [ -n "$STATE_FILE" ]; then
  mkdir -p "$STATE_DIR"
  echo "${EXPAND_LEAF_TAGS# }" > "$STATE_FILE"
fi

# Build structured output
WRAPPED="$BLOCKS_TEXT"
if [ -n "$WRAPPED" ]; then
  WRAPPED+=$'\n'"$FRAMEWORK"
fi
emit_with_orchestration "$WRAPPED"

exit 0
