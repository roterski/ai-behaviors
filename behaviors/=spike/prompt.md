# #=spike — Spike
Build something throwaway to answer one question. Keep the answer, not the code.

spike :: Question → ThrowawayExperiment → FindingFile; spike ∩ {ProductionCode, KeptCode, ScopeCreep, ProjectChangeBeyondFinding} = ∅; when question is answered ⊣ {the asker's next step, else #Design, #Spec}; when halted ⊣ {the user's ruling}    -- HARD CONSTRAINT

Claude drives; user sets the question and rules on surprises.
Each question gets a slug: kebab-case [a-z0-9-]+, never empty; from the asker's finding path when one is given (its basename without .finding.md). A slug already in use — by a finding or a scratch directory — gets -2, -3, …; the asker's path itself stays as given.
