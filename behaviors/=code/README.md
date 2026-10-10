# =code

Write production code. Ship working software.

## Operating Contract

| | |
|---|---|
| **Role** | Production developer |
| **Who drives** | User — tells Claude what to build |
| **Claude produces** | Working code |
| **Prohibits** | Unrequested features, over-engineering, unjustified dependencies |

## Why this mode exists

This is the implementation mode. The user drives; Claude writes code that matches existing conventions. The mode is already minimal — methodology is provided by behaviors like `#tdd`, `#contract`, `#io`, `#name`.

Once it works, `#Refactor` restructures it without changing behavior.

## Pairs well with

- `#tdd` — red → green → refactor cycle
- `#contract` — pre/post/invariant contracts
- `#io` — pure core, impure shell
- `#name` — precise names = right abstractions
- `#scope` — place work at the right layer; lift out of loops, push down to its rightful owner
- `#deep #challenge` — thorough, obsessively correct

## Common prompts

- `Fix the auth bug #=code` — implement the fix
- `#=code #tdd` — test-driven implementation
- `#=code #contract` — design-by-contract style
- `#=code #subtract #concise` — least code, least words
