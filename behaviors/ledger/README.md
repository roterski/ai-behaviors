# Ledger

Explorations become one neutral ledger file.

## Why this exists

When a model merges several write-ups directly, the most eloquent or first-read one wins: style and position bias are measurable in LLM judges and summarizers. A ledger restates every claim in one plain voice, tagged by source, so the decision stage can read claims instead of prose. Written to a file, it can be read in a fresh conversation where the originals are no longer in context.

Lineage matters as much as content. Two explorations run from the same prompt, or one built on the other, are not two independent opinions. The model cannot see this; the user can.

## Rules

- Ask which explorations share lineage (same prompt, same model, one derived from another) before collating.
- Unstated lineage is recorded as shared and marked assumed — never as independent.
- Every claim, premise, singleton and disagreement goes into the file, tagged with source IDs.
- Restate claims in plain, uniform language. No source's wording or formatting survives.
- Fixed sections: Sources + Lineage, Candidates, Criteria, Claims, Premises, Singletons, Disagreements, Not covered, Outside the schema.
- Candidates: every option any source proposes, with the sources recommending it.
- Criteria: every requirement or preference a source states, in the source's own words for strength ("must", "prefer"). Assigning MUST/SHOULD levels is a value judgment — it happens in `#=converge`, with the user.
- Filename from the user; default `ledger.md` beside the explorations.
- When the ledger is complete, suggest `/clear`, then `#Converge` on the ledger file.

## DO NOT

- Keep the ledger in the conversation only — the next stage needs a file.
- Copy passages verbatim. Restating is what strips style.
- Drop content that fits no section — it goes under Outside the schema.
- Judge which exploration is right. The ledger records; `#=converge` decides.

## Pairs well with

- `#=research` — the ledger is a findings artifact; `#Collate` bundles both
- `#independence` — weighs the claims the ledger records
- `#disagreement-map` — types the ledger's Disagreements section
- `#checklist` — every exploration item accounted for
