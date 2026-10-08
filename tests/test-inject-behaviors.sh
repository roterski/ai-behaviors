#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_DIR/hooks/inject-behaviors.sh"

TEST_HOME=$(mktemp -d)
export HOME="$TEST_HOME"
STDERR_FILE="$TEST_HOME/stderr"

PASS=0
FAIL=0

cleanup() { rm -rf "$TEST_HOME"; }
trap cleanup EXIT

# --- Helpers ---

invoke() {
  local prompt="${1:-}"
  local session_id="${2:-test-session}"
  local cwd="${3:-}"
  if [ -n "$cwd" ]; then
    jq -n --arg p "$prompt" --arg s "$session_id" --arg c "$cwd" \
      '{prompt: $p, session_id: $s, cwd: $c}' \
      | "$HOOK" 2>"$STDERR_FILE"
  else
    jq -n --arg p "$prompt" --arg s "$session_id" \
      '{prompt: $p, session_id: $s}' \
      | "$HOOK" 2>"$STDERR_FILE"
  fi
}

invoke_no_session() {
  local prompt="$1"
  jq -n --arg p "$prompt" '{prompt: $p}' \
    | "$HOOK" 2>"$STDERR_FILE"
}

context_of() { jq -r '.hookSpecificOutput.additionalContext // empty'; }

reset_state() { rm -rf "$TEST_HOME/.claude/behaviors-state"; }

run_test() {
  reset_state
  : > "$STDERR_FILE"
  printf "  %-55s " "$1"
}

pass() { PASS=$((PASS + 1)); echo "OK"; }

fail() {
  FAIL=$((FAIL + 1))
  echo "FAIL"
  echo "    $1" >&2
}

assert_empty() {
  if [ -n "$1" ]; then
    fail "expected empty output, got: ${1:0:80}"
  else
    pass
  fi
}

assert_contains() {
  if [[ "$1" == *"$2"* ]]; then
    return 0
  else
    fail "expected to contain: $2"
    return 1
  fi
}

assert_not_contains() {
  if [[ "$1" == *"$2"* ]]; then
    fail "expected NOT to contain: $2"
    return 1
  else
    return 0
  fi
}

assert_eq() {
  if [ "$1" = "$2" ]; then
    return 0
  else
    fail "expected '$2', got '$1'"
    return 1
  fi
}

# === Input gating ===

echo "Input gating:"

run_test "empty_prompt_produces_no_output"
OUT=$(invoke "")
assert_empty "$OUT"

run_test "no_hashtags_no_state_produces_no_output"
OUT=$(invoke "hello world")
assert_empty "$OUT"

run_test "no_hashtags_empty_state_file_produces_no_output"
mkdir -p "$TEST_HOME/.claude/behaviors-state"
touch "$TEST_HOME/.claude/behaviors-state/test-session"
OUT=$(invoke "hello world")
assert_empty "$OUT"

# === Validation ===

echo ""
echo "Validation:"

run_test "last_mode_wins_second_mode_resets"
OUT=$(invoke "#=frame #concrete #=research #deep" | context_of)
assert_contains "$OUT" "Investigate. Report findings" && \
  assert_not_contains "$OUT" "Define the problem" && pass

run_test "first_mode_preserves_preceding_modifiers"
invoke "#deep #=research" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_contains "$STATE" "#deep" && \
  assert_contains "$STATE" "#=research" && pass

run_test "second_mode_drops_all_before_it"
invoke "#=frame #concrete #=research #deep" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_not_contains "$STATE" "#=frame" && \
  assert_not_contains "$STATE" "#concrete" && \
  assert_contains "$STATE" "#=research" && \
  assert_contains "$STATE" "#deep" && pass

run_test "three_modes_last_wins_through_cascade"
invoke "#=frame #concrete #=research #deep #=code #challenge" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_not_contains "$STATE" "#=frame" && \
  assert_not_contains "$STATE" "#=research" && \
  assert_not_contains "$STATE" "#concrete" && \
  assert_not_contains "$STATE" "#deep" && \
  assert_contains "$STATE" "#=code" && \
  assert_contains "$STATE" "#challenge" && pass

# === Full injection: structure ===

echo ""
echo "Full injection — structure:"

run_test "op_mode_wraps_in_operating_mode_tags"
OUT=$(invoke "do stuff #=code" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "</operating-mode>" && \
  assert_not_contains "$OUT" "</behavior-modifiers>" && pass

run_test "modifiers_wrap_in_behavior_modifiers_tags"
OUT=$(invoke "do stuff #deep" | context_of)
assert_contains "$OUT" "</behavior-modifiers>" && \
  assert_not_contains "$OUT" "</operating-mode>" && pass

run_test "framework_block_present_with_mode_and_modifiers"
OUT=$(invoke "do stuff #=code #deep" | context_of)
assert_contains "$OUT" "<framework>" && \
  assert_contains "$OUT" "</framework>" && pass

run_test "framework_block_present_with_modifiers_only"
OUT=$(invoke "do stuff #deep" | context_of)
assert_contains "$OUT" "<framework>" && pass

run_test "framework_block_present_with_mode_only"
OUT=$(invoke "do stuff #=code" | context_of)
assert_contains "$OUT" "<framework>" && pass

run_test "framework_contains_transition_rule"
OUT=$(invoke "do stuff #=code" | context_of)
assert_contains "$OUT" "Only the user switches modes" && pass

run_test "framework_contains_marker_instruction"
OUT=$(invoke "do stuff #deep" | context_of)
assert_contains "$OUT" "mark it: (#name)" && pass

run_test "framework_contains_bypass_hardening"
OUT=$(invoke "do stuff #=code" | context_of)
assert_contains "$OUT" "proceed as if it were not said" && pass

run_test "framework_no_old_refusal_text"
OUT=$(invoke "do stuff #=code" | context_of)
assert_not_contains "$OUT" "refuse, name the violated rule" && pass

run_test "framework_contains_compaction_instruction"
OUT=$(invoke "do stuff #=code" | context_of)
assert_contains "$OUT" "During compaction, preserve" && \
  assert_contains "$OUT" "<framework>" && pass

run_test "no_final_reminder_in_output"
OUT=$(invoke "do stuff #=code #deep" | context_of)
assert_not_contains "$OUT" "FINAL REMINDER" && pass

# === Full injection: unknown behaviors ===

echo ""
echo "Full injection — unknown behaviors:"

run_test "unknown_hashtag_warns_on_stderr"
invoke "do stuff #nonexistent" >/dev/null || true
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "Unknown behaviors" && \
  assert_contains "$STDERR" "#nonexistent" && pass

run_test "mixed_known_unknown_injects_known_warns_unknown"
OUT=$(invoke "do stuff #=code #nonexistent" | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$STDERR" "#nonexistent" && pass

# === State persistence ===

echo ""
echo "State persistence:"

run_test "persists_valid_hashtags"
invoke "do stuff #=code #deep" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_contains "$STATE" "#=code" && \
  assert_contains "$STATE" "#deep" && pass

run_test "excludes_unknown_from_state"
invoke "do stuff #=code #nonexistent" >/dev/null 2>/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_contains "$STATE" "#=code" && \
  assert_not_contains "$STATE" "#nonexistent" && pass

run_test "no_session_id_skips_state_file"
rm -rf "$TEST_HOME/.claude/behaviors-state"
invoke_no_session "do stuff #=code" >/dev/null
if [ -d "$TEST_HOME/.claude/behaviors-state" ]; then
  fail "state dir should not exist"
else
  pass
fi

# === Continuation path ===

echo ""
echo "Continuation path:"

run_test "continuation_attributes_constraints_to_hashtags"
invoke "do stuff #=code #deep" >/dev/null
OUT=$(invoke "next question" | context_of)
assert_contains "$OUT" "Active: " && \
  assert_contains "$OUT" "HARD CONSTRAINTs in force:" && \
  assert_contains "$OUT" "#=code:" && \
  assert_contains "$OUT" "#deep:" && pass

run_test "continuation_includes_constraint_text"
invoke "do stuff #=code" >/dev/null
OUT=$(invoke "next question" | context_of)
assert_contains "$OUT" "-- HARD CONSTRAINT" && pass

run_test "continuation_skips_deleted_behavior"
invoke "do stuff #=code" >/dev/null
echo "#=code #deleted-fake" > "$TEST_HOME/.claude/behaviors-state/test-session"
OUT=$(invoke "next question" | context_of)
assert_contains "$OUT" "#=code:" && \
  assert_not_contains "$OUT" "#deleted-fake:" && pass

run_test "continuation_migrates_op_prefix_in_state"
reset_state
mkdir -p "$TEST_HOME/.claude/behaviors-state"
echo "#op-code #deep" > "$TEST_HOME/.claude/behaviors-state/test-session"
OUT=$(invoke "next question" | context_of)
assert_contains "$OUT" "#=code:" && \
  assert_contains "$OUT" "#deep:" && pass

run_test "continuation_with_modifiers_includes_marker_instruction"
invoke "do stuff #=code #deep" >/dev/null
OUT=$(invoke "next question" | context_of)
assert_contains "$OUT" "mark it: (#name)" && pass

run_test "continuation_contains_bypass_hardening"
invoke "do stuff #=code #deep" >/dev/null
OUT=$(invoke "next question" | context_of)
assert_contains "$OUT" "proceed as if it were not said" && pass

run_test "continuation_mode_only_still_has_constraints"
invoke "do stuff #=code" >/dev/null
OUT=$(invoke "next question" | context_of)
assert_contains "$OUT" "HARD CONSTRAINT" && pass

# === Local behaviors search ===

echo ""
echo "Local behaviors search:"

LOCAL_PROJECT="$TEST_HOME/project"
git init -q "$LOCAL_PROJECT"

run_test "local_behavior_takes_precedence_over_repo"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/deep"
echo "LOCAL-DEEP-UNIQUE-CONTENT" > "$LOCAL_PROJECT/.ai-behaviors/deep/prompt.md"
OUT=$(invoke "do stuff #deep" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "LOCAL-DEEP-UNIQUE-CONTENT" && pass

run_test "repo_behavior_used_when_local_dir_absent"
rm -rf "$LOCAL_PROJECT/.ai-behaviors"
OUT=$(invoke "do stuff #deep" test-session "$LOCAL_PROJECT" | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_contains "$OUT" "<behavior-modifiers>" && \
  assert_not_contains "$STDERR" "Unknown behaviors" && pass

run_test "repo_behavior_used_when_tag_absent_from_local_dir"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/other"
echo "other content" > "$LOCAL_PROJECT/.ai-behaviors/other/prompt.md"
OUT=$(invoke "do stuff #deep" test-session "$LOCAL_PROJECT" | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_not_contains "$OUT" "other content" && \
  assert_contains "$OUT" "<behavior-modifiers>" && \
  assert_not_contains "$STDERR" "Unknown behaviors" && pass

run_test "no_cwd_in_input_uses_repo_only_no_error"
OUT=$(invoke "do stuff #deep" | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_contains "$OUT" "<behavior-modifiers>" && \
  assert_not_contains "$STDERR" "Unknown behaviors" && pass

# === User-local behaviors search ===

echo ""
echo "User-local behaviors search:"

USER_BEHAVIORS="$TEST_HOME/.config/ai-behaviors/behaviors"

run_test "user_local_behavior_resolves"
mkdir -p "$USER_BEHAVIORS/ulocal-test"
echo "ULOCAL-UNIQUE-CONTENT" > "$USER_BEHAVIORS/ulocal-test/prompt.md"
OUT=$(invoke "do stuff #ulocal-test" | context_of)
rm -rf "$USER_BEHAVIORS/ulocal-test"
assert_contains "$OUT" "ULOCAL-UNIQUE-CONTENT" && pass

run_test "project_local_beats_user_local"
mkdir -p "$USER_BEHAVIORS/precedence-test"
echo "USER-LOCAL-CONTENT" > "$USER_BEHAVIORS/precedence-test/prompt.md"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/precedence-test"
echo "PROJECT-LOCAL-CONTENT" > "$LOCAL_PROJECT/.ai-behaviors/precedence-test/prompt.md"
OUT=$(invoke "do stuff #precedence-test" test-session "$LOCAL_PROJECT" | context_of)
rm -rf "$USER_BEHAVIORS/precedence-test" "$LOCAL_PROJECT/.ai-behaviors/precedence-test"
assert_contains "$OUT" "PROJECT-LOCAL-CONTENT" && \
  assert_not_contains "$OUT" "USER-LOCAL-CONTENT" && pass

run_test "user_local_beats_repo"
mkdir -p "$USER_BEHAVIORS/deep"
echo "USER-LOCAL-DEEP-OVERRIDE" > "$USER_BEHAVIORS/deep/prompt.md"
OUT=$(invoke "do stuff #deep" | context_of)
rm -rf "$USER_BEHAVIORS/deep"
assert_contains "$OUT" "USER-LOCAL-DEEP-OVERRIDE" && pass

run_test "user_local_composite_expands_repo_behaviors"
mkdir -p "$USER_BEHAVIORS/ulocal-macro"
echo "#=code #deep" > "$USER_BEHAVIORS/ulocal-macro/compose"
OUT=$(invoke "do stuff #ulocal-macro" | context_of)
rm -rf "$USER_BEHAVIORS/ulocal-macro"
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "<behavior-modifiers>" && pass

run_test "xdg_config_home_override"
XDG_ALT="$TEST_HOME/custom-xdg"
mkdir -p "$XDG_ALT/ai-behaviors/behaviors/xdg-test"
echo "XDG-OVERRIDE-CONTENT" > "$XDG_ALT/ai-behaviors/behaviors/xdg-test/prompt.md"
OUT=$(XDG_CONFIG_HOME="$XDG_ALT" invoke "do stuff #xdg-test" | context_of)
rm -rf "$XDG_ALT"
assert_contains "$OUT" "XDG-OVERRIDE-CONTENT" && pass

# === Word boundary (S2) ===

echo ""
echo "Word boundary:"

run_test "hashtag_in_url_not_captured"
OUT=$(invoke "see https://example.com#deep for info" | context_of)
assert_empty "$OUT"

run_test "hashtag_after_space_captured"
OUT=$(invoke "do stuff #deep" | context_of)
assert_contains "$OUT" "<behavior-modifiers>" && pass

run_test "hashtag_at_start_of_prompt_captured"
OUT=$(invoke "#deep do stuff" | context_of)
assert_contains "$OUT" "<behavior-modifiers>" && pass

# === Order preservation (S3) ===

echo ""
echo "Order preservation:"

run_test "modifier_order_preserved_in_state"
invoke "do stuff #wide #deep #challenge" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_eq "$STATE" "#wide #deep #challenge" && pass

run_test "mode_preserves_input_order_in_state"
invoke "do stuff #wide #=code #deep" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_eq "$STATE" "#wide #=code #deep" && pass

# === CLEAR (S7) ===

echo ""
echo "CLEAR:"

run_test "clear_empties_state"
invoke "do stuff #=code #deep" >/dev/null
invoke "#CLEAR" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_eq "$STATE" "" && pass

run_test "clear_produces_no_output"
invoke "do stuff #=code #deep" >/dev/null
OUT=$(invoke "#CLEAR")
assert_empty "$OUT"

run_test "clear_with_other_hashtags_exits_2"
invoke "#CLEAR #deep" >/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "#CLEAR" && \
  assert_eq "$EXIT_CODE" "2" && pass

run_test "continuation_after_clear_produces_no_output"
invoke "do stuff #=code #deep" >/dev/null
invoke "#CLEAR" >/dev/null
OUT=$(invoke "next question")
assert_empty "$OUT"

run_test "lowercase_clear_not_treated_as_clear"
OUT=$(invoke "#clear" 2>/dev/null | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "Unknown behaviors" && pass

# === EXPLAIN ===

echo ""
echo "EXPLAIN:"

run_test "explain_with_companions_produces_explain_output"
OUT=$(invoke "#EXPLAIN #=code #deep" | context_of)
assert_contains "$OUT" "<explain-instruction>" && \
  assert_contains "$OUT" "<explain-behaviors>" && pass

run_test "explain_contains_behavior_content_in_labeled_tags"
OUT=$(invoke "#EXPLAIN #=code #deep" | context_of)
assert_contains "$OUT" 'name="#=code"' && \
  assert_contains "$OUT" 'role="mode"' && \
  assert_contains "$OUT" 'name="#deep"' && \
  assert_contains "$OUT" 'role="modifier"' && pass

run_test "explain_does_not_use_active_directive_tags"
OUT=$(invoke "#EXPLAIN #=code #deep" | context_of)
assert_not_contains "$OUT" "<operating-mode>" && \
  assert_not_contains "$OUT" "<behavior-modifiers>" && pass

run_test "explain_alone_reads_from_state"
invoke "#=code #deep" >/dev/null
OUT=$(invoke "#EXPLAIN" | context_of)
assert_contains "$OUT" "<explain-instruction>" && \
  assert_contains "$OUT" 'name="#=code"' && \
  assert_contains "$OUT" 'name="#deep"' && pass

run_test "explain_alone_no_state_exits_2"
invoke "#EXPLAIN" >/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "No active behaviors to explain" && \
  assert_eq "$EXIT_CODE" "2" && pass

run_test "explain_does_not_write_state"
invoke "#=code #deep" >/dev/null
STATE_BEFORE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
invoke "#EXPLAIN #=frame" >/dev/null
STATE_AFTER=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_eq "$STATE_AFTER" "$STATE_BEFORE" && pass

run_test "explain_last_mode_wins"
OUT=$(invoke "#EXPLAIN #=code #=design" | context_of)
assert_contains "$OUT" "<explain-instruction>" && \
  assert_contains "$OUT" 'name="#=design"' && \
  assert_not_contains "$OUT" 'name="#=code"' && pass

run_test "explain_dropped_composite_shown_in_dropped_section"
OUT=$(invoke "#EXPLAIN #Frame #Code" | context_of)
assert_contains "$OUT" "<dropped-by-mode-resolution>" && \
  assert_contains "$OUT" "#Frame" && \
  assert_contains "$OUT" "#=frame" && \
  assert_contains "$OUT" "#=code" && \
  assert_contains "$OUT" "#Code" && pass

run_test "explain_bare_mode_dropped_shown_in_dropped_section"
OUT=$(invoke "#EXPLAIN #=frame #=code #deep" | context_of)
assert_contains "$OUT" "<dropped-by-mode-resolution>" && \
  assert_contains "$OUT" "#=frame" && \
  assert_contains "$OUT" 'name="#=code"' && \
  assert_contains "$OUT" 'name="#deep"' && pass

run_test "explain_no_drops_no_dropped_section"
OUT=$(invoke "#EXPLAIN #=code #deep" | context_of)
assert_not_contains "$OUT" "<dropped-by-mode-resolution>" && pass

run_test "explain_instruction_mentions_dropped_resolution"
OUT=$(invoke "#EXPLAIN #Frame #Code" | context_of)
assert_contains "$OUT" "dropped-by-mode-resolution" && \
  assert_contains "$OUT" "explain which" && pass

run_test "explain_with_unknown_warns_and_explains_known"
OUT=$(invoke "#EXPLAIN #=code #nonexistent" | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_contains "$OUT" 'name="#=code"' && \
  assert_contains "$STDERR" "#nonexistent" && pass

run_test "explain_prompt_contains_output_sections"
OUT=$(invoke "#EXPLAIN #=code" | context_of)
assert_contains "$OUT" "Will do" && \
  assert_contains "$OUT" "Won't do" && \
  assert_contains "$OUT" "Hard constraints" && \
  assert_contains "$OUT" "Interactions" && \
  assert_contains "$OUT" "Example" && pass

run_test "explain_modifiers_only_no_mode_tag"
OUT=$(invoke "#EXPLAIN #deep #challenge" | context_of)
assert_contains "$OUT" 'name="#deep"' && \
  assert_contains "$OUT" 'name="#challenge"' && \
  assert_not_contains "$OUT" 'role="mode"' && pass

run_test "lowercase_explain_not_treated_as_explain"
OUT=$(invoke "#explain #deep" 2>/dev/null | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_not_contains "$OUT" "<explain-instruction>" && \
  assert_contains "$STDERR" "Unknown behaviors" && pass

run_test "clear_with_explain_exits_2"
invoke "#CLEAR #EXPLAIN" >/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "#CLEAR" && \
  assert_eq "$EXIT_CODE" "2" && pass

# === Composite tests ===

echo ""
echo "Composite expansion:"

# Setup test composite directories
rm -rf "$LOCAL_PROJECT/.ai-behaviors"

# Pure macro (T1)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-macro"
echo "#=code #deep" > "$LOCAL_PROJECT/.ai-behaviors/test-macro/compose"

# Composite with custom text (T2)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-custom"
echo "#deep #challenge" > "$LOCAL_PROJECT/.ai-behaviors/test-custom/compose"
cat > "$LOCAL_PROJECT/.ai-behaviors/test-custom/prompt.md" << 'EOF'
# #test-custom — Test Custom Composite
UNIQUE-CUSTOM-PERSONA-CONTENT-XYZ
EOF

# Nested (T3)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-inner"
echo "#=review #deep" > "$LOCAL_PROJECT/.ai-behaviors/test-inner/compose"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-outer"
echo "#test-inner #challenge" > "$LOCAL_PROJECT/.ai-behaviors/test-outer/compose"

# Cycle (T4)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-cycle-a"
echo "#test-cycle-b" > "$LOCAL_PROJECT/.ai-behaviors/test-cycle-a/compose"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-cycle-b"
echo "#test-cycle-a" > "$LOCAL_PROJECT/.ai-behaviors/test-cycle-b/compose"

# Deep nesting — 9 levels to exceed depth 8 (T5)
for i in $(seq 1 9); do
  mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-depth-$i"
  if [ "$i" -lt 9 ]; then
    echo "#test-depth-$((i+1))" > "$LOCAL_PROJECT/.ai-behaviors/test-depth-$i/compose"
  else
    echo "#deep" > "$LOCAL_PROJECT/.ai-behaviors/test-depth-$i/compose"
  fi
done

# Unknown in compose (T6)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-with-unknown"
echo "#=code #nonexistent-xyz-test" > "$LOCAL_PROJECT/.ai-behaviors/test-with-unknown/compose"

# Empty compose (T7)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-empty-compose"
touch "$LOCAL_PROJECT/.ai-behaviors/test-empty-compose/compose"

# Mode-bearing composites for conflict tests (T10, T11)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-mode-a"
echo "#=code #deep" > "$LOCAL_PROJECT/.ai-behaviors/test-mode-a/compose"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-mode-b"
echo "#=review #challenge" > "$LOCAL_PROJECT/.ai-behaviors/test-mode-b/compose"

# Composite with HARD CONSTRAINT in custom text (T14)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-constrained"
echo "#deep" > "$LOCAL_PROJECT/.ai-behaviors/test-constrained/compose"
cat > "$LOCAL_PROJECT/.ai-behaviors/test-constrained/prompt.md" << 'EOF'
# #test-constrained — Constrained Composite
test-constrained :: always verify    -- HARD CONSTRAINT
EOF

# --- T1: Pure macro expands ---
run_test "composite_pure_macro_expands"
OUT=$(invoke "#test-macro" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "<behavior-modifiers>" && pass

# --- T2: Custom text in modifiers alongside composed behaviors ---
run_test "composite_custom_text_in_modifiers"
OUT=$(invoke "#test-custom" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "UNIQUE-CUSTOM-PERSONA-CONTENT-XYZ" && \
  assert_contains "$OUT" "Go beneath the surface" && \
  assert_contains "$OUT" "counterargument" && pass

# --- T3: Nested composite fully expands ---
run_test "nested_composite_expands"
OUT=$(invoke "#test-outer" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "<behavior-modifiers>" && pass

# --- T4: Cycle detected ---
run_test "composite_cycle_detected"
invoke "#test-cycle-a" test-session "$LOCAL_PROJECT" >/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "Cycle" && \
  assert_eq "$EXIT_CODE" "2" && pass

# --- T5: Depth limit exceeded ---
run_test "composite_depth_limit_exceeded"
invoke "#test-depth-1" test-session "$LOCAL_PROJECT" >/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "depth" && \
  assert_eq "$EXIT_CODE" "2" && pass

# --- T6: Unknown in compose warns, expands known ---
run_test "composite_unknown_in_compose_warns"
OUT=$(invoke "#test-with-unknown" test-session "$LOCAL_PROJECT" | context_of)
STDERR=$(cat "$STDERR_FILE")
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$STDERR" "#nonexistent-xyz-test" && pass

# --- T7: Empty compose errors ---
run_test "composite_empty_compose_errors"
invoke "#test-empty-compose" test-session "$LOCAL_PROJECT" >/dev/null && EXIT_CODE=$? || EXIT_CODE=$?
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "Empty compose" && \
  assert_eq "$EXIT_CODE" "2" && pass

# --- T8: Stacking composite + extra modifier ---
run_test "composite_stacked_with_extra_modifier"
OUT=$(invoke "#test-macro #challenge" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "Write production code" && \
  assert_contains "$OUT" "counterargument" && pass

# --- T9: Duplicate deduplicated ---
run_test "composite_duplicate_deduplicated"
OUT=$(invoke "#test-macro #deep" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "Write production code" && \
  COUNT=$(grep -o "Go beneath the surface" <<< "$OUT" | wc -l | tr -d ' ') && \
  assert_eq "$COUNT" "1" && pass

# --- T10: Composite mode + explicit mode = last wins ---
run_test "composite_mode_plus_explicit_mode_last_wins"
OUT=$(invoke "#test-mode-a #=review" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "Review code. Find issues" && \
  assert_not_contains "$OUT" "Write production code" && pass

# --- T11: Two mode composites = last wins ---
run_test "two_mode_composites_last_wins"
OUT=$(invoke "#test-mode-a #test-mode-b" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "Review code. Find issues" && \
  assert_not_contains "$OUT" "Write production code" && pass

# --- T12: Composite with mode + extra modifiers = ok ---
run_test "composite_mode_with_extra_modifiers_ok"
OUT=$(invoke "#test-mode-a #challenge" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "Write production code" && \
  assert_contains "$OUT" "counterargument" && pass

# --- T13: State stores expanded leaf tags ---
run_test "state_stores_expanded_leaf_tags"
invoke "#test-macro #challenge" test-session "$LOCAL_PROJECT" >/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_contains "$STATE" "#=code" && \
  assert_contains "$STATE" "#deep" && \
  assert_contains "$STATE" "#challenge" && \
  assert_not_contains "$STATE" "#test-macro" && pass

# --- T14: Continuation with expanded state ---
run_test "continuation_with_expanded_state"
invoke "#test-constrained" test-session "$LOCAL_PROJECT" >/dev/null
OUT=$(invoke "next question" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "Active: #deep" && \
  assert_contains "$OUT" "#deep:" && pass

# --- T15: EXPLAIN composite shows tree ---
run_test "explain_composite_shows_tree"
OUT=$(invoke "#EXPLAIN #test-outer" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<expansion-tree>" && \
  assert_contains "$OUT" "#test-outer" && \
  assert_contains "$OUT" "#test-inner" && pass

# --- T16: EXPLAIN with expanded leaf state ---
run_test "explain_active_expanded_from_state"
invoke "#test-macro" test-session "$LOCAL_PROJECT" >/dev/null
OUT=$(invoke "#EXPLAIN" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<explain-instruction>" && \
  assert_contains "$OUT" 'name="#=code"' && \
  assert_contains "$OUT" 'name="#deep"' && pass

# --- T19: Local composite overrides repo ---
run_test "local_composite_overrides_repo"
mkdir -p "$REPO_DIR/behaviors/test-override-zzz"
echo "#deep" > "$REPO_DIR/behaviors/test-override-zzz/compose"
echo "REPO-OVERRIDE-ZZZ" > "$REPO_DIR/behaviors/test-override-zzz/prompt.md"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-override-zzz"
echo "#deep" > "$LOCAL_PROJECT/.ai-behaviors/test-override-zzz/compose"
echo "LOCAL-OVERRIDE-ZZZ" > "$LOCAL_PROJECT/.ai-behaviors/test-override-zzz/prompt.md"
OUT=$(invoke "#test-override-zzz" test-session "$LOCAL_PROJECT" | context_of)
rm -rf "$REPO_DIR/behaviors/test-override-zzz"
assert_contains "$OUT" "LOCAL-OVERRIDE-ZZZ" && \
  assert_not_contains "$OUT" "REPO-OVERRIDE-ZZZ" && \
  assert_contains "$OUT" "Go beneath the surface" && pass

# --- T20: Local composite composes repo behaviors ---
run_test "local_composite_composes_repo_behaviors"
OUT=$(invoke "#test-macro" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "<behavior-modifiers>" && pass

# === All-invalid hashtags retain state ===

echo ""
echo "All-invalid hashtags retain state:"

# Composite whose children are all nonexistent (T24)
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-all-unknown-compose"
echo "#nonexistent-aaa #nonexistent-bbb" > "$LOCAL_PROJECT/.ai-behaviors/test-all-unknown-compose/compose"
echo "COMPOSITE-OWN-TEXT" > "$LOCAL_PROJECT/.ai-behaviors/test-all-unknown-compose/prompt.md"

run_test "all_invalid_retains_active_state"
invoke "#=frame #concrete" >/dev/null
invoke "here is some JVM output #xyzfake1 #xyzfake2" >/dev/null 2>/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_contains "$STATE" "#=frame" && \
  assert_contains "$STATE" "#concrete" && pass

run_test "all_invalid_warns_on_stderr"
invoke "#=frame #concrete" >/dev/null
invoke "here is some JVM output #xyzfake1 #xyzfake2" >/dev/null
STDERR=$(cat "$STDERR_FILE")
assert_contains "$STDERR" "Unknown behaviors" && \
  assert_contains "$STDERR" "#xyzfake1" && pass

run_test "all_invalid_reinjects_active_behaviors"
invoke "#=frame #concrete" >/dev/null
OUT=$(invoke "here is some JVM output #xyzfake1 #xyzfake2" | context_of)
assert_contains "$OUT" "Active:" && \
  assert_contains "$OUT" "#=frame" && \
  assert_contains "$OUT" "#concrete" && pass

run_test "all_invalid_no_prior_state_no_output"
OUT=$(invoke "some text #xyzfake1" 2>/dev/null)
STDERR=$(cat "$STDERR_FILE")
assert_eq "$OUT" "" && \
  assert_contains "$STDERR" "Unknown behaviors" && pass

run_test "all_invalid_composite_retains_state"
invoke "#=code #deep" test-session "$LOCAL_PROJECT" >/dev/null
invoke "#test-all-unknown-compose" test-session "$LOCAL_PROJECT" >/dev/null 2>/dev/null
STATE=$(cat "$TEST_HOME/.claude/behaviors-state/test-session")
assert_contains "$STATE" "#=code" && \
  assert_contains "$STATE" "#deep" && pass

# === Mode transition suggests composites ===

echo ""
echo "Mode transition suggests composites:"

run_test "mode_transition_suggests_composite_name"
OUT=$(invoke "#Frame" | context_of)
assert_contains "$OUT" "#Research" && pass

# === Route catalog ===

echo ""
echo "Route catalog:"

mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf"
cat > "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/prompt.md" << 'EOT'
# #test-catalog-leaf — Something Else Entirely

UNIQUE-CATALOG-TAGLINE-XYZ
Second line never shown.
EOT

run_test "route_injects_catalog"
OUT=$(invoke "#Route" | context_of)
assert_contains "$OUT" "<behavior-catalog>" && \
  assert_contains "$OUT" "Recommend only from this catalog." && pass

run_test "catalog_inside_operating_mode_after_route"
OUT=$(invoke "#Route" | context_of)
BETWEEN="${OUT#*# #=route — Route}"
BETWEEN="${BETWEEN%%</operating-mode>*}"
assert_contains "$BETWEEN" "</behavior-catalog>" && pass

run_test "no_catalog_without_marker"
OUT=$(invoke "#=code #deep" | context_of)
assert_not_contains "$OUT" "<behavior-catalog>" && pass

run_test "frame_unchanged_by_route"
OUT=$(invoke "#Frame" | context_of)
assert_not_contains "$OUT" "<behavior-catalog>" && \
  assert_contains "$OUT" "⊣ {#Research}" && pass

run_test "catalog_groups_modes_composites_modifiers"
OUT=$(invoke "#Route" | context_of)
assert_contains "$OUT" $'## Modes\n#=code — Write production code. Ship working software.' && \
  assert_contains "$OUT" $'## Composites\n#Code → #=code' && \
  assert_contains "$OUT" "#Route → #=route #coherence #legible #concise" && \
  assert_contains "$OUT" "#challenge — Find the flaws. Nothing gets a free pass." && pass

run_test "catalog_prefixes_title_that_differs_from_name"
OUT=$(invoke "#Route" | context_of)
assert_contains "$OUT" "#ct — Category Theory: Name the categorical structure." && \
  assert_contains "$OUT" "#deep — Go beneath the surface." && pass

run_test "catalog_includes_project_local_behaviors"
OUT=$(invoke "#Route" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "#test-catalog-leaf — Something Else Entirely: UNIQUE-CATALOG-TAGLINE-XYZ" && \
  assert_contains "$OUT" "#test-macro → #=code #deep" && \
  assert_not_contains "$OUT" "Second line never shown." && pass

run_test "catalog_lists_shadowed_behavior_once"
OUT=$(invoke "#Route" test-session "$LOCAL_PROJECT" | context_of)
COUNT=$(grep -c '^#deep ' <<< "$OUT" || true)
assert_eq "$COUNT" "1" && pass

run_test "explain_route_omits_catalog"
OUT=$(invoke "#EXPLAIN #Route" | context_of)
assert_contains "$OUT" "<explain-behaviors>" && \
  assert_not_contains "$OUT" "Recommend only from this catalog." && pass

touch "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/catalog"

run_test "catalog_marker_on_modifier"
OUT=$(invoke "#=code #test-catalog-leaf" test-session "$LOCAL_PROJECT" | context_of)
BETWEEN="${OUT#*<behavior-modifiers>}"
BETWEEN="${BETWEEN%%</behavior-modifiers>*}"
assert_contains "$BETWEEN" "<behavior-catalog>" && pass

rm "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/catalog"

mkdir -p "$LOCAL_PROJECT/.ai-behaviors/=route"
cp "$REPO_DIR/behaviors/=route/prompt.md" "$LOCAL_PROJECT/.ai-behaviors/=route/prompt.md"

run_test "shadow_without_marker_drops_catalog"
OUT=$(invoke "#=route" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "# #=route — Route" && \
  assert_not_contains "$OUT" "Recommend only from this catalog." && pass

rm -rf "$LOCAL_PROJECT/.ai-behaviors/=route"

mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-crlf"
printf '# #test-crlf — Carriage Return\r\n\r\nCRLF-TAGLINE\r\n' > "$LOCAL_PROJECT/.ai-behaviors/test-crlf/prompt.md"

run_test "catalog_line_from_crlf_prompt"
OUT=$(invoke "#Route" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" $'\n#test-crlf — Carriage Return: CRLF-TAGLINE\n' && pass

rm -rf "$LOCAL_PROJECT/.ai-behaviors/test-crlf"
touch "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/catalog"

run_test "catalog_once_when_several_marked"
OUT=$(invoke "#Route #test-catalog-leaf" test-session "$LOCAL_PROJECT" | context_of)
COUNT=$(grep -c 'Recommend only from this catalog.' <<< "$OUT" || true)
BETWEEN="${OUT#*<operating-mode>}"
BETWEEN="${BETWEEN%%</operating-mode>*}"
assert_eq "$COUNT" "1" && \
  assert_contains "$BETWEEN" "Recommend only from this catalog." && pass

rm "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/catalog"

# === Shipped composites ===

echo ""
echo "Shipped composites:"

# Every tag in compose resolves and injects its tagline (catches typos in compose)
for COMPOSITE in Collate Converge Spike Stepback; do
  run_test "shipped_${COMPOSITE}_injects_every_leaf"
  OUT=$(invoke "#$COMPOSITE" | context_of)
  STDERR=$(cat "$STDERR_FILE")
  OK=1
  for TAG in $(cat "$REPO_DIR/behaviors/$COMPOSITE/compose"); do
    TAGLINE=$(sed -n 2p "$REPO_DIR/behaviors/${TAG#\#}/prompt.md" 2>/dev/null || true)
    if [ -z "$TAGLINE" ] || [[ "$OUT" != *"$TAGLINE"* ]]; then
      fail "$TAG tagline missing from #$COMPOSITE"
      OK=0
      break
    fi
  done
  [ "$OK" -eq 1 ] && assert_not_contains "$STDERR" "Unknown behaviors" && pass
done

run_test "spike_mode_injects_contract"
OUT=$(invoke "#=spike" | context_of)
assert_contains "$OUT" "# #=spike — Spike" && \
  assert_contains "$OUT" "ProjectChangeBeyondFinding" && \
  assert_contains "$OUT" "when halted ⊣ {the user's ruling}" && \
  assert_contains "$OUT" "never empty" && \
  assert_not_contains "$OUT" "ai/spike/" && pass

run_test "scratch_injects_workspace_rules"
OUT=$(invoke "#scratch" | context_of)
assert_contains "$OUT" "LeftoverScratch" && \
  assert_contains "$OUT" "containing \`*/\` and \`.gitignore\`" && \
  assert_contains "$OUT" "git status --porcelain -uall" && pass

run_test "finding_injects_section_rules"
OUT=$(invoke "#finding" | context_of)
assert_contains "$OUT" "OverwrittenSection" && \
  assert_contains "$OUT" "PostHocPrediction" && \
  assert_contains "$OUT" "or halted, which settles nothing" && pass

run_test "collate_does_not_suggest_spike"
OUT=$(invoke "#Collate" | context_of)
assert_contains "$OUT" "suggest /clear, then #Converge" && \
  assert_not_contains "$OUT" "#Spike" && pass

run_test "converge_crux_names_both_routes"
OUT=$(invoke "#=converge" | context_of)
assert_contains "$OUT" "<ledger dir>/<slug>.finding.md" && \
  assert_contains "$OUT" "when Crux ⊣ {#Research, #Spike}" && \
  assert_contains "$OUT" "read (research suffices, by reading or quick probes of existing code)" && \
  assert_contains "$OUT" "every command embedded in a prompt is wrapped in backticks" && \
  assert_contains "$OUT" "If its section leaves the question unsettled: \`<run command>\`" && \
  assert_contains "$OUT" "run → #Spike <question> → <path>, then <tail>." && \
  assert_contains "$OUT" "settle <other slugs>, and once all findings exist, \`<collate command>\`" && \
  assert_contains "$OUT" "lineage: <restated from the ledger's Sources>; findings independent" && \
  assert_contains "$OUT" "if it exists, append -2" && \
  assert_contains "$OUT" "with one Crux, just the backticked collate command" && pass

run_test "spike_contracts_survive_second_turn"
invoke "#Spike" >/dev/null
OUT=$(invoke "run the experiment" | context_of)
assert_contains "$OUT" "when halted ⊣ {the user's ruling}" && \
  assert_contains "$OUT" "LeftoverScratch" && \
  assert_contains "$OUT" "OverwrittenSection" && pass

run_test "backticked_hashtag_is_inert"
OUT=$(invoke "#Spike q → p, then \`#Collate a into b\`" | context_of)
assert_contains "$OUT" "# #=spike — Spike" && \
  assert_not_contains "$OUT" "# #=research — Research" && \
  assert_not_contains "$OUT" "# #ledger — Ledger" && pass

run_test "stepback_mode_injects_contract"
OUT=$(invoke "#=stepback" | context_of)
assert_contains "$OUT" "# #=stepback — Step Back" && \
  assert_contains "$OUT" "ContinuingCurrentLine" && \
  assert_contains "$OUT" "If none changes the goal, say why" && \
  assert_contains "$OUT" "else #Research, or #Spike" && \
  assert_contains "$OUT" "never a session scratchpad or temp directory" && \
  assert_contains "$OUT" "never ask the user to edit the file" && pass

run_test "stepback_contract_survives_second_turn"
invoke "#Stepback" >/dev/null
OUT=$(invoke "these framings don't fit" | context_of)
assert_contains "$OUT" "ContinuingCurrentLine" && \
  assert_contains "$OUT" "the fresh-session handoff" && pass

run_test "stepback_handoff_lines_activate"
OUT=$(invoke "#Stepback #file notes/stuck.md" | context_of)
assert_contains "$OUT" "# #=stepback — Step Back" && \
  assert_contains "$OUT" "# #file — File" && pass

run_test "stepback_path_prompt_injects_section_rules"
OUT=$(invoke "#Stepback notes/stuck.md" | context_of)
assert_contains "$OUT" "Given a \`# Step Back\` section" && \
  assert_contains "$OUT" "the mode it records is the prior mode" && \
  assert_contains "$OUT" "the file the step-back was given, if any" && \
  assert_not_contains "$OUT" "# #file — File" && pass

run_test "route_catalog_lists_stepback"
OUT=$(invoke "#Route" | context_of)
assert_contains "$OUT" "#=stepback — Leave the current line." && \
  assert_contains "$OUT" "#Stepback → #=stepback #coherence #legible #concise" && pass

run_test "assumptions_injects_contract"
OUT=$(invoke "#assumptions" | context_of)
assert_contains "$OUT" "# #assumptions — Assumptions" && \
  assert_contains "$OUT" "SilentChoice" && \
  assert_contains "$OUT" "RestatedCode" && \
  assert_contains "$OUT" "never restate the code" && pass

run_test "proceed_records_without_assumptions"
OUT=$(invoke "#proceed" | context_of)
assert_contains "$OUT" "# #proceed — Proceed" && \
  assert_contains "$OUT" "IrreversibleOnAssumption" && \
  assert_contains "$OUT" "SilentChoice" && \
  assert_contains "$OUT" "never restate the code" && \
  assert_not_contains "$OUT" "# #assumptions — Assumptions" && pass

run_test "proceed_keeps_the_mode"
OUT=$(invoke "#Code #proceed" | context_of)
assert_contains "$OUT" "# #=code — Code" && \
  assert_contains "$OUT" "# #proceed — Proceed" && pass

run_test "proceed_survives_second_turn"
invoke "#Code #proceed" >/dev/null
OUT=$(invoke "next step" | context_of)
assert_contains "$OUT" "HaltOnChoice" && pass

run_test "proceed_and_assumptions_share_record_format"
assert_eq "$(grep '^End of response' "$REPO_DIR/behaviors/assumptions/prompt.md")" \
  "$(grep '^End of response' "$REPO_DIR/behaviors/proceed/prompt.md")" && pass

# === Summary ===

echo ""
TOTAL=$((PASS + FAIL))
echo "$PASS/$TOTAL passed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
