# Atlas

Explain as a map the reader walks, not a text they scroll.

## Why this exists

An LLM answers a hard question with pages of text, instantly. Reading them is the slow part: a linear explanation makes you hold where you are, the context, and the unfamiliar parts all at once, and when you get lost you can't zoom out.

`#atlas` makes the answer a map: a tree of nodes, each small enough to hold in mind, each openable into more.
Combined with `#html`, the map opens in a browser through [concept-atlas](https://github.com/roterski/concept-atlas), and it grows where you ask.

`#atlas` is a modifier: it works on a question ("explain X") and on any mode's output (research findings, a tour of code, a plan).

## Rules

- **Nodes.** Every node has a gist of at most 15 words that reads alone, and, once written, a summary and several representations of the same idea: explanation, analogy, diagram, example, check questions.
- **Tree.** A parent has 3–5 children, and its gist can be rebuilt from theirs. All children of a node relate to it the same way: parts, kinds or steps.
- **Order.** Read depth-first, nothing needs something that comes later.
- **Source.** For a question, the LLM infers the audience and the goal and states them; it doesn't ask. On another mode's output, that output is the content.

## DO NOT

- Write a gist that is only a label, with nothing behind it (`EmptyChunk`).
- Give a node a sixth child where an intermediate level is missing (`OverBranching`).
- Mix parts, kinds and steps under one parent (`MixedLadder`).
- Use a term before the node that introduces it (`PrerequisiteAfterUse`).
- Let two representations of a node state different facts (`DriftingRepresentation`).

## Output by channel

| With | The map is |
|---|---|
| `#html` | a concept-atlas map: you walk it with the keyboard, switch format and detail, and send requests (go deeper, explain differently, a question, a flag). Each request wakes the LLM, which grows the map while your tab stays where it was. How it's built lives in concept-atlas's [ATLAS.md](https://github.com/roterski/concept-atlas/blob/main/ATLAS.md), not here |
| nothing | one nested markdown outline: title, gist and summary per node, gists only at the deepest level |

A map lives in the project (`ai/html-channel/atlas-<slug>/`) and can be reopened in a later conversation.

## Requires

`#html` needs the `concept-atlas` command and html-channel 0.4.0 or newer.
`./install` and `./eca-install` install both with `bbin` when it's on your PATH. Otherwise:

```sh
bbin install io.github.roterski/html-channel
bbin install io.github.roterski/concept-atlas
```

## Pairs well with

- `#html`: the map you walk and grow
- `#=research`: findings as a map, each node carrying its sources
- `#=tour`: a codebase as a map of its parts
- `#=mentor`: check questions on every node

## Doesn't combine well with

- `#explorable`: one long page that goes all the way down; an atlas is many small nodes opened on demand. Pick one.
- `#zoom`: both decide how depth is revealed.
- `#file`: both claim the structured output.

## Known limitations

- Nothing checks that a map is a good decomposition, or that it is right. concept-atlas checks sizes and safety; the rules above are the LLM's job.
- Not yet evaluated against a good article on the same topic.

## Common prompts

- `How does Git store history? #atlas #html`
- `What do we know about the cache layer? #=research #atlas #html`
- `#atlas`: the map as a markdown outline in the reply
