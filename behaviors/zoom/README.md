# Zoom

Coarse to fine. One level per step. The user turns the lens.

## Why this exists

Asked "how does X work?", an LLM answers at one uniform depth: file by file, essential logic mixed with workarounds, every level at once. The reader ends up with a transcript, not a model. Program-comprehension research points the other way: people understand code top-down, purpose first, then structure, then mechanism, and they jump levels when they need to.

`#zoom` presents one level per step and holds it. Anything deeper becomes a one-line entry under "Deeper", which doubles as the menu for the next step. You choose where to zoom; nothing below the current level is volunteered.

## Levels

| Level | Holds | Never |
|---|---|---|
| 0 Purpose | Why it exists, who triggers it, what breaks without it — ≤ 3 sentences | Names a function, file, mechanism or step |
| 1 Shape | ≤ 7 `part — role` lines and how the parts connect | Says how a part works inside; invariants belong to Key points |
| 2 Flow | One pseudocode block of the main path | Real code |
| 3 Key points | ≤ 5 invariants, decisions, non-obvious mechanisms | |
| 4 Detail | Real code, error handling, edge cases | |
| 5 Incidental | Workarounds, legacy, hacks — each labeled, with why | |

## Rules

- One level per step, starting from the coarsest not yet covered. A step is a response, or a section when `#proceed` keeps going.
- Evidence at any level is a pointer (docstring, README, commit, file:line, or "inferred") plus a confidence. How it's known goes under Deeper as "Evidence for <claim>".
- Anchors (file:line) from level 1 down.
- Incidental remarks — strays, duplication, workarounds — at levels 0–4 are one Deeper line.
- Every step ends with: the model so far, where you are (level, region), and 2–4 Deeper targets.

## DO NOT

- Explain anything from a deeper level, even briefly — park it under Deeper.
- Justify a level-0 claim with mechanism.
- Treat the ladder as a gate: you may jump levels at any time.

## Pairs well with

- `#=tour` — the read-only mode built around it; `#Tour` bundles both
- `#delta` — explain a change; its parts map onto the levels
- `#proceed` — writes every level once for the whole region, breadth-first, down to Key points, recording each choice
- `#deep` — its layers go up the why-chain (why it exists → what need → what breaks without it), never down into mechanism
- `#fractal` — applied to the current level's parts only
- `#wide` — neighbors surveyed at the current level
- `#epistemic` — labels inferred purpose, which is rarely written down

## Known limitations

The first step holds its level; later steps leak. In throwaway experiments, `#Tour` on code kept its first response at Purpose in 5 of 6 runs; with `#delta`, judges disagreed on whether first responses held. After "Zoom to Shape." and "Zoom to Flow." most responses carried some content from a deeper level — about 10–20% of their paragraphs:

- Shape steps may state invariants or name mechanisms inside part roles.
- Evidence lines may appear below level 0 instead of as Deeper entries.
- With `#delta`, "what did not change" may appear before Key points.

When a step goes deeper than you asked, say so; the next step holds better with the correction in context.

## Common prompts

- `How does auth work here? #Tour` — purpose first, then you pick where to zoom
- `#Tour #proceed` — every level once, down to Key points, in one document
- `#Research #zoom` — investigate, reporting one level at a time
- `#Tour #deep` — purpose traced up the why-chain
