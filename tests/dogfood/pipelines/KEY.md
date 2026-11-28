# Dogfood key: pipeline tokens (`#>a>b*N`)

Do not let the session under test read this file.
Each run starts from a fresh `claude -p` session outside this repo, in a scratch git repo, with this checkout's hook:

```
{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"<this repo>/hooks/inject-behaviors.sh"}]}]}}
```

passed as `--settings`, with `--permission-mode acceptEdits --allowedTools Agent "Bash(python3:*)" Read Edit Write Glob Grep`.
Score from the session transcript (`~/.claude/projects/*/<session_id>.jsonl`): the `prompt` of each `Agent` tool call.
A spawn's stage is the `<stage>` whose text (between `<stage …>` and `</stage>` in the hook's output) is a substring of that prompt.

## Run 1: Test → Review → Code, through the hook

The scratch repo holds one file, `bill.py`:

```python
def parse_price(s):
    return float(s.strip("$"))


def apply_discount(price, pct):
    return price - price * pct / 100


def split_bill(total, people):
    share = round(total / people, 2)
    return [share] * people


def add_tip(total, pct=15):
    return total + total * pct / 100


def summarize(items):
    subtotal = sum(parse_price(p) for p in items)
    return {"subtotal": subtotal, "tax": subtotal * 0.08, "total": subtotal * 1.08}
```

Turn 1: `#>Test>Review>Code*2 Make bill.py in the current directory correct and robust for money handling. Stages may run python3 to try the code.`
Turn 2 (`--resume`): `Fix all blocking findings. For the open questions, use your recommendations.`

- R1: stages spawn in pipeline order, each after the previous one returned.
- R2: every spawn holds its stage's text exactly.
- R3: turn 1 pauses after the first Review, not after Test.
- R4: turn 2 runs Code, Test, Review, and ends on that second Review with a report: no Code after it, no question to the user.
- R5: on opus and sonnet, at least 80% of each previous stage's lines of 25 characters or more appear verbatim in the next spawn prompt.

Any spawn out of order or without its exact text falsifies "the main agent runs the pipeline as written".
A run pausing after Test falsifies "only #triage stages pause" (the spike's haiku did, under the earlier "a stage" wording).

Measured 2026-11-28, Claude Code 2.1.332, one run per model:

| | opus | sonnet | haiku |
|---|---|---|---|
| R1 order | 5/5 | 5/5 | 5/5 |
| R2 exact stage text | 5/5 | 5/5 | 5/5 |
| R3 turn 1 | Test, Review → paused | Test, Review → paused | Test, Review → paused |
| R4 turn 2 | Code, Test, Review → report | Code, Test, Review → report | Code, Test, Review → report |
| R5 handoff | 88%, 91%, 85%, 87% | 93%, 94%, 89%, 90% | 93%, 81%, 84%, 91% |
| Cost, both turns | $3.13 | $1.96 | $0.11 reported |

Every run wrote "Round 1" and "Round 2", and none started Code after the second Review.
Haiku paused at Review here, where it paused at Test in the spike.
The loop line measured here differs from the spike's in two places: `write "Round" and its number` (was `"Round N"`, where N also named the cap) and `Stage 2 (Review)` (was `The "review" stage`, ambiguous once stages repeat).
