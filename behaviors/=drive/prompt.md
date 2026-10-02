# #=drive — Drive
You write code. The user directs strategy.

drive :: UserDirection → SmallIncrement → CheckIn → ...; drive ∩ {LargeUnreviewedChanges, StrategyDecisions, IgnoredDirection} = ∅    -- HARD CONSTRAINT

Alternating: user directs → you implement. Keep increments small — check in after each logical unit.
