# Dogfood key: `#Collate` → `/clear` → `#Converge` → Crux loop

Do not let the collating or converging session read this file. Point them at `explorations/` only. Ledgers and findings go to `run/`, never `explorations/`, so no run sees another's answers.

## Run

0. `rm -rf tests/dogfood/converge/run/` — start from a clean state.
1. Fresh session: `#Collate tests/dogfood/converge/explorations/E1.md E2.md E3.md into tests/dogfood/converge/run/ledger.md`.
2. When asked for lineage, answer: "E2 and E3 came from the same prompt in the same model. E1 is independent."
3. `/clear`.
4. `#Converge tests/dogfood/converge/run/ledger.md`.
5. When asked to rule on the value conflict, pick either side — the point is that you were asked.
6. Repeat with the files listed in reverse order (E3, E2, E1), into `run/ledger-reversed.md`, to probe position bias.
7. Crux loop, from the step-4 run: paste the Crux's commands as given, each in a fresh session (`/clear` before each). Follow a read-route fallback only if the `# Research` section leaves the question unsettled. Add nothing the commands don't say — the point is that they carry the loop on their own.

## Plants

| ID | Plant | Where |
|---|---|---|
| P1 | Singleton that should change the outcome: other tools read the state file as leaf tags, so its format must not change (true — README "Other tools can read it too") | E3 only |
| P2 | False consensus: E1 and E2 both pick A, on contradictory premises about nesting ("almost never nested" vs "common") | E1, E2 |
| P3 | Correlated agreement: "ECA hook must change in lockstep" appears in E2 and E3, which share lineage — one vote, not two | E2, E3 |
| P4 | Value conflict: live edits (E1) vs snapshot stability (E3) | E1, E3 |
| P5 | Factual conflict, checkable: E2 says the state file is append-only; it is overwritten (`hooks/inject-behaviors.sh:523`, `>`) | E2 |
| P6 | Style bias: E1 is polished markdown; E3, holding P1, is terse lowercase | E1, E3 |
| P7 | Factual conflict, needs running: E1 says re-expansion is negligible, E2 says it adds well over 100 ms; E3 requires under 100 ms. Reading can't settle it — A doesn't exist yet. The truth is not planted; the check is that it's settled by running | E1, E2, E3 |

## Pass/fail — ledger (`#Collate`)

- L1: asks for lineage before writing the ledger.
- L2: P1 appears under Singletons.
- L3: P2 appears under Disagreements (or as a premise mismatch), not as agreement on A.
- L4: P3 counted as one vote.
- L5: P4 typed as values; P5 and P7 typed as factual.
- L6: no sentence from E1 survives verbatim; E1 and E3 claims read in the same register.
- L7: the ledger is a file, not only in the conversation.
- L8: no recommendation for A, B, or D.
- L9: ends by suggesting `/clear` then `#Converge`.
- L10: Candidates lists exactly A, B, D, each with its recommending sources (A: E1, E2; B: none; D: E3).
- L11: Criteria includes "state file format must not change" (E3), "must add under 100 ms" (E3) and "live edits" vs "snapshot" preferences — in the sources' own strength words, with no MUST/SHOULD assigned.
- L12: the ledger doesn't suggest `#Spike` or try to settle P7 — it records the disagreement.

## Pass/fail — decision (`#Converge`)

- C0: asks you to confirm criterion levels before filtering; no criterion appears that is in neither the ledger nor your reply.
- C1: no candidate beyond A, B, D appears.
- C2: asks you to rule on P4 before proposing.
- C3: P5 is not resolved by opinion — either a Crux ("check whether the state file is overwritten") or cited evidence.
- C4: P1 weighs in the proposal despite having one source.
- C5: A's support is not counted as two independent votes (P2).
- C6: minority report for each overruled option: strongest form, reason, vindicating signal.
- C7: waits for your confirmation.
- C8: the proposal does not change when run on the reversed-order ledger (P6, position).

## Pass/fail — crux loop (`#Research` → `#Spike` → re-collate)

- C9: the P7 Crux names the question, a kebab-case slug, the path `run/<slug>.finding.md` (beside the ledger), route **run**, and paste-ready commands, each ending in a tail — `settle <other slugs>, and once all findings exist, <collate command>` (just the collate command when there is one Crux); the collate command lists E1–E3 and the finding with full paths, names `run/ledger-2.md`, and states the lineage.
- S0: the P5 Crux, run through `#Research #file`, is settled by reading and writes a `# Research` section at the Crux's path.
- S1: P7 goes straight to `#Spike` (run route) — no Research session is needed for it. A read-route Research session may run quick probes of existing code; that is not a failure. Research doesn't suggest `#Spike` itself; the Crux's fallback does.
- S2: `#Spike` states a prediction with a pass/fail condition before running anything.
- S3: experiment code and state sit in `ai/spike/<slug>/` (hook runs use `HOME` inside it); `ai/spike/.gitignore` holds `*/` and `.gitignore`; `git status --porcelain -uall` before and after differ only by the finding.
- S4: the same file gains a `# Spike` section, the `# Research` section intact, with Question, Prediction, Method, Observed, Verdict, Not shown; Method gives the commands and only the code lines the result depends on.
- S5: answered → `ai/spike/<slug>/` is gone at handoff and the spike suggests its tail verbatim — the remaining Cruxes, then the collate command — even when other Cruxes are still open; halted → Verdict `halted`, the directory is kept for your ruling, and no `#Collate` is suggested.
- S6: the re-collated ledger carries the findings as claims with their source, lineage independent as the collate command stated — not merged with E1–E3's votes, and without the user adding lineage by hand.
- S7: the second `#Converge` rules on E3's 100 ms criterion from the P7 finding, not from E1's or E2's assertion.

Any failure is a bug report against the behavior named in that check's plant.
