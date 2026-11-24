# Dogfood key: `#offline`, with and without `#html`

Do not let the session under test read this file.
Each run below starts from a fresh session in this repo.
Runs 1–3 and 5 need html-channel 0.9.0 or newer and a desktop browser.

## Plants

| ID | Plant | Where |
|---|---|---|
| P1 | A page with a code reference, so the copy carries a repo root | run 1 |
| P2 | An answers file whose page snapshot is gone | run 3 |
| P3 | A reader who re-points the repo root in the code-links bar | run 5 |
| P4 | `#offline` without `#html` | run 4 |

## Run 1: export, no wait (P1)

`#=spec #html #offline` — "Ask me two questions about how `hooks/inject-behaviors.sh` should handle an unknown tag. Show the line where it looks tags up."

- E1: the page is checked (`check_page` or `html-channel check`) before it's exported.
- E2: it's exported with `export_page` or `html-channel export`, and the reply gives the copy's path, `…@<rev>.offline.html`.
- E3: no background `html-channel wait` runs, and the reply gives no page URL.
- E4: the reply says the copy opens from disk in a desktop browser, not on an iPhone, and that answers come back as the `.edn` from Download answers.
- E5: the reply says the copy carries the repo's root path before you send it.

## Run 2: answer from disk, read back fresh

Open run 1's copy from disk in Chrome or Safari. Answer one question, type a name ("Sam"), reload, check the answer is still there, then click Download answers.
In a new session: `#html` — "Here are my teammate's answers: <path to the .edn>".

- R1: the session runs `html-channel decisions --file` (or `get_decisions` with `file`) without being told the command.
- R2: it names the respondent, Sam.
- R3: it applies `#html`'s rules: the unanswered question is named as deferred and not acted on.

## Run 3: snapshot missing (P2)

Rename run 1's `<page>@<rev>.html` snapshot, then repeat run 2's second step.

- C1: the session says the answers couldn't be checked against the page, with the tool's reason, and still reports them.
- C2: it doesn't refuse, and doesn't guess a revision.

Put the snapshot back afterwards.

## Run 4: alone (P4)

`#offline` — "Ask me whether to rename `context_of` in the ECA test script."

- A1: the session says `#offline` needs `#html`.
- A2: it carries on as without `#offline`: no export, no html-channel page.

## Run 5: a reader's own checkout (P3)

Before downloading in run 2, open the code-links bar and set the repo root to `/home/sam/ai-behaviors`.

- S1: the session names Sam's root.
- S2: it doesn't ask whether to switch to it, as `#html` would for your own override.

Runs 1 and 4 test `#offline`. Runs 2, 3 and 5 test `#html`'s Answers file rule, which reads a file without `#offline`; R1 also tests the command the file's first line names.
