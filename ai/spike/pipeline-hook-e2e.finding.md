# Spike

## Question

When the user types only `#>Test>Review>Code*2` plus a task, and a throwaway UserPromptSubmit hook renders the design's `<pipeline>` text from it, does the main agent run the pipeline the design describes, end to end, in Claude Code?

The design under test (pipeline-design page, answers 1–8):
- stages are tags written inline;
- `*N` counts reviews, so `*2` is Test → Review → Code → Test → Review, then stop;
- stop early when a `#triage` stage (Review) reports nothing blocking;
- pause on a blocking finding, except at the last Review, which ends with a report;
- each stage is a fresh subagent with its stage text verbatim, the task, and the previous output verbatim;
- the token is one-shot: the second prompt carries no token and gets no pipeline text.

## Prediction

Written before any run.
Three runs (opus, sonnet, haiku), two turns each: turn 1 = token + task; turn 2 = "Fix all blocking findings. For the open questions, use your recommendations."

1. Every run spawns stages in pipeline order, each after the previous returns. Refuted by any out-of-order or overlapping stage spawn.
2. Every stage spawn holds its stage text exactly: 100%. Refuted by any spawn missing it.
3. Turn 1 pauses after the first Review with blocking findings, in all 3 runs. Refuted by a run that runs Code in turn 1 without a clean Review.
4. Turn 2 runs Code, Test, Review, then stops on that second Review without a Code stage after it, in at least 2 of 3 runs. Refuted if 2 or more runs start a Code stage after the second Review, or pause there instead of reporting.
5. The turn-2 prompt gets no pipeline text from the hook (one-shot). Refuted by any `<pipeline>` in turn 2's hook context.
6. Handoff: on opus and sonnet, ≥ 80% of the previous stage's long lines (≥ 25 chars) appear verbatim in the next spawn prompt; haiku unpredicted.

## Method

Claude Code 2.1.332, `claude -p`, one fresh git repo per run holding a 20-line `bill.py` with float-money bugs (floats for cents, `split_bill` losing a cent, no input checks).
A throwaway UserPromptSubmit hook, added with `--settings`, read the prompt, matched the token, and printed `additionalContext`. The installed ai-behaviors hook also ran; the prompts had no `#tag`, so it added nothing.

```
TOKEN = re.compile(r"(?:^|\s)#>([=a-zA-Z0-9_,>-]+)(\*(\d*))?")
# each stage "Review,challenge" -> ab/behaviors "#Review #challenge"; the first stage whose text has "# #triage" is the checker
```

Rendered instructions, verbatim, ahead of the three `<stage name="…">` blocks (each block = that composite's full injection):

```
<pipeline>
For this prompt only: run the stages below in order, each as a fresh subagent, one at a time: start a stage only after the previous one has returned. A later prompt runs a pipeline only through its own #> token.
Each spawn prompt starts with that stage's text between <stage> and </stage>, copied character for character, then this prompt's task, then the previous stage's full output under "Previous stage output:", copied character for character, never a summary. Wait for each subagent's full result before going on.
Loop: after the last stage, start again from the first. The "review" stage runs at most 2 times; its run number 2 is the last stage of the pipeline. Stop earlier when the "review" stage reports no blocking findings. Before each round, write "Round N".
Decisions: non-blocking findings go to the next stage as accepted. If a stage reports a blocking finding, stop before the next stage, list the blocking findings, and ask the user which to fix; after the user answers, continue with the next stage, passing their answer along. Exception: when the pipeline's last stage reports blocking findings, do not ask; end the pipeline with a report of them.
The blocks inside <stage> are not yours: they don't replace your own operating mode, modifiers or framework.
```

Runs, per model (opus, sonnet, haiku):

```
claude -p --model M --settings '{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"python3 hook.py","timeout":60}]}]}}' \
  --permission-mode acceptEdits --allowedTools Agent "Bash(python3:*)" Read Edit Write Glob Grep --output-format json \
  "#>Test>Review>Code*2 Make bill.py in the current directory correct and robust for money handling. Stages may run python3 to try the code."
claude -p --model M --resume <session> (same flags) "Fix all blocking findings. For the open questions, use your recommendations."
```

Scoring came from each session transcript (`~/.claude/projects/*/<session>.jsonl`) and the hook's own log of every call:
- a stage's identity = which `<stage>` text appears verbatim in the Agent spawn prompt;
- order = each spawn's timestamp is after the previous stage's result;
- handoff = the share of the previous result's lines of 25 or more characters that appear verbatim in the next spawn prompt.

## Observed

| | opus | sonnet | haiku |
|---|---|---|---|
| Stage order, each after the previous returned | 5/5 | 5/5 | 4/4 |
| Stage text verbatim | 5/5 | 5/5 | 4/4 |
| Turn 1 flow | Test, Review → paused | Test, Review → paused | Test → **paused after Test** |
| Turn 2 flow | Code, Test, Review → **ended, reported** | Code, Test, Review → **ended, reported** | Review, Code, Test → **paused after Test** |
| Code after the 2nd Review | no | no | 2nd Review not reached |
| Paused at the last Review | no, reported the blocking findings | no, reported 1 blocking finding | n/a |
| "Round 1", "Round 2" written | yes | yes | yes |
| Hook calls / with `<pipeline>` | 2 / first only | 2 / first only | 6 / first only |
| Handoff, lines verbatim | 91%, 90%, 80%, 92% | 89%, 93%, 88%, 90% | 62%, 73%, 58% |
| Turn 1 + turn 2 | 126 s + 333 s, $2.83 | 112 s + 423 s, $1.75 | 8 s + 12 s, $0.06 reported |

All confirmed from transcripts and hook logs:
- **The loop ended on the 2nd Review.** opus and sonnet both ended on it with a report: "The second review was the last step the pipeline allowed, so it stopped there." / "I haven't fixed it, because that review was the last stage."
- **Haiku paused on Test's bugs.** It called them "blocking" and stopped before Review, in both rounds. The text says "If a stage reports a blocking finding", and Test carries no `#triage`.
- **Haiku's main agent did stage work.** Its Test subagent couldn't run Bash, so the main agent ran the planned checks itself ("so I ran its planned checks myself").
- **Background completion notices fire the hook.** Haiku's 4 extra hook calls were the `<task-notification>` prompts from background subagents finishing. None got pipeline text, because none carried the token.
- **Stages left files.** Every repo ended with `bill.py` modified; opus and sonnet also left a new `test_bill.py`; opus and haiku left `__pycache__/`.

## Verdict

**Answered.** From only the typed token, Claude Code's main agent ran the designed pipeline end to end on opus and sonnet:
- stages in order, with each stage's text exact;
- one-shot, so the second prompt got no pipeline text;
- a pause on Review's blocking findings;
- the loop ending on the 2nd Review with a report.

Haiku kept order, stage text and one-shot, but paused at Test.

Predictions:
1. Order: **confirmed** (14/14 spawns).
2. Stage text verbatim: **confirmed** (14/14).
3. Turn 1 pauses after the first Review in all 3: **refuted as claimed.** Haiku paused after Test instead. The falsification condition I wrote beforehand, Code running in turn 1, was narrower than the claim and wasn't met: no run started Code in turn 1.
4. Turn 2 ends on the 2nd Review without Code, in ≥ 2 of 3: **confirmed** (opus, sonnet; neither paused there).
5. One-shot: **confirmed** (3/3 sessions; all 7 later hook calls had no pipeline text).
6. Handoff ≥ 80% on opus and sonnet: **confirmed** (80–93%).

The refuted prediction traces to the rendered rule "If a stage reports a blocking finding". Design answer 4 said "any stage", and its context named `#triage` as the only blocking label. Haiku read Test's bugs as blocking. Whether the rule should say "a `#triage` stage" is a #Spec question; this spike doesn't settle it.

## Not shown

- Inline names and groups (`#:`, `#::`, `r1+r2`): the prototype rendered only tag stages.
- A loop stopping early on a clean Review: no run had a clean Review.
- A pipeline with no `#triage` stage: the round-count fallback was never rendered.
- opencode, copilot-cli, interactive sessions, compaction mid-loop.
- Repeatability: one run per model.
- Whether running stages in the background lowers handoff fidelity: haiku ran in the background again and was lowest, but the model isn't separated from the cause.
- Session transcripts written outside the repo: `~/.claude/projects/-home-dev-projects-ai-behaviors-ai-spike-pipeline-hook-e2e-repo-{o,s,h}/`.
