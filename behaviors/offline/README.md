# Offline

An `#html` page for someone the server can't reach: you send them a file, they send you a file back.

## Why this exists

`#html` pages are served by html-channel on your machine, and Done wakes the LLM.
That needs a browser that reaches the server: no good for a teammate, or for a phone that can't reach your devbox.
Without a tag, you'd ask for a self-contained page and an export button, and get a new one-off every time.

`#offline` is a modifier on `#html`. The LLM writes and checks the page as usual, then exports an offline copy: one `.html` that runs from disk with no server.
The reader answers in their browser and clicks **Download answers**, which saves an `.edn` file. You hand that file to any LLM session.

## What changes

| | `#html` | `#html #offline` |
|---|---|---|
| What you get | a page URL | the path of an offline copy, `<page>@<rev>.offline.html` next to the page |
| Who answers | you, in a browser that reaches the server | anyone with the file |
| How answers come back | Done wakes the LLM | the reader sends the `.edn` from Download; you give it to the LLM |
| Waiting | a background `html-channel wait` | none |

The copy has no Done, no server banner and no Deeper buttons. It keeps answers in the reader's browser across reloads, and asks before they leave with answers not yet downloaded.
Diffs and hunk choices work without internet; highlighting and diagrams need it.

## Reading answers back

Give the LLM the `.edn` in any session with `#html`; `#offline` isn't needed to read it. Its first line names the command, `html-channel decisions --file`, and `#html` reads the result with the same rules as a page's answers.

- It names who answered: the name they typed, or `:author` for you when you downloaded from a connected page.
- When the page snapshot the answers were given at is missing (another checkout, a cleaned `ai/html-channel`), it says the answers couldn't be checked, and still reads them.
- A reader's re-pointed code-link roots are their own checkout: the LLM names them and doesn't ask you about switching.

Each file is one reader's answers. Nothing is written to the page's decision log.

## Where the copy runs

- Desktop Chrome and Safari: tested.
- Firefox: untested.
- iPhone: not supported. A local `.html` opens only in the Files preview, which runs no scripts; Share and "Open with…" offer no browser (tested 2026-11-24).
- Android: untested.

For a phone that can reach your machine over a VPN or tailnet, use html-channel's `HTML_CHANNEL_REMOTE_BASE` and plain `#html` instead.

## Privacy

The copy is the page as written. Its code links default to your checkout paths, which each reader can re-point in the code-links bar. The LLM mentions this before you send a copy.

## Requirements

html-channel 0.9.0 or newer (`html-channel version`). With an older one, the LLM says so and carries on with plain `#html`.
`#offline` needs `#html`: alone, it says so and does nothing more.

## Common prompts

- `#=spec #html #offline`: open questions as a file for a teammate
- `#=review #html #offline`: review findings someone else decides on, answered offline
