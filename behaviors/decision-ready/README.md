# Decision-ready

Every choice arrives with what it takes to make it.

## Why this exists

Asked to choose, you often get a list of option names and a sentence each.
To decide, you need more: what's true now, what each option changes, when it's the right one, what it costs if it's wrong, and how sure the LLM is.
Without a tag, you add "explain each choice, provide context, alternatives, code snippets and screenshots" to every prompt.

`#decision-ready` is a modifier: it works in any mode that puts a choice to you, on an html-channel page or in markdown.
Turns that put no choice to you are unchanged.

## Rules

Each question carries:

| Element | What it is |
|---|---|
| Context | What's true now |
| Alternatives | The options, plus what wasn't offered and why |
| Links | How answering it changes other questions in the same output |
| Lean | The option the LLM would pick, and why. Left out in modes that forbid recommendations: `#=research`, `#=tour`, `#=probe`, `#=frame`, `#=route` |

Each option carries:

| Element | What it is |
|---|---|
| Explanation | What the option is |
| Own context | Only what differs from the question's context |
| Pick this if | When it's the right one |
| If wrong | The consequence, and how hard it is to undo |
| Confidence | `confirmed`, `probable`, `uncertain` or `unknown`, as `#epistemic` labels it |
| Source | Research finding, established pattern, user input, domain analogy or LLM inference, as `#provenance` labels it |
| Code and visuals | When they exist or can be made: repo code, captures, diagrams. An option that changes code shows its own diff, against the same base as its sibling options |

The labels are the same with or without `#epistemic` and `#provenance`, so output reads the same either way.
`#concise` still applies: it trims each sentence, not the elements.

## Output by channel

| With | Questions and options are |
|---|---|
| `#html` | an html-channel page. Code changes are kit diffs. When an answer makes another question or option moot, the page greys it out as you answer (a question folds to its heading and the reason) and records `moot` on Done. A diff with per-hunk choices is one question, with its context, lean and links above the diff |
| neither | markdown: one block per question, one labelled block per option. Code changes are fenced `diff` blocks |

How a page is built, its links included, lives in html-channel's `CONVENTION.md`. How the LLM reads `moot` and per-hunk answers lives in `#html`'s prompt, because only pages have them.

## With other tags

Overlapping tags don't double the output: each pair gives one statement.

| With | Merged |
|---|---|
| `#epistemic` | one confidence label per claim |
| `#provenance` | one origin per idea |
| `#downstream` | one trace of consequences, which also serves as "if wrong" |
| `#evaluate` | its table is the alternatives; its rejected items are what wasn't offered |
| `#assumptions` | choices the LLM made stay in its list; only choices put to you appear here |

## Requires

With `#html`: html-channel 0.7.0 or newer, the same as `#html` itself (`html-channel version`).
Update with `bbin install io.github.roterski/html-channel`.

## Common prompts

- `#Design #html #decision-ready`: candidates on a page, each with its full case; linked questions grey out as you answer
- `#Frame #html #decision-ready`: clarifying questions with the context to answer them
- `#=review #html #decision-ready`: findings and per-hunk choices, framed above each diff
- `#Spec #decision-ready`: open spec questions in markdown, each option with its cost if wrong

## Doesn't combine well with

- `#proceed`: it makes open choices instead of putting them to you, so there's little for `#decision-ready` to act on. Its choices go to its own list.

## Known limitations

- Nothing checks the elements against the code or the facts. Confidence and source labels make the basis visible, which is all the tag can do.
- Options inside a `<select>`, checkboxes and text fields can't be moot one by one, and a link can't match an answer that contains a space, `=` or `|`.
