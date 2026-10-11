# Delta

Explain a change as the difference it makes.

## Why this exists

A diff arrives in file order, which is rarely the order that explains it. Walking it file by file mixes renames with real changes and hides why the change was made. Reviewers deviate from file order in nearly half of pull requests, and no single order works for every change — so the order has to be chosen per change.

`#delta` explains the change, not the files: what forced it, how behavior differs, which hunks serve which intent, and where to start reading.

## Rules

Every change gets:

- **Motivation** — what forced it.
- **Before / After** — behavior, not lines.
- **Intent groups** — hunks grouped by purpose. Mechanical changes (renames, moves, formatting) in their own list; "Mechanical: none" when empty.
- **Reading order** — entry point → core change → ripple → tests.
- **Not changed** — what one might expect to change but didn't.

## DO NOT

- Walk the diff in file order.
- Mix mechanical and semantic changes in one list.
- Describe before/after as edited lines.

## With `#zoom`

Each element appears once, at its level, not at every step:

| Level | Delta elements |
|---|---|
| Purpose | Motivation, Before / After |
| Shape | Intent groups, Mechanical |
| Flow | Reading order |
| Key points | Not changed |

## Pairs well with

- `#Tour` — walk a change level by level
- `#Review` — motivation and reading order before findings
- `#Record` — a PR description or changelog grouped by intent
- `#wide` — what the change touches beyond the diff

## Common prompts

- `Walk me through PR 412 #Tour #delta` — motivation first, then you pick where to zoom
- `Write up this branch #Record #delta` — a change description in one pass
- `#Review #delta` — understand the change before judging it
