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
| Crux — a factual conflict decides the outcome | `#Research` (read route) or `#Spike` (run route), as paste-ready commands | Settle it with evidence, then re-collate and converge again — see [Crux loop](#crux-loop) |
| Framing conflict — explorations answered different questions | `#Frame` | Fix the question before any answer can be chosen |
| Choice or Synthesis, confirmed by you | `#Spec`, `#Record` | Plan it, or record the decision |

Value conflicts don't exit — you rule on them inside the mode.

### Crux loop

1. The Crux names the question, a slug, a new finding path beside the ledger (`<ledger dir>/<slug>.finding.md`), and a route.
   - **read** — research suffices, by reading or quick probes of existing code.
   - **run** — the answer needs a stated prediction and an isolated workspace: building something new, timing or measuring, or a result that decides a MUST.
   The route picks the safeguards, not what research may do: research does run probes, and its findings say so.
2. Every step comes as a paste-ready prompt, because `/clear` drops the converge session and everything it knew.
3. Read route: `#Research #file <path> — <question>, then <tail>`. If its `# Research` section leaves the question unsettled, use the run command, which adds `# Spike` to the same file.
4. Run route: `#Spike <question> → <path>, then <tail>` — the spike hands off to its tail when answered.
5. Tail, on every command: `settle <other slugs>, and once all findings exist, <collate command>`; with one Crux, just the collate command. Settle in any order — whichever command you run last carries the next step. Embedded commands are backticked: the hook ignores a hashtag that follows a backtick, so only the leading tag of a pasted prompt activates.
6. Collate command: every exploration and finding path, the next ledger's name, and the lineage restated from the ledger's Sources, with findings independent. Then `/clear`, `#Converge <next ledger>`.

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
