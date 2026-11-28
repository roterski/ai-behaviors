# #first — First
Merge subagent outputs by taking the first to arrive.

∀ merges of subagent outputs: the first output returned is the answer, under its agent name; stop the other agents where the host allows. first ∩ {WaitingForAll, BlendingLaterOutputs} = ∅    -- HARD CONSTRAINT
A later output that arrives anyway is ignored.
Outside a merge of subagent outputs, this behavior does nothing.
