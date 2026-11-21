# Dogfood key: `#decision-ready`, alone and with `#html`

Do not let the session under test read this file.
Each run below starts from a fresh session in this repo.
Runs 2 and 5 need html-channel 0.5.0 or newer and a browser.

## Plants

| ID | Plant | Where |
|---|---|---|
| P1 | Questions that one answer makes moot: an in-process cache has no eviction policy and no TTL. The controlling question gets buttons (no change event), and one dependent is a checkbox (shows "moot" as ticked unless blanked) | run 2 |
| P2 | A mode that forbids recommendations (`#=research`) next to one that allows them (`#=design`), on the same prompt | runs 1, 3 |
| P3 | `#Research` carries `#epistemic`, which labels every claim on its own | run 1 |
| P4 | A task with no open choice | run 4 |
| P5 | A two-hunk change: a harmless comment edit, and a depth-limit change from 8 to 80 that the ECA hook (`hooks/eca-inject-behaviors.sh:80`), `src/ai_behaviors/core.clj:17` and the README ("max 8") don't follow. `tests/test-inject-behaviors.sh` fails `composite_depth_limit_exceeded` (144/145); `bb parity` still passes, because no parity prompt nests composites | run 5, `fixture/review.patch` |

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
4. Pick in-process, then reload the page. Then pick Redis, and pick in-process again.
5. Clear Q2, wait 2 s, then reload.
6. In chat: "Add a question: the TTL in seconds, which only matters for Redis." On the new revision, leave Q1 as it is, so the new question's link is newer than the answer.
7. Write "keep the TTL anyway" in Q3's note, then click Done.

- M1: after step 1, Q2 and Q3 are greyed out, not disabled, and both are `"moot"`; Q3's box is unticked.
- M2: after step 2, Q1, Q2 and Q3 are `null`, and Q2 and Q3 are no longer greyed out.
- M3: after step 3, the same as M2: Clear on the controlling question takes the mootness back.
- M4: after the reload in step 4, Q2 and Q3 are still `"moot"` and greyed out, Q3's box is still unticked, and nothing new was recorded on load. Picking Redis makes both `null` and no longer greyed; picking in-process makes both `"moot"` again.
- M5: after step 5, Q2 is `null` and still greyed out, before and after the reload.
- M6: after step 6, the TTL-seconds question is greyed out with nothing recorded.
- M7: the reply calls Q2 deferred (cleared, so not moot) and the TTL-seconds question moot (by the links, never recorded), and asks about Q3's note before acting on it.
- M8: the page has a lean on each question, and each option has pick-if, if-wrong, confidence and source.

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

Any failure is a bug report against `#decision-ready`, or against `#html`'s "With #decision-ready" clause for M1–M5 and H1–H3.
