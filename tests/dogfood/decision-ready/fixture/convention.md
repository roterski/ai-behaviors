# Claims convention

A claim is a statement about the system that a person stands behind.
This file says how claims are recorded, held, rated, verified and withdrawn.

## Vocabulary

| Term | Meaning |
|---|---|
| claim | a named statement, such as `:claim/decisions-persisted` |
| kind | what a claim is about: `decision` or `usage` |
| store | an EDN file that holds every claim of one kind |
| holder | the person who stands behind a claim |
| withdrawn | a claim its holder no longer stands behind; it stays in its store, marked `:withdrawn true` |

## Rules

- **R-record**: record each claim in the store for its kind, `stores/decision.edn` or `stores/usage.edn`, under its name.
- **R-hold**: a claim is held while its holder's name is in its `:held-by`. An LLM may assert that a claim is held.
- **R-holder**: only a person can be a holder.
- **R-rating**: when a person rates a claim from 1 to 5, record the rating with the rater's name.
- **R-withdraw**: a holder may retire their claim at any time; a retired claim is never deleted.
- **R-verify**: a claim is verified when a test names it in its `:claims` metadata, using the name R-recrod stores it under.
