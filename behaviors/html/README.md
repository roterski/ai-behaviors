# html

Present anything that needs your input as an interactive local HTML page instead of markdown.

## What it does

`#html` is an output-channel modifier. It doesn't change how the LLM thinks, only where its questions and output go.
Instead of a markdown list of options, the LLM writes an [html-channel](https://github.com/roterski/html-channel) page into `<project>/ai/html-channel/<session>/<page>.html`.
You open it in a browser, answer with buttons and fields, and click Done. The click wakes the LLM, which then reads your answers back.

How a page is built lives in html-channel's `CONVENTION.md`, not here, so the two can't drift apart.
This behavior owns what each question offers and how the LLM reads your answers.

## Questions on a page

- Every question has a note field below it: an answer the LLM didn't predict, or a comment. The LLM gets both your choice and your note.
- Clear, or clicking the chosen option again, takes back a choice and keeps your note.
- A question with no choice and no note is deferred: the LLM names it in its reply and doesn't act on it.
- A note alone is your answer. If it contradicts your choice, the LLM asks before acting.
- With `#decision-ready`, a question or option another answer makes moot greys out as you answer: a moot question folds to its heading and the reason, with a Show button to open it, and its answer stays as you left it. On Done the page records what was moot, with the reasons: the LLM names those questions as moot and doesn't act on their answers. A note on one, or a moot option you chose anyway, makes the LLM ask before acting.

## Code links

Code on a page links to the code it came from.
The LLM declares each repo it read and marks every code block and inline mention with its file and lines, following html-channel's `CONVENTION.md`.
A collapsed bar at the top of the page lets you open the code in VS Code or on GitHub, copy its path, and point each repo at your own checkout.
Your settings stay in your browser, per page, and "Save as default" shares them with other pages of the same repo.

When you click Done, the LLM also gets the checkout you used for each repo.
If it differs from the one the LLM read, the LLM names both and asks whether that's expected and whether to switch to yours, before it acts on your answers.

## Code and diffs

Code on a page is colored by its language, which the LLM names or which comes from the file it links to.
Changes to code are shown as diffs, not as before and after copies: changes already made as `git diff` output, and edits the LLM proposes as their old and new text.
A diff shows a split view when there's room and marks the changed words. For a proposed edit, you can also open the unchanged lines around each change.

When you review changes, each hunk can carry its own choices (accept or reject, say), with Clear and a note like any other question.
On Done, the LLM also gets which file and lines each hunk covers, and names hunks that way in its reply.
An answer carries over to a new revision of the page as long as its hunk didn't change. When the hunk did change, the LLM treats your old answer as stale: it names it and doesn't act on it.

## How it reaches the page

- **MCP tools available** (`channel_setup`, `check_page`, `get_decisions`): the LLM writes the page and renders it in headless Chrome to catch errors and check both color schemes.
  Then it starts `html-channel wait` as a background command and ends its turn with the URL, so the chat stays free: you can ask about the page or have it reshaped before you click Done.
  The URL comes last because some clients hide text written between tool calls.
  Clicking Done ends the wait, and its exit wakes the LLM with your answers. You don't need to type "done".
  If you clicked a Deeper button instead, the LLM expands what you asked for in a new revision, waits again and gives you the URL again.
  Every rewrite of the page ends the old wait and starts a new one, so only Done on the latest revision counts.
- **CLI only**: the LLM serves the page with `html-channel serve`, checks it with `html-channel check`, starts `html-channel wait` the same way, and gives you the URL.
- **No background wake** (a client that can't wake the LLM when a background command exits): you say "done" in chat, and the LLM reads your answers with `get_decisions` or `html-channel decisions`.
- **Neither installed**: the LLM says so and falls back to markdown.

`./install` and `./eca-install` install the `html-channel` command with `bbin` when it's on your PATH. Otherwise they print the command to run.
`#html` needs html-channel 0.7.0 or newer (`html-channel version`).
Update with `bbin install io.github.roterski/html-channel`.

## Common prompts

- `#=review #html`: review findings as a page, with a decision per finding
- `#=design #html`: candidates side by side, and you pick one on the page
- `#=spec #html`: open questions as fields
- `#=tour #zoom #html`: a code tour, one zoom level per page revision; Deeper buttons pick where to zoom next
- `#Design #html #decision-ready`: every option with its full case; linked questions grey out as you answer

## Doesn't combine well with

- `#file`: both claim the structured output. `#file` writes it to a markdown file, and `#html` puts it on a page. ai-behaviors has no way to make modifiers exclusive, so pick one.
