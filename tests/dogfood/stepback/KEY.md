# Dogfood key: stuck session → `#Stepback` → fresh-session handoff

Do not let the session under test read this file. The step-back file goes wherever the handoff lines name it — `<path>` below — never next to this key.

## Run

0. `rm -rf ai/stepback/` in this repo — start from a clean state (the handoff's default directory).
1. Fresh session, `#Code`. Send these turns one at a time, each after the previous reply, whatever it proposed:
   1. "The checkout confirmation modal renders behind the sticky header on the product page. Fix it."
   2. "Fixed there. Now on the cart page it's behind the promo banner."
   3. "Cart fixed. I also tried rendering the modal into a portal on `document.body` — on the account page it's still behind the sidebar."
   4. "Now the dropdown menus on the account page render under the layout. Every fix moves the bug."
2. `#Stepback`.
3. Reply: "I want the portal framing." If no framing is about the portal, reply "None of these — reject all."
4. Paste the handoff lines as given, `/clear` included. `<path>` is the path they name; don't change it.
5. In the fresh session, pick any framing — the point is that new ones appeared. For F5, reject all instead and repeat steps 4–5 once.

## Plants

| ID | Plant | Where |
|---|---|---|
| P1 | A goal-level reframing exists: success is "every overlay layers correctly on every page", not "this modal on the reported page" | turns 1–4 |
| P2 | Inherited assumption: z-index numbers decide what paints on top; stacking contexts were never checked | turns 1–2 |
| P3 | Already-tried framing: the portal was tried in turn 3, so choosing it should trigger the handoff | turn 3 |

## Pass/fail — in-session (`#Stepback`)

- B1: produces goal → path → assumptions → framings → exit, in that order; no new fix proposed before the framings.
- B2: the goal is restated from turn 1's words, not from turn 4's.
- B3: at least two framings; each names its level (fix, diagnosis, goal).
- B4: a goal-level framing appears (P1), or the step-back says why none changes the goal.
- B5: P2 appears among the assumptions, labeled inherited.
- B6: the exit picks or confirms with a reason, and recommends a line matching the level: goal → `#Frame`; diagnosis → `#Research`, or `#Spike` if reading can't settle it; fix → `#Design` or `#Code`.
- B7: after step 3 (P3), it offers the fresh-session handoff as three paste-ready lines: `#Stepback #file <path>`, `/clear`, `#Stepback <path>`.
- B8: the offered `<path>` is inside the project, not under a session scratchpad or temp directory.

## Pass/fail — fresh session (`#Stepback <path>`)

- F1: `<path>` holds one `# Step Back` section with goal, path, assumptions, framings and exit.
- F2: the fresh session reads the section and treats its path and framings as tried — no framing repeats one from the file.
- F3: at least two new framings, each labeled with its level.
- F4: `<path>` records the prior mode (`#Code`); a diagnosis-level pick in the fresh session routes to `#Research` (or `#Spike`), not `#Debug`.
- F5: reject all again, paste the handoff lines again, and run a third session: the file still lists every earlier framing as tried, no framing repeats, and no exit asks you to edit the file by hand.
- F6: every handoff offered in a session started from `<path>` reuses that `<path>`; the default `ai/stepback/<slug>.md` appears only in the first, in-session handoff.

Any failure is a bug report against `=stepback`.
