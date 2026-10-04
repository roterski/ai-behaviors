# =stepback

Leave the current line. Re-derive the problem, then choose the frame to continue in.

## Operating Contract

| | |
|---|---|
| **Role** | Reframer |
| **Who drives** | Claude reframes; user picks a framing, confirms the current one, or rejects all |
| **Claude produces** | Goal, path, assumptions, labeled framings, and an exit with the next line |
| **Prohibits** | Continuing the current line, unlabeled framings, code, mutation |

## Why this mode exists

A stuck session repeats itself: each attempt is a small variation of the last, each fix moves the bug, the goal drifts. Every earlier turn pulls the next one back onto the same line. Getting out takes an explicit move: go back to the goal, list what was tried and what was assumed along the way, and look for a different frame before trying anything else.

`#Route` asks whether the *method* still fits. `#Stepback` asks whether the *problem framing* still fits.

Each framing names the level it changes — the fix, the diagnosis, or the goal — and if none changes the goal, the step-back says why. In throwaway experiments that requirement made a goal-level reframing appear in every step-back (1.00, against 0.56 without it), with no loss of diversity between framings. A menu of reframing moves (rethink the goal, flip a constraint, reason backward, …) made no measurable difference, so the mode doesn't prescribe one; stack `#first-principles`, `#backward` or `#analogy` when you want a specific angle.

## Workflow

In-session:

1. Stuck in any mode: type `#Stepback`.
2. You get goal → path → assumptions → framings → exit.
3. Pick a framing, confirm the current one, or reject all.
4. The exit recommends the next line by level (see Exits).

Fresh-session handoff, when one step back isn't enough:

1. The exit offers it when the chosen framing was already on the path, or when you reject every framing.
2. Paste the three lines in order: `#Stepback #file <path>` writes the step-back under `# Step Back`, the prior mode included; `/clear` drops the anchored context; `#Stepback <path>` reframes from the file.
3. In the fresh session, the file's path and framings count as tried; the new framings must differ from them. Exits route against the prior mode the file records.

## Exits

| Outcome | Suggests | Why |
|---|---|---|
| Goal-level framing chosen | `#Frame` | The problem itself changed; scope it again |
| Diagnosis-level framing chosen, prior mode was debug | `#Debug` | Investigate the new cause |
| Diagnosis-level framing chosen, reading can settle it | `#Research` | Gather evidence for the new account |
| Diagnosis-level framing chosen, reading can't settle it | `#Spike` | Run a throwaway experiment |
| Fix-level framing chosen, a new approach | `#Design` | Explore candidates for it |
| Fix-level framing chosen, same approach family | The prior mode | Continue with the new fix |
| Current framing confirmed | The prior mode | The frame holds; continue with the reason stated |
| Chosen framing already tried, or all rejected | The fresh-session handoff | The session's own context is the anchor |

## Conventions

- Framing levels: **fix** keeps the goal and the diagnosis; **diagnosis** changes what the problem is or what causes it; **goal** changes the goal, the success criterion, or whether to solve it.
- Assumptions are labeled **chosen** (decided) or **inherited** (crept in without a decision).
- Confirming the current framing is a valid exit — after the alternatives are on the table.
- The fresh-session file uses [`#file`](../file/README.md): one `# Step Back` section, written by the handoff's first line — you never edit it by hand.
- The file lives in the project (default `ai/stepback/<slug>.md`), never in a session scratchpad or temp directory, which may not survive `/clear`.
- A step-back started from a file hands off to that same file, so one problem keeps one file.

## Pairs well with

- `#first-principles` — re-derive from constraints instead of the session's conventions
- `#backward` — reason from the end state instead of from where you're stuck
- `#analogy` — borrow the structure of a solved problem
- `#negative-space` — look for what the stuck line never considered

## Common prompts

- `We've been going around in circles on this #Stepback` — reframe in-session
- `#Stepback #first-principles` — reframe from constraints
- `#Stepback notes/stuck.md` — reframe in a fresh session from a written step-back
