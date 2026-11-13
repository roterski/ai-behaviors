# Statecharts

Show modes and the events between them as a statechart, grounded in code.

## Why this exists

Most software behavior is a set of modes and the events that move between them: a request that loads, fails and retries; a form that is clean, dirty or saving.
Asked to explain it, an LLM writes prose or a list of flags, and the reader has to rebuild the machine in their head.
A [statechart](https://statecharts.dev/) shows it directly: states, events, guards, nesting and parallel regions.
With `#html`, the reader can also drive it: send events, change the values guards read, and step back through what happened.

`#statecharts` is a modifier: it works in any mode, and the output tags decide what the chart looks like.

## Rules

- **When.** The stateful parts of the subject get a chart, where seeing the transitions helps. If nothing is stateful, the LLM says so and draws nothing. Continuous quantities stay plots.
- **Source.** An explicitly defined machine (XState, SCXML, a statechart library) is charted as defined. Otherwise the LLM maps the implicit state (status enums, flags, booleans that change together), labels the chart inferred, and says what it's inferred from.
- **Grounding.** Every state and transition cites the code it lives in, or is marked illustrative.
- **Slicing.** One core machine refined step by step, flat first, then hierarchy where the flat version has too many states, plus small side machines. State names and layout stay the same across versions, and the prose names the state that was refined.

## Output by channel

| With | The chart is |
|---|---|
| `#html` | an interactive `data-statechart` figure on an html-channel page: event buttons, a context panel, an event log you can step back through, and links to the code. How it's built lives in html-channel's [STATECHART.md](https://github.com/roterski/html-channel/blob/main/STATECHART.md), not here |
| `#explorable` | the instrument of each concept section that is about state |
| neither | a static Mermaid `stateDiagram-v2` in markdown, with `path:line` references |

## Requires

`#html` needs html-channel 0.3.0 or newer for statecharts (`html-channel version`).
Update with `bbin install io.github.roterski/html-channel`.

## Pairs well with

- `#html`: the interactive chart
- `#=tour`: a codebase subsystem explained as the machine it implements
- `#explorable`: a long explainer whose stateful concepts get charts as instruments
- `#=research`: how a protocol or library behaves, as a chart

## Known limitations

- Nothing checks that a chart matches the code. html-channel checks the definition (unknown targets, undefined context keys, unreachable states) and that the chart responds; the match to the code is the LLM's job, which is why every state cites its code.
- Inferred charts are flat unless the LLM adds the hierarchy. No published method infers nesting or parallel regions from implicit state.
- Refining a state into a composite moves every other state in the drawing, so a chart grown across sections jumps. The prose names what changed.

## Common prompts

- `How does our upload flow work? #=tour #statecharts #html`
- `#=research #statecharts #html`: a protocol's states, driven on a page
- `Explain the editor's save logic #explorable #statecharts #html`
- `#statecharts`: a Mermaid state diagram in the reply
