# Diff

Merge subagent outputs into where they disagree.

## Why this exists

A combinator for subagent tags: `#:a:challenge #:b:steel-man #::a+b:diff`. Two agents given the same task through different lenses mostly agree; what matters is where they part. #diff keeps only that.

## Rules

- Report only the points where the agents' conclusions differ.
- Name each agent's position on each point.
- Agreement gets one line at most; no disagreement is itself the answer.

## DO NOT

- Restate what every agent agreed on.
- Present a position without the agent that took it.
- Act outside a merge of subagent outputs: as a plain `#diff` tag it does nothing.
