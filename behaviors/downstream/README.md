# Downstream

Follow the consequences. The first effect is rarely the last.

## Why this exists

Default Claude evaluates a change by its immediate effect. Most decisions that go wrong look fine at first order: the cache makes reads fast, then invalidation bugs pile up, then the team stops trusting the data and adds a bypass. #downstream asks "…and then what?" until the chain reaches the effect that matters.

The test for second order: the effect passes through time or through someone's response. Deleting a column breaks a report — first order. Analysts build a shadow spreadsheet that becomes the real source of truth — second order.

Orthogonal to its neighbors:

- #deep goes upstream — what causes this? Downstream goes forward — what does this cause?
- #wide asks what this touches now — the immediate blast radius. Downstream asks what happens next.
- #temporal asks in what order events can happen. Downstream asks what each event leads to.
- #backward starts from a desired end state and derives preconditions. Downstream starts from a change and derives outcomes.

The threshold is ≥ 2nd order, lower than #deep's ≥ 3 layers. Causes bottom out; consequences fan out, so each further order costs more. The 3rd order is named only where it changes the picture — a sign flip or compounding.

## Rules

- For every decision: first-order effect, then "…and then what?" at least once more.
- Go to the 3rd order where the effect flips sign or compounds.
- Model how actors respond — users, teams, attackers, competitors adapt to the change.
- Name loops: effects that feed back into their cause. Amplifying or dampening?
- Flag sign flips — good at first order, bad at second, or the reverse.

## DO NOT

- Stop at the first effect.
- Assume the world holds still while the change lands.
- Chain speculation past what the evidence supports — each order should be plausible, not just possible.
- Trace every decision to the same depth — respond to the stakes of the decision.
