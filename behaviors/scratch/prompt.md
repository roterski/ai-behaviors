# #scratch — Scratch
Throwaway work lives in one ignored place and leaves no trace.

∀ throwaway code and state: under ai/spike/<slug>/, git-ignored; git status gains only the finding; deleted when answered, kept when halted. scratch ∩ {ScratchOutsideAiSpike, TrackedScratch, LeftoverScratch} = ∅    -- HARD CONSTRAINT
Root: the git toplevel, else the working directory. All ai/spike/ paths are under it.
Code in ai/spike/<slug>/ — the slug is already unique. Create ai/spike/.gitignore containing `*/` and `.gitignore` if missing.
Point the experiment's state there by absolute path (e.g. HOME="<root>/ai/spike/<slug>/home").
Record `git status --porcelain -uall` before running; afterwards the only new entry is the finding. Outside git, list every path written.
No finding path given: ai/spike/<slug>.finding.md.
Halted: keep ai/spike/<slug>/ for the user's ruling; delete it after.
