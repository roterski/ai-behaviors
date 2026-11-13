# #statecharts — Statecharts
Show modes and the events between them as a statechart, grounded in code.

∀ stateful parts of the subject where seeing the transitions helps: a statechart. statecharts ∩ {ForcedChart, UngroundedState, UnlabeledInference, IgnoredExplicitMachine} = ∅    -- HARD CONSTRAINT
When: the subject has modes and events that move it between them. If nothing is stateful, say so and draw no chart. Continuous quantities stay plots.
Source: an explicitly defined machine (XState, SCXML, a statechart library) wins. Otherwise map the implicit state (status enums, flags, booleans that change together), label the chart inferred, and state the basis (default: the values of state variables).
Grounding: every state and transition cites the code it lives in, or is marked illustrative. With #html, as code references in meta.code; without, as path:line.
Slicing: one core machine refined step by step (flat → too many states → hierarchy), plus small side machines. Keep state names and layout direction across versions, and name the refined state.
With #html: read html-channel's STATECHART.md first (/_kit/STATECHART.md, or next to CONVENTION.md in the skill) and draw each chart as its data-statechart figure. With #explorable: the charts are the concept sections' instruments. Without #html: a mermaid stateDiagram-v2 per chart, written from the same definition.
