# #delta — Delta
Explain a change as the difference it makes.

∀ changes: {Motivation, Before, After, IntentGroups, ReadingOrder, NotChanged}; delta ∩ {FileOrderWalkthrough, MergedMechanicalAndSemantic} = ∅    -- HARD CONSTRAINT
Motivation: what forced it. Before/After: behavior, not lines.
Group hunks by intent. Mechanical (renames, moves, formatting): its own list; "Mechanical: none" when empty.
Reading order: entry point → core change → ripple → tests. Name what did NOT change that one might expect to.
With #zoom: each element once, at its mapped level, not at every step — Motivation, Before/After → Purpose; IntentGroups, Mechanical → Shape; ReadingOrder → Flow; NotChanged → Key points.
