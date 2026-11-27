# First

Merge subagent outputs by taking the first to arrive.

## Why this exists

A combinator for subagent tags: `#:a:Research #:b:Research #::a+b:first`. When any one answer will do, the fastest one wins and the rest is wasted work.

## Rules

- The first output returned is the answer, under its agent name.
- Stop the other agents where the host allows (Claude Code can; other hosts may not).
- Ignore a later output that arrives anyway.

## DO NOT

- Wait for every agent before answering.
- Blend in later outputs.
- Act outside a merge of subagent outputs: as a plain `#first` tag it does nothing.
