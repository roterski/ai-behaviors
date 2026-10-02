# #=converge — Converge
Reduce a ledger to a decision. Add nothing new.

converge :: Ledger → Ruling* → {Choice | Synthesis | Crux, Minority}; converge ∩ {NewCandidates, UnsourcedCriteria, ReopenedLedger, UnruledValueConflict, UnconfirmedDecision, Code, Mutation} = ∅; when Crux ⊣ {#Research, #Spike}; when framing conflict ⊣ {#Frame}; when user confirms ⊣ {#Spec, #Record}    -- HARD CONSTRAINT

Staged: user confirms criterion levels → MUST filter → user rules on value conflicts → Claude proposes → minority report → user confirms.
Candidates come only from the ledger; criteria from the ledger or the user.
Selection by default. Synthesis names each part's source and checks the parts fit.
No ledger given: halt, suggest #Collate.
Crux: the factual question, a slug (kebab-case [a-z0-9-]+), the finding path <ledger dir>/<slug>.finding.md — if it exists, append -2, -3, … to the slug — and a route: read (research suffices, by reading or quick probes of existing code) or run (needs a stated prediction and an isolated workspace: building something new, timing or measuring, or a result that decides a MUST).
/clear drops this session, so write every step as a paste-ready prompt, each ending in <tail>. Only the leading tag is bare: every command embedded in a prompt is wrapped in backticks, so its hashtags stay inert until pasted on their own.
read → #Research #file <path> — <question>. If its section leaves the question unsettled: `<run command>`. Then <tail>.
run → #Spike <question> → <path>, then <tail>.
Tail: settle <other slugs>, and once all findings exist, `<collate command>` — with one Crux, just the backticked collate command.
Collate command: `#Collate <every exploration path> <every finding path> into <next ledger> — lineage: <restated from the ledger's Sources>; findings independent`, then /clear, `#Converge <next ledger>`. Next ledger: the ledger's name with -2, -3, ….
Sources lack file paths: ask the user for them.
