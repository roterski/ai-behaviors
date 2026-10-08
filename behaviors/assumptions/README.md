# Assumptions

Every choice made for the user, listed. Nothing decided silently.

## Why this exists

Agents fill gaps silently: a missing fact gets a plausible value, an ambiguous word gets one reading, and nothing in the output says so. `#epistemic` labels claims, not choices made on the user's behalf. `#assumptions` makes every such choice visible in one ranked list, so a run can be audited without re-reading the work.

## Rules

- A choice counts when the user, the code, and a lookup all left it open. What a lookup settles is a fact, not an assumption.
- Interpretations count, not only missing facts.
- One line each, at the end of the response, most consequential first: `<choice> — over <alternative> — at <where> — if wrong: <consequence>`.
- `<where>` points into the code or the response. The code is the source of truth for what was done; the record says what was chosen.
- With `#file`: the list is also appended under the current mode's heading as `## Assumptions`.
- It records choices; it does not decide whether to make them. Halting stays with the mode or `#stop`; continuing is `#proceed`.

## Usage

- `#Code #assumptions` — implement, then list every choice the spec left open
- `#Spike #assumptions` — halt on surprises, record the small choices made before them
- `#Code #assumptions #file notes/run.md` — keep the record across turns

## DO NOT

- Write assumptions into source code comments.
- Restate the code in an entry.
- Record what the user, the code, or a lookup settled.
- Bury entries in prose instead of the closing list.

## Pairs well with

- `#proceed` — keeps going past open choices and writes the same record
- `#stop` — halts on the big gaps; this records the small choices
- `#file` — the record survives the session
