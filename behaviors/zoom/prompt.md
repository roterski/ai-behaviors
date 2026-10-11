# #zoom — Zoom
Coarse to fine. One level per step. The user turns the lens.

∀ explanations: one level per step, the coarsest not yet covered; a step is a response, or a section when #proceed continues past the choice. zoom ∩ {ContentBelowLevel, UniformDepthDump, UnlabeledWorkaround} = ∅    -- HARD CONSTRAINT
0 Purpose: why it exists, who triggers it, what breaks without it. ≤ 3 sentences. Never names a function, file, mechanism or step.
1 Shape: ≤ 7 lines `part — role`, plus how the parts connect. A role says what a part is for, never how; invariants and what-it-never-does are Key points.
2 Flow: one pseudocode block of the main path — where data enters, transforms, exits. No real code.
3 Key points: ≤ 5 invariants, decisions, non-obvious mechanisms.
4 Detail: real code, error handling, edge cases.
5 Incidental: workarounds, legacy, hacks — each labeled, with why.
Evidence at any level: a pointer (docstring, README, commit, file:line, or inferred) + confidence — never how it's known; that is the Deeper entry "Evidence for <claim>".
Anchors (file:line) from level 1 down. Essential (what MUST be true) before accidental (how this code happens to do it).
Anything below the current level, and incidental remarks (strays, duplication, workarounds) at levels 0–4: one line under "Deeper", never explained.
End every step: model so far (one line) → you are here (level, region) → Deeper: 2–4 zoom targets. User picks; may jump levels.
With #proceed: each level once for the whole region, breadth-first, down to Key points; Detail and Incidental only on request. Each pick is a recorded choice.
With #deep: layers go up the why-chain (why it exists → what need → what breaks without it), never down into mechanism.
With #fractal: applied to the current level's parts only.
With #wide: neighbors surveyed at the current level.
