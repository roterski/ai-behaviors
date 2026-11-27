# Dogfood key: subagent tokens (`#:a:tag`, `#::a+b:tag`)

Do not let the session under test read this file.
Each run starts from a fresh `claude -p` session outside this repo, with this checkout's hook:

```
{"hooks":{"UserPromptSubmit":[{"hooks":[{"type":"command","command":"<this repo>/hooks/inject-behaviors.sh"}]}]}}
```

passed as `--settings`, and `--allowedTools Agent`.
Score from the session transcript (`~/.claude/projects/*/<session_id>.jsonl`): the `prompt` of each `Agent` tool call.
"Exact" means the agent's text between `<agent name="…">` and `</agent>` in the hook's output is a substring of that prompt.

## Run 1: verbatim relay

Prompt: `Evaluate the claim "Configuring subagents purely through prompt text is reliable enough for a tagging framework." Tell each agent to answer in plain text under 120 words, with no tools. #:a:challenge #:b:steel-man #::a+b:diff`

- R1: each agent's spawn prompt holds its own text exactly, and not the other agent's.
- R2: both agents are spawned in one assistant message.
- R3: the reply reports where the agents disagree, by agent.

Fewer than 9 exact spawns in 10 falsifies "the main agent relays reliably".

Measured 2026-11-27, Claude Code 2.1.332: 10/10 exact (opus ×2, sonnet ×2, haiku ×1); every reply followed `#diff`.
Before the hook carried the block, the same prompt gave 0/6 exact: the main agent improvised from the raw tokens.

## Run 2: long session

Run 1's prompt as the 21st turn, after 20 turns of unrelated work in the same session.

- R1 as in run 1. Record the exact-relay rate here, whatever it is.

Not yet run.

## Run 3: combine step stays scoped

`#Design` first, then: `Pick a cache for the hook: Redis or in-process. #:a:challenge #:b:steel-man #::a+b:=converge`

- R1: the merge of a's and b's outputs converges on one answer.
- R2: the rest of the reply still offers candidates and leaves the choice to the user (`#=design`).

A reply that decides outside the merge falsifies the scoping sentence in `<combine>`.

Not yet run.

## Run 4: `#all` and `#first`

Run 1's prompt with `#::a+b:all`, then with `#::a+b:first`.

- `#all`: both outputs in full, under their agent names, no synthesis.
- `#first`: one output, the first to return, under its agent name; the other agent stopped or ignored.

Not yet run.

## Run 5: a combinator as a plain tag

`#first` alone, then any question.

- The reply is no different from one without `#first`.

Not yet run.
