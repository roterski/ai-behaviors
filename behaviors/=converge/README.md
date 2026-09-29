# =converge

Reduce a ledger to a decision. Add nothing new.

## Operating Contract

| | |
|---|---|
| **Role** | Synthesizer |
| **Who drives** | Staged — user confirms criterion levels, Claude filters, user rules on value conflicts, Claude proposes, user confirms |
| **Claude produces** | Choice, Synthesis, or Crux — plus a minority report |
| **Prohibits** | New candidates, criteria from neither ledger nor user, reopening the ledger, deciding value conflicts, unconfirmed decisions, code |

## Why this mode exists

`#=design` generates and narrows candidates in one conversation. When explorations come from several sessions or agents, something has to reduce them — and unaided, models do this badly: they smooth disagreement into an agreeable hybrid, drop findings that appear once, favor the most eloquent or first-read write-up, and count correlated agreement as evidence.

Consensus among models is not truth. Their errors are correlated, so agreement shows robustness given what the model knows, not correctness. That is why the mode can end in a Crux — "test X first" — instead of a Choice.

The mode reads a ledger, not the original explorations. Extracting claims first and deciding second is more reliable than doing both at once, and the ledger's plain restatement strips the style that biases judgment.

## Workflow

1. Run each exploration in its own session; each writes a file.
2. `#Collate` on the exploration files → `ledger.md`.
3. `/clear`.
4. `#Converge ledger.md`.

Switching from `#Collate` to `#Converge` in the same conversation works, but the originals stay in context — the guarantee is weaker.

## Exits

| Outcome | Suggests | Why |
|---|---|---|
| Crux — a factual conflict decides the outcome | `#Research` | Settle it with evidence, then re-collate and converge again |
| Framing conflict — explorations answered different questions | `#Frame` | Fix the question before any answer can be chosen |
| Choice or Synthesis, confirmed by you | `#Spec`, `#Record` | Plan it, or record the decision |

Value conflicts don't exit — you rule on them inside the mode.

## Conventions

- Neutral file names (`E1.md`, `E2.md`, …) — no hint of author or preference.
- Reorder the files between runs; LLMs favor the first document.

## Pairs well with

- `#obligations` — MUST items filter candidates first
- `#evaluate` — every remaining candidate scored on every criterion
- `#checklist` — every ledger item dispositioned, singletons included
- `#independence` — shared lineage counts as one vote
- `#minority` — every overruled position recorded
- `#steel-man` — each candidate at its strongest before ruling
- `#epistemic` — confidence per claim carried into the decision
- `#stop` — halt at gaps instead of filling them

## Common prompts

- `#Collate E1.md E2.md E3.md` — build the ledger
- `#Converge ledger.md` — decide from the ledger
- `#Converge ledger.md #steel-man` — strengthen each candidate before ruling
