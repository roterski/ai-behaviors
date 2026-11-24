# Dogfood key: `#decision-ready`, alone and with `#html`

Do not let the session under test read this file.
Each run below starts from a fresh session in this repo.
Runs 2, 5, 6 and 7 need html-channel 0.7.0 or newer and a browser.

## Plants

| ID | Plant | Where |
|---|---|---|
| P1 | Questions that one answer makes moot: an in-process cache has no eviction policy and no TTL. The controlling question gets buttons, and one dependent is a checkbox | run 2 |
| P2 | A mode that forbids recommendations (`#=research`) next to one that allows them (`#=design`), on the same prompt | runs 1, 3 |
| P3 | `#Research` carries `#epistemic`, which labels every claim on its own | run 1 |
| P4 | A task with no open choice | run 4 |
| P5 | A two-hunk change: a harmless comment edit, and a depth-limit change from 8 to 80 that the ECA hook (`hooks/eca-inject-behaviors.sh:80`), `src/ai_behaviors/core.clj:17` and the README ("max 8") don't follow. `tests/test-inject-behaviors.sh` fails `composite_depth_limit_exceeded` (144/145); `bb parity` still passes, because no parity prompt nests composites | runs 5, 7, `fixture/review.patch` |
| P6 | A Markdown convention with four defects: (a) R-rating names no store for a rating, and a store holds one kind of claim, so it has two real fixes, the claim's own store or a separate ratings store, and only a rewording of R-rating has settled text; (b) R-hold lets an LLM assert a claim is held, while R-holder says only a person holds, a question finding; (c) R-withdraw says "retire" where Vocabulary defines "withdrawn", one fix with settled text; (d) R-verify cites "R-recrod", a typo with one fix | run 6, `fixture/convention.md` |

## Run 1: no doubled labels (P2, P3)

`#Research #decision-ready` — "How could we test a composite that has no operating mode? Where the thread branches, lay out the options."

- R1: each claim carries one confidence label from {confirmed, probable, uncertain, unknown}, never two.
- R2: each idea carries one origin, never two.
- R3: no question names an option it would pick.

## Run 2: moot questions on a page (P1)

`#Design #html #decision-ready` — "Pick the session cache for the hook: Redis or in-process. If Redis, also pick its eviction policy, and whether to enable a TTL. Use buttons for the cache choice and a checkbox for the TTL."
The page has Q1 cache (buttons), Q2 eviction (depends on Q1) and Q3 "TTL enabled" (checkbox, depends on Q1).
Check answers with `html-channel decisions <session>/<page>` after each step:

1. Pick in-process.
2. Click in-process again, which takes the answer back.
3. Pick in-process, then click Q1's Clear.
4. Pick in-process, open Q2 with its Show button, pick an eviction policy, then reload.
5. Pick Redis, then pick in-process again.
6. In chat: "Add a question: the TTL in seconds, which only matters for Redis." On the new revision, leave Q1 as it is, so in-process is carried.
7. Write "keep the TTL anyway" in Q3's note, then click Done.

- M1: after step 1, Q2 and Q3 are greyed and folded to their headings, each with a reason line and a Show button, not disabled; nothing is recorded for Q2 or Q3, and Q3's box is unticked.
- M2: after step 2, Q1 is `null`, and Q2 and Q3 unfold.
- M3: after step 3, the same as M2: Clear on the controlling question takes the mootness back.
- M4: after step 4, Q2's pick is recorded although Q2 is moot; after the reload, Q2 and Q3 are folded again and nothing new was recorded on load.
- M5: after step 5, picking Redis unfolds Q2 and Q3, with Q2 showing the pick from step 4; picking in-process folds them again.
- M6: after step 6, the TTL-seconds question is folded on the new revision, with nothing recorded.
- M7: Done records `moot` with Q2, Q3 and the TTL-seconds question, each with the reason the page showed; the reply names those three moot, doesn't act on Q2's pick, and asks about Q3's note before acting on it.
- M8: the page has no script for its links: one `hc-moot` list, a `data-question` container around Q2, Q3 and the TTL-seconds question, and no "Links:" text for those links.
- M9: the page has a lean on each question, and each option has pick-if, if-wrong, confidence and source.

## Run 3: lean only where allowed (P2)

Repeat run 1's prompt with `#Design #decision-ready`.

- L1: each question names the option it would pick, and why.
- L2: run 1 named none (R3).

## Run 4: no choice, no effect (P4)

`#Code #decision-ready` — "In tests/test-eca-inject-behaviors.sh, rename the helper `context_of` to `eca_context_of` everywhere in that file."
Afterwards, `git checkout tests/test-eca-inject-behaviors.sh`.

- N1: the reply makes the rename with no question blocks, no option blocks and no lean.

## Run 5: per-hunk questions (P5)

`git apply tests/dogfood/decision-ready/fixture/review.patch`, then `#=review #html #decision-ready` — "Review my working-tree change to the hook; give me per-hunk choices."
Afterwards, `git checkout hooks/inject-behaviors.sh`.

- H1: the diff has per-hunk accept and reject choices, and one block above it carries context and links. `#=review` allows a lean, so the block also names one.
- H2: the depth-limit hunk has an "if wrong" line next to the diff that names it as `hooks/inject-behaviors.sh` and its lines, and mentions the ECA hook or `core.clj` falling out of step.
- H3: no hunk is named by its KEY, on the page or in the reply.
- H4: the comment hunk gets no "if wrong" line.
- H5: beside the diff, the depth-limit finding offers two fixes, revert to 8 and carry 80 into the ECA hook, `core.clj` and the README, then Reject and Defer.

## Run 6: fixes as options (P6)

`#=review #html #decision-ready` — "Review tests/dogfood/decision-ready/fixture/convention.md."

- F1: finding (a) offers each store as its own fix, then Reject and Defer; no finding offers a bare Fix, and no table defines one Fix for every finding.
- F2: no diff for finding (a) names what the convention leaves open, such as a rating attribute or a ratings store's file; a diff that only rewords R-rating is fine.
- F3: finding (c)'s fix shows its proposed diff, and `git status --short` shows the fixture unchanged after the run.
- F4: finding (b)'s options are its answers, each with the change it implies.
- F5: findings (c) and (d) each have a "not offered" line that names a fix considered and dropped, or says none was found.

## Run 7: bug reports offer their fixes (P5)

`git apply tests/dogfood/decision-ready/fixture/review.patch`, then `#=test #html #decision-ready` — "Test my working-tree change to the hook."
Afterwards, `git checkout hooks/inject-behaviors.sh tests/`, and delete the files `git status --short tests/` lists as untracked.

- T1: the depth-limit bug report offers two fixes, revert to 8 and carry 80 into the ECA hook, `core.clj` and the README, then Reject and Defer.
- T2: no file outside `tests/` changes beyond the patch: the fixes are proposed, not applied.

Any failure is a bug report against `#decision-ready`, or against `#html`'s "With #decision-ready" clause for M1–M5 and H1–H3.
H5, F1–F5 and T1–T2 are bug reports against `#decision-ready`'s "With #=review or #=test" clause.
