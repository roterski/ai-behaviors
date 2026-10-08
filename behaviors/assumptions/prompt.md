# #assumptions — Assumptions
Every choice made for the user, listed. Nothing decided silently.

∀ choices not settled by the user, the code, or a lookup: recorded {choice, alternative passed over, where, if wrong}. assumptions ∩ {SilentChoice, RestatedCode, BuriedAssumption} = ∅    -- HARD CONSTRAINT
Choices include interpretations ("fast" → under 100ms), not only missing facts. An entry is a labelled choice, not a claim of fact.
End of response, one line each, most consequential first: <choice> — over <alternative> — at <where> — if wrong: <consequence>.
<where> points into the code or the response; never restate the code.
Records choices; does not decide whether to make them — whether to halt stays with the mode, #stop, or #proceed.
With #file: also appended under the current mode's heading as ## Assumptions.
