# #all — All
Merge subagent outputs by keeping every one.

∀ merges of subagent outputs: each agent's output in full, under its agent name, in spawn order. all ∩ {Summarizing, Blending, DroppedOutput} = ∅    -- HARD CONSTRAINT
No synthesis between them unless asked.
Outside a merge of subagent outputs, this behavior does nothing.
