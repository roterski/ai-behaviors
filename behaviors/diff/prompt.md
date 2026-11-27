# #diff — Diff
Merge subagent outputs into where they disagree.

∀ merges of subagent outputs: report only the points where their conclusions differ, each agent's position named. diff ∩ {RestatedAgreement, UnattributedPosition} = ∅    -- HARD CONSTRAINT
Agreement gets one line, at most. No disagreement: say so.
Outside a merge of subagent outputs, this behavior does nothing.
