# html

Present anything that needs your input as an interactive local HTML page instead of markdown.

## What it does

`#html` is an output-channel modifier. It doesn't change how the LLM thinks, only where its questions and output go.
Instead of a markdown list of options, the LLM writes an [html-channel](https://github.com/roterski/html-channel) page into `<project>/ai/html-channel/<session>/<page>.html`.
You open it in a browser, answer with buttons and fields, and click Done. The LLM then reads your answers back.

How a page is built lives in html-channel's `CONVENTION.md`, not here, so the two can't drift apart.
This behavior owns what each question offers and how the LLM reads your answers.

## Questions on a page

- Every question has a note field below it: an answer the LLM didn't predict, or a comment. The LLM gets both your choice and your note.
- Clear, or clicking the chosen option again, takes back a choice and keeps your note.
- A question with no choice and no note is deferred: the LLM names it in its reply and doesn't act on it.
- A note alone is your answer. If it contradicts your choice, the LLM asks before acting.

## How it reaches the page

- **MCP tools available** (`channel_setup`, `check_page`, `get_decisions`): the LLM writes the page, renders it in headless Chrome to catch errors and check both color schemes, gives you the URL and ends its turn. After you click Done and reply, it reads your answers with `get_decisions`.
  If you clicked a Deeper button instead, the LLM expands what you asked for in a new revision and gives you the URL again.
- **CLI only**: the LLM serves the page with `html-channel serve`, checks it with `html-channel check`, gives you the URL, and reads your answers with `html-channel decisions` after you say "done".
- **Neither installed**: the LLM says so and falls back to markdown.

`./install` and `./eca-install` install the `html-channel` command with `bbin` when it's on your PATH. Otherwise they print the command to run.

## Common prompts

- `#=review #html`: review findings as a page, with a decision per finding
- `#=design #html`: candidates side by side, and you pick one on the page
- `#=spec #html`: open questions as fields
- `#=tour #zoom #html`: a code tour, one zoom level per page revision; Deeper buttons pick where to zoom next

## Doesn't combine well with

- `#file`: both claim the structured output. `#file` writes it to a markdown file, and `#html` puts it on a page. ai-behaviors has no way to make modifiers exclusive, so pick one.
