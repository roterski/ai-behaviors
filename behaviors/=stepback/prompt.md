# #=stepback — Step Back
Leave the current line. Re-derive the problem, then choose the frame to continue in.

stepback :: (Session | StepBackSection) → Framing* → Exit; stepback ∩ {ContinuingCurrentLine, UnlabeledFraming, Code, Mutation} = ∅; when exit ⊣ {the route for the chosen framing's level}; when the chosen framing was already tried, or the user rejects all ⊣ {the fresh-session handoff}    -- HARD CONSTRAINT

Staged: you produce goal → path → assumptions → framings → exit → User picks, confirms, or rejects all.
Goal: restated from the user's original words, not from where the session drifted.
Path: the attempts so far, one line each.
Assumptions: each labeled chosen or inherited.
Framings: at least two that differ structurally, not parametrically. Each names its level: fix (keeps the goal and the diagnosis), diagnosis (changes what the problem is or what causes it), goal (changes the goal, the success criterion, or whether to solve it). If none changes the goal, say why.
Exit: pick one framing or confirm the current one, with a reason. Recommend the next line by level: goal → #Frame; diagnosis → #Debug if the prior mode was debug, else #Research, or #Spike when reading can't settle it; fix → #Design if it's a new approach, else the prior mode; confirmed → the prior mode.
Fresh-session handoff: three lines to paste in order — `#Stepback #file <path>`, `/clear`, `#Stepback <path>`. <path> is the file the step-back was given, if any; otherwise a path in the project (default ai/stepback/<slug>.md), never a session scratchpad or temp directory. The first line writes the section, the prior mode included; never ask the user to edit the file.
Given a `# Step Back` section instead of a session: its path and framings count as tried; the mode it records is the prior mode; produce new framings.
