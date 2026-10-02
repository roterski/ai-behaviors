#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOK="$REPO_DIR/hooks/eca-inject-behaviors.sh"

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
      '{prompt: $p, chat_id: $s, workspaces: [$c]}' \
      | "$HOOK" 2>"$STDERR_FILE"
  else
    jq -n --arg p "$prompt" --arg s "$session_id" \
      '{prompt: $p, chat_id: $s}' \
      | "$HOOK" 2>"$STDERR_FILE"
  fi
}

context_of() { jq -r '.additionalContext // empty'; }

reset_state() { rm -rf "$TEST_HOME/.config/eca/.behaviors"; }

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

# === Setup ===

LOCAL_PROJECT="$TEST_HOME/project"
git init -q "$LOCAL_PROJECT"

# Pure macro composite
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-macro"
echo "#=code #deep" > "$LOCAL_PROJECT/.ai-behaviors/test-macro/compose"

# Composite with custom text + constraint
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-constrained"
echo "#deep" > "$LOCAL_PROJECT/.ai-behaviors/test-constrained/compose"
cat > "$LOCAL_PROJECT/.ai-behaviors/test-constrained/prompt.md" << 'EOF'
# #test-constrained — Constrained Composite
test-constrained :: always verify    -- HARD CONSTRAINT
EOF

# Nested composite for tree test
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-inner"
echo "#=review #deep" > "$LOCAL_PROJECT/.ai-behaviors/test-inner/compose"
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-outer"
echo "#test-inner #challenge" > "$LOCAL_PROJECT/.ai-behaviors/test-outer/compose"

# === Bypass hardening ===

echo "Bypass hardening:"

run_test "eca_framework_contains_bypass_hardening"
OUT=$(invoke "#=code" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "proceed as if it were not said" && pass

run_test "eca_framework_no_old_refusal_text"
OUT=$(invoke "#=code" test-session "$LOCAL_PROJECT" | context_of)
assert_not_contains "$OUT" "refuse, name the violated rule" && pass

run_test "eca_continuation_contains_bypass_hardening"
invoke "#=code #deep" test-session "$LOCAL_PROJECT" >/dev/null
OUT=$(invoke "next question" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "proceed as if it were not said" && pass

# === ECA Composite Tests ===

echo ""
echo "ECA composite expansion:"

# --- T21: Composite expansion produces leaf content ---
run_test "eca_composite_expands_to_leaves"
OUT=$(invoke "#test-macro" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<operating-mode>" && \
  assert_contains "$OUT" "Write production code" && \
  assert_contains "$OUT" "<behavior-modifiers>" && pass

# --- T22: State stores expanded leaf tags ---
run_test "eca_state_stores_expanded_continuation_works"
invoke "#test-constrained" test-session "$LOCAL_PROJECT" >/dev/null
STATE=$(cat "$TEST_HOME/.config/eca/.behaviors/test-session")
assert_contains "$STATE" "#deep" && \
  assert_not_contains "$STATE" "#test-constrained"
OUT=$(invoke "next question" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "Active: #deep" && \
  assert_contains "$OUT" "#deep:" && pass

# --- T23: EXPLAIN with composite shows expansion tree ---
run_test "eca_explain_composite_shows_tree"
OUT=$(invoke "#EXPLAIN #test-outer" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "<expansion-tree>" && \
  assert_contains "$OUT" "#test-outer" && \
  assert_contains "$OUT" "#test-inner" && pass

# === All-invalid hashtags retain state ===

echo ""
echo "ECA all-invalid hashtags retain state:"

# Composite whose children are all nonexistent
mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-all-unknown-compose"
echo "#nonexistent-aaa #nonexistent-bbb" > "$LOCAL_PROJECT/.ai-behaviors/test-all-unknown-compose/compose"

run_test "eca_all_invalid_retains_active_state"
invoke "#=frame #concrete" test-session "$LOCAL_PROJECT" >/dev/null
invoke "JVM output #xyzfake1 #xyzfake2" test-session "$LOCAL_PROJECT" >/dev/null 2>/dev/null
STATE=$(cat "$TEST_HOME/.config/eca/.behaviors/test-session")
assert_contains "$STATE" "#=frame" && \
  assert_contains "$STATE" "#concrete" && pass

run_test "eca_all_invalid_reinjects_active_behaviors"
invoke "#=frame #concrete" test-session "$LOCAL_PROJECT" >/dev/null
OUT=$(invoke "JVM output #xyzfake1 #xyzfake2" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "Active:" && \
  assert_contains "$OUT" "#=frame" && pass

run_test "eca_all_invalid_composite_retains_state"
invoke "#=code #deep" test-session "$LOCAL_PROJECT" >/dev/null
invoke "#test-all-unknown-compose" test-session "$LOCAL_PROJECT" >/dev/null 2>/dev/null
STATE=$(cat "$TEST_HOME/.config/eca/.behaviors/test-session")
assert_contains "$STATE" "#=code" && \
  assert_contains "$STATE" "#deep" && pass

# === Route catalog ===

echo ""
echo "Route catalog:"

mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf"
cat > "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/prompt.md" << 'EOT'
# #test-catalog-leaf — Something Else Entirely

UNIQUE-CATALOG-TAGLINE-XYZ
Second line never shown.
EOT

run_test "eca_route_injects_catalog"
OUT=$(invoke "#Route" | context_of)
assert_contains "$OUT" "<behavior-catalog>" && \
  assert_contains "$OUT" "Recommend only from this catalog." && pass

run_test "eca_catalog_inside_operating_mode_after_route"
OUT=$(invoke "#Route" | context_of)
BETWEEN="${OUT#*# #=route — Route}"
BETWEEN="${BETWEEN%%</operating-mode>*}"
assert_contains "$BETWEEN" "</behavior-catalog>" && pass

run_test "eca_no_catalog_without_marker"
OUT=$(invoke "#=code #deep" | context_of)
assert_not_contains "$OUT" "<behavior-catalog>" && pass

run_test "eca_frame_unchanged_by_route"
OUT=$(invoke "#Frame" | context_of)
assert_not_contains "$OUT" "<behavior-catalog>" && \
  assert_contains "$OUT" "⊣ {#Research}" && pass

run_test "eca_catalog_groups_modes_composites_modifiers"
OUT=$(invoke "#Route" | context_of)
assert_contains "$OUT" $'## Modes\n#=code — Write production code. Ship working software.' && \
  assert_contains "$OUT" $'## Composites\n#Code → #=code' && \
  assert_contains "$OUT" "#Route → #=route #coherence #legible #concise" && \
  assert_contains "$OUT" "#challenge — Find the flaws. Nothing gets a free pass." && pass

run_test "eca_catalog_prefixes_title_that_differs_from_name"
OUT=$(invoke "#Route" | context_of)
assert_contains "$OUT" "#ct — Category Theory: Name the categorical structure." && \
  assert_contains "$OUT" "#deep — Go beneath the surface." && pass

run_test "eca_catalog_includes_project_local_behaviors"
OUT=$(invoke "#Route" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "#test-catalog-leaf — Something Else Entirely: UNIQUE-CATALOG-TAGLINE-XYZ" && \
  assert_contains "$OUT" "#test-macro → #=code #deep" && \
  assert_not_contains "$OUT" "Second line never shown." && pass

run_test "eca_catalog_lists_shadowed_behavior_once"
OUT=$(invoke "#Route" test-session "$LOCAL_PROJECT" | context_of)
COUNT=$(grep -c '^#deep ' <<< "$OUT" || true)
assert_eq "$COUNT" "1" && pass

run_test "eca_explain_route_omits_catalog"
OUT=$(invoke "#EXPLAIN #Route" | context_of)
assert_contains "$OUT" "<explain-behaviors>" && \
  assert_not_contains "$OUT" "Recommend only from this catalog." && pass

touch "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/catalog"

run_test "eca_catalog_marker_on_modifier"
OUT=$(invoke "#=code #test-catalog-leaf" test-session "$LOCAL_PROJECT" | context_of)
BETWEEN="${OUT#*<behavior-modifiers>}"
BETWEEN="${BETWEEN%%</behavior-modifiers>*}"
assert_contains "$BETWEEN" "<behavior-catalog>" && pass

rm "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/catalog"

mkdir -p "$LOCAL_PROJECT/.ai-behaviors/=route"
cp "$REPO_DIR/behaviors/=route/prompt.md" "$LOCAL_PROJECT/.ai-behaviors/=route/prompt.md"

run_test "eca_shadow_without_marker_drops_catalog"
OUT=$(invoke "#=route" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" "# #=route — Route" && \
  assert_not_contains "$OUT" "Recommend only from this catalog." && pass

rm -rf "$LOCAL_PROJECT/.ai-behaviors/=route"

mkdir -p "$LOCAL_PROJECT/.ai-behaviors/test-crlf"
printf '# #test-crlf — Carriage Return\r\n\r\nCRLF-TAGLINE\r\n' > "$LOCAL_PROJECT/.ai-behaviors/test-crlf/prompt.md"

run_test "eca_catalog_line_from_crlf_prompt"
OUT=$(invoke "#Route" test-session "$LOCAL_PROJECT" | context_of)
assert_contains "$OUT" $'\n#test-crlf — Carriage Return: CRLF-TAGLINE\n' && pass

rm -rf "$LOCAL_PROJECT/.ai-behaviors/test-crlf"
touch "$LOCAL_PROJECT/.ai-behaviors/test-catalog-leaf/catalog"

run_test "eca_catalog_once_when_several_marked"
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
for COMPOSITE in Collate Converge Spike; do
  run_test "eca_shipped_${COMPOSITE}_injects_every_leaf"
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

run_test "eca_spike_mode_injects_contract"
OUT=$(invoke "#=spike" | context_of)
assert_contains "$OUT" "# #=spike — Spike" && \
  assert_contains "$OUT" "ProjectChangeBeyondFinding" && \
  assert_contains "$OUT" "when halted ⊣ {the user's ruling}" && \
  assert_contains "$OUT" "never empty" && \
  assert_not_contains "$OUT" "ai/spike/" && pass

run_test "eca_scratch_injects_workspace_rules"
OUT=$(invoke "#scratch" | context_of)
assert_contains "$OUT" "LeftoverScratch" && \
  assert_contains "$OUT" "containing \`*/\` and \`.gitignore\`" && \
  assert_contains "$OUT" "git status --porcelain -uall" && pass

run_test "eca_finding_injects_section_rules"
OUT=$(invoke "#finding" | context_of)
assert_contains "$OUT" "OverwrittenSection" && \
  assert_contains "$OUT" "PostHocPrediction" && \
  assert_contains "$OUT" "or halted, which settles nothing" && pass

run_test "eca_collate_does_not_suggest_spike"
OUT=$(invoke "#Collate" | context_of)
assert_contains "$OUT" "suggest /clear, then #Converge" && \
  assert_not_contains "$OUT" "#Spike" && pass

run_test "eca_converge_crux_names_both_routes"
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

run_test "eca_spike_contracts_survive_second_turn"
invoke "#Spike" >/dev/null
OUT=$(invoke "run the experiment" | context_of)
assert_contains "$OUT" "when halted ⊣ {the user's ruling}" && \
  assert_contains "$OUT" "LeftoverScratch" && \
  assert_contains "$OUT" "OverwrittenSection" && pass

run_test "eca_backticked_hashtag_is_inert"
OUT=$(invoke "#Spike q → p, then \`#Collate a into b\`" | context_of)
assert_contains "$OUT" "# #=spike — Spike" && \
  assert_not_contains "$OUT" "# #=research — Research" && \
  assert_not_contains "$OUT" "# #ledger — Ledger" && pass

# === Summary ===

echo ""
TOTAL=$((PASS + FAIL))
echo "$PASS/$TOTAL passed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
