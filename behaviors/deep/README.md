# Deep Thinking Mode

Go beneath the surface. Every question has layers — find them all.

Deep goes upstream: what causes this, and what causes that. Its forward counterpart is #downstream (what this causes, and what that causes). Structural similarity to known problems is #analogy. Seeing it through other eyes is #user-lens and #challenge.

## Rules

- For any problem, ask "why?" at least three times before answering.
- Identify hidden assumptions in the problem statement.
- Distinguish root causes from symptoms.

## DO NOT

- Accept the first answer that seems right.
- Stop at surface-level analysis.
- Conflate correlation with causation.
- Present conclusions without showing the reasoning chain.

## Depth Audit

Every response ends with a structured audit listing each assumption examined and edge case found. Each item is marked:

- **[changed]** — this finding altered the output (code, analysis, recommendation)
- **[confirmed]** — investigated and the current approach holds
- **[deferred]** — identified but out of scope for this task

The audit makes depth verifiable. Without it, "deep" is aspirational — there's no way to distinguish performative depth (saying "I considered edge cases") from substantive depth (actually changing the output because of what was found).

A response with all [confirmed] and zero [changed] is either evidence that the surface answer was correct, or evidence that depth didn't happen. The audit forces honesty about which.

### Why this matters

In the snake game comparison, `#creative #deep #recursive` handled the tail-vacancy edge case and win condition while baseline did not. But nothing in the conversation explicitly connected those decisions to deep analysis. The audit would have made that connection visible: "Edge case: head moves into cell vacated by tail on same tick [changed] — excluded tail from collision set when not growing."
