# Explorable

Explain in depth, one concept at a time, each with something to drive.

## Why this exists

Asked to explain a complex topic, an LLM writes a wall of prose or a list of terms: every concept at once, none of them motivated, nothing to try.
The explanations people remember work differently.
[Ciechanowski's articles](https://ciechanow.ski/archives/), [Bret Victor's explorable explanations](http://worrydream.com/ExplorableExplanations/) and [Nicky Case's explorables](https://blog.ncase.me/explorable-explanations/) start from something you've seen, build a wrong model and break it, and give every concept a small instrument you can drive.

`#explorable` makes that structure a constraint.
Combined with `#html`, the result is one long interactive page; without it, a gradual markdown document with mermaid diagrams.

## The arc

The page as a whole follows:

phenomenon → smallest faithful toy → naive model → its failure → fix → combine → payoff → limits

## Each concept

6–12 concept sections, each with, in order:

| Part | What it is |
|---|---|
| Need | the problem the previous section left, which this one fixes |
| Setup | a sentence ending in ":" that says what to do with the instrument |
| Instrument | something the reader drives (with `#html`) or a mermaid diagram (without) |
| Notice | a line starting "Notice that…", saying what to see |
| Simplification | what this part of the model leaves out, in plain words |

The page closes with **Limits** (where the model stops being true), **Further reading** and **Sources**.

## Rules

- Research the topic before writing. Every factual claim and every constant in a simulation has a source, or is listed under Sources as illustrative.
- Under a mode that excludes research (`#=frame`), explain only from what the conversation already holds, and say so in the first line.
- With `#html`, the page follows html-channel's [EXPLORABLE.md](https://github.com/roterski/html-channel/blob/main/EXPLORABLE.md), which owns how the page is built: markup, the kit's controls (scrubbable numbers, state links, timelines, a global pause, KaTeX) and the checks.
- The page is report-only, unless the explanation leads to choices you should make. Then it's a decision page with each question next to the section it's about. "What's still unclear?" belongs in chat, not on the page.

## DO NOT

- Use a term before the section that introduces it.
- Start from the abstraction; start from an instance.
- Add an interactive that doesn't change anything the reader can name.
- Simplify silently, or end without saying where the model breaks.
- State a constant without a source or an "illustrative" label.

## What `#html` adds

html-channel's `check_page` runs two checks on an explorable page:

- **A structure lint:** section count, an instrument per section, Limits and Sources headings, labeled controls.
- **An interaction probe:** it drives every instrument's controls in headless Chrome and reports any instrument that doesn't change (`inert`).

The LLM fixes what they report before giving you the URL.
They can't judge whether the explanation is good; the checklist in EXPLORABLE.md covers what the tools can't.

## Requires

`#html` needs html-channel 0.2.0 or newer for explorables (`html-channel version`).
Older versions lack EXPLORABLE.md, the controls and the checks. Update with `bbin install io.github.roterski/html-channel`.

## Pairs well with

- `#html` — the interactive page this behavior is designed for
- `#=research` — investigate a topic and report it as an explorable
- `#=tour` — a codebase subsystem explained with instruments
- `#=mentor` — teaching, with the explorable as the lesson
- `#epistemic` — confidence labels on claims, for topics where sources disagree

## Doesn't combine well with

- `#zoom`: it shows one level per step and waits for you to pick the next; an explorable is one long page that goes all the way down.
- `#file`: both claim the structured output. Pick one.

## Known limitations

- Not yet evaluated across topics. The structure is checked, but whether a page explains well is not.
- The probe drives controls with synthetic events. A drag-only instrument whose handler checks `event.isTrusted` is reported `unprobed`, and needs checking by hand.
- Ciechanowski-scale pages (dozens of hand-built 3D demos) are out of reach. Expect one focused instrument per concept.

## Common prompts

- `How does TCP congestion control work? #=research #explorable #html`
- `Explain our job scheduler #=tour #explorable #html`
- `#=mentor #explorable` — the lesson as a markdown document with mermaid diagrams
