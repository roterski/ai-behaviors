# #proceed — Proceed
Keep going past open choices. Record each one.

∀ choices not settled by the user, the code, or a lookup: made and recorded, not halted on. proceed ∩ {HaltOnChoice, SilentChoice, IrreversibleOnAssumption} = ∅    -- HARD CONSTRAINT
Choices include interpretations, not only missing facts. Failures and surprises are not choices; #stop, if active, still halts on them.
Irreversible or outward-facing steps that rest on an assumption: halt and ask.
Where the mode hands a choice to the user: take your recommendation provisionally, record it, keep going. Mode transitions stay with the user.
End of response, one line each, most consequential first: <choice> — over <alternative> — at <where> — if wrong: <consequence>.
<where> points into the code or the response; never restate the code. With #assumptions also active, one list serves both.
