# =spike

Build something throwaway to answer one question. Keep the answer, not the code.

## Operating Contract

| | |
|---|---|
| **Role** | Experimenter |
| **Who drives** | Claude — user sets the question and rules on surprises |
| **Claude produces** | A finding file: question, prediction, method, observed, verdict, not shown — see [`#finding`](../finding/README.md) |
| **Prohibits** | Production code, runnable code left in the project, growing the question, project changes beyond the finding |

## Why this mode exists

Some questions can't be settled by reading: is approach A fast enough, does library X handle nested input, does this API behave the way the docs imply. `#=research` only observes, so it can't answer them. `#=code` answers them by building the real thing, and the experiment becomes code to keep.

A spike runs the smallest experiment that answers the question, records what happened, and deletes the code. The finding is the product.

It is also the check that sits outside the model. Agents share blind spots, and a claim that several explorations agree on is still a claim. Running something is the cheapest way to test it.

## Workflow

From a Crux in `#=converge`:

1. `#Converge` ends in a Crux with a route. A run-route Crux hands you `#Spike <question> → <path>, then <tail>`; a read-route Crux sends you to `#Research` first and gives the same Spike command as the fallback.
2. `#Spike` adds `# Spike` to the finding file at `<path>`.
3. Answered: the spike hands off to its tail — the other Cruxes still to settle, then the collate command. Halted: no handoff until you rule.
4. The loop is owned by `=converge` — see its [Crux loop](../=converge/README.md#crux-loop).

From research: when `#Research` reports an unknown that only running something can settle, `#Spike` it. Research doesn't suggest this itself; its exits are unchanged.

From a design question: `#Spike` directly → `ai/spike/<slug>.finding.md`, then back to `#Design` or `#Spec`.

## Exits

| Outcome | Suggests | Why |
|---|---|---|
| Question answered, asker gave a next step | That step (e.g. the Crux's `#Collate` loop) | The finding goes back to whoever asked |
| Question answered, no next step given | `#Design`, `#Spec` | The finding feeds the next decision |
| Halted on a surprise | You rule on it — no handoff | Verdict `halted` settles nothing, so it doesn't go to the asker's next step; `ai/spike/<slug>/` is kept until you've ruled |

## Conventions

- Each question gets a slug: kebab-case `[a-z0-9-]+`, never empty — from the asker's finding path when given. A slug already held by a finding or a scratch directory gets `-2`, `-3`, …; the asker's path stays as given.
- Where the code runs and how it's cleaned up: [`#scratch`](../scratch/README.md).
- What the finding holds and how modes share it: [`#finding`](../finding/README.md).
- Bare `#=spike` keeps its bans but picks its own location and format; `#Spike` brings both modifiers.

## Pairs well with

- `#falsifiable` — state the prediction before running, so the verdict can't be tuned to the result
- `#stop` — a surprise is reported, not chased
- `#challenge` — look for the case that breaks the finding
- `#boundary` — for capability questions, test the edges, not only the happy path
- `#bisect` — when the question is where a behavior changes

## Common prompts

- `#Spike can the parser stream a 1 GB file in under 200 MB of memory?` — throwaway prototype, measured
- `#Spike #challenge does the parser handle nested composites?` — try to break the answer
- `#=spike #boundary` — edge cases of a capability
