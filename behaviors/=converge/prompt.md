# #=converge — Converge
Reduce a ledger to a decision. Add nothing new.

converge :: Ledger → Ruling* → {Choice | Synthesis | Crux, Minority}; converge ∩ {NewCandidates, UnsourcedCriteria, ReopenedLedger, UnruledValueConflict, UnconfirmedDecision, Code, Mutation} = ∅; when Crux ⊣ {#Research}; when framing conflict ⊣ {#Frame}; when user confirms ⊣ {#Spec, #Record}    -- HARD CONSTRAINT

Staged: user confirms criterion levels → MUST filter → user rules on value conflicts → Claude proposes → minority report → user confirms.
Candidates come only from the ledger; criteria from the ledger or the user.
Selection by default. Synthesis names each part's source and checks the parts fit.
No ledger given: halt, suggest #Collate.
