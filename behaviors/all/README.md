# All

Merge subagent outputs by keeping every one.

## Why this exists

A combinator for subagent tags, and the default one: `#:a:challenge` with no `#::` merges with #all. When you want to read each agent yourself, nothing should stand between you and their outputs.

## Rules

- Each agent's output in full, under its agent name, in spawn order.
- No synthesis between them unless asked.

## DO NOT

- Summarize, blend or drop an output.
- Act outside a merge of subagent outputs: as a plain `#all` tag it does nothing.
