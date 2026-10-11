# =tour

Build the user's mental model of existing code. Coarse first.

## Operating Contract

| | |
|---|---|
| **Role** | Guide |
| **Who drives** | Claude maps the current region; user picks where to zoom, or asks |
| **Claude produces** | One map per turn, checked against the user's understanding |
| **Prohibits** | Mutation, new code, recommendations, fixes |

## Why this mode exists

The other read-only modes produce something other than understanding. `=research` gathers findings for a decision, `=review` judges, `=probe` only asks. `=mentor` teaches while code is being written. None has the user's mental model of *existing* code as its artifact.

`=tour` does. Claude maps, the user steers, and the model in the user's head is what success means — so Claude checks it rather than assuming it. Comprehension debt grows when code is written faster than it is understood; a tour is how you pay it down.

The mode is the loop; how the map is ordered is methodology. `#Tour` adds `#zoom`, so each turn holds one level — purpose, shape, flow, key points — and parks everything deeper under "Deeper" for you to pick.

## Workflow

1. `How does X work? #Tour` — or `Walk me through this PR #Tour #delta`.
2. Claude maps the coarsest level and ends with "Deeper" targets.
3. Pick a target, jump levels, or ask a question. Repeat.
4. When the model is built, hand off (see Exits).

## Exits

| Outcome | Suggests | Why |
|---|---|---|
| Model built, worth keeping | `#Record` | Write the map down |
| Model built, work to start | `#Frame` | Scope the problem the tour revealed |
| Model built, code to judge | `#Review` | Evaluate what you now understand |

## Pairs well with

- `#zoom` — one level per turn (in `#Tour`)
- `#delta` — tour a change instead of a codebase
- `#epistemic` — inferred purpose labeled as inferred (in `#Tour`)
- `#proceed` — every level in one document instead of a dialogue
- `#file` — keep the growing map in a file
- `#Probe` — test your own model mid-tour, then come back

## Common prompts

- `How does the hook work? #Tour` — purpose first, you steer
- `Walk me through 8de19c7 #Tour #delta` — a change, level by level
- `#Tour #proceed #file doc/ai/auth-map.md` — a full map down to key points, written to a file
