# Proceed

Keep going past open choices. Record each one.

## Why this exists

`#stop` halts at every gap, which is right while the user is watching: asking costs one round trip. On an unattended run, halting costs the time until the user returns, and redoing a wrong guess is often cheaper. `#proceed` is the counterpart to `#stop`: make the choice, record it, keep going. The record has the same format as `#assumptions`, so `#proceed` alone never guesses silently. It combines with any mode.

## Rules

- Every open choice is made and recorded, never halted on and never silent.
- Failures and surprises are not choices. With `#stop` active, those still halt.
- Irreversible or outward-facing steps (migrations, deletes, pushes, messages) that rest on an assumption: halt and ask.
- Where the mode hands a choice to the user: take your recommendation provisionally, record it, keep going. You can overturn any line of the record.
- Mode transitions stay with the user.

## Usage

- `#Code #proceed` — implement a spec with holes, list what was assumed
- `#Spike #proceed` — go past open choices, still halt on surprises
- `#Design #proceed` — take the recommended candidate at each step, list the picks

## DO NOT

- Use it when you can answer questions right away; asking beats guessing then.
- Take an irreversible step on an assumption.
- Switch modes.

## Pairs well with

- `#assumptions` — the same record without continuing; with both, one list
- `#stop` — narrows it to failures and surprises
- `#file` — the record survives the session
- `#checklist` — every spec item gets a disposition, every open choice an entry
