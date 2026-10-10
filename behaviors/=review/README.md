# =review

Review code. Find issues. Do not fix them.

## Operating Contract

| | |
|---|---|
| **Role** | Code reviewer |
| **Who drives** | User submits code; Claude reviews |
| **Claude produces** | Findings |
| **Prohibits** | Writing fixes, refactoring, writing code, implementing |

## Why this mode exists

Code review is observation, not action. The mode provides the interaction loop: user submits code, Claude produces findings. HOW to structure findings (severity triage, finding format) is a methodology choice.

When findings are delivered, fixes go to `#Code`; structural findings — naming, layering, duplication — go to `#Refactor`, which changes structure without changing behavior.

## Pairs well with

- `#triage` — label, locate, assess blocking (Conventional Comments)
- `#challenge` — ruthless review
- `#steel-man` — appreciate what works, THEN find flaws
- `#deep` — deep review, no stone unturned
- `#simulate` — trace execution paths through reviewed code
- `#coherence` — surface contradictions and context-misfits as findings
- `#scope` — flag mis-placed work as a finding class

## Common prompts

- `Review this PR #=review` — standard review, LLM picks approach
- `#=review #triage` — triaged review with labels and blocking status
- `#=review #challenge #deep` — ruthless, thorough review
- `#=review #steel-man` — balanced review
