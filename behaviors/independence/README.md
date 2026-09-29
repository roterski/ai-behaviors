# Independence

Count reasons, not voices.

## Why this exists

Agreement is only evidence when the agreeing sources are independent. LLM errors are correlated — models agree most of the time even when both are wrong, and larger models more so, across providers. Five sessions of the same model on the same prompt are one opinion sampled five times.

Two opposite failures follow. Findings repeated across sources get amplified; findings from a single source get dropped (the hidden-profile problem). And a shared conclusion can hide incompatible reasons: three explorations recommending B for three different reasons is not agreement on B.

## Rules

- Weigh each finding by the number of independent premises behind it, not the number of sources stating it.
- Same premises or shared lineage = one vote.
- Same conclusion, different premises = a disagreement, not consensus.
- Record singletons before shared findings.
- Show, per finding, the independent support count and the premises behind it.

## DO NOT

- Treat correlated agreement as evidence.
- Tally conclusions without their premises.
- Read frequency as importance — a singleton may be the only source that looked.

## Pairs well with

- `#ledger` — supplies the lineage this behavior weighs by
- `#disagreement-map` — premise mismatches become typed disagreements
- `#epistemic` — confidence per finding
- `#minority` — a singleton that loses still gets its report
