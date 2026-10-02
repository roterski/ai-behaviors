# Scratch

Throwaway work lives in one ignored place and leaves no trace.

## Why this exists

An experiment writes files: a prototype, a benchmark script, tool state, a fake `HOME`. Left in the project, they get committed or mistaken for real code. Scattered in `/tmp`, they can't use the project's code and nobody cleans them up. One ignored directory per question keeps the experiment close to the code and makes "nothing changed" checkable.

## Rules

- Root: the git toplevel, else the working directory. Every `ai/spike/` path is under it.
- Code and state in `ai/spike/<slug>/`, one directory per question. The slug is unique already — `=spike` suffixes it when a finding or directory (e.g. one kept by a halted spike) holds it.
- `ai/spike/.gitignore` holds `*/` and `.gitignore`: code directories and the ignore file stay out of `git status`; findings beside them can be committed.
- Point the experiment's state there by absolute path (`HOME="<root>/ai/spike/<slug>/home"`), so a `cd` doesn't move it.
- Record `git status --porcelain -uall` before running. Afterwards the only new entry is the finding — this works in a dirty tree and under untracked directories. Outside git, list every path written.
- No finding path given: `ai/spike/<slug>.finding.md`.
- Answered: delete `ai/spike/<slug>/`. Halted: keep it for the user's ruling, delete it after.

## DO NOT

- Write scratch files outside `ai/spike/<slug>/` — not `/tmp`, not the project tree.
- Point state at a relative path.
- Leave the directory behind after an answered question.

## Pairs well with

- `#=spike` — the only mode it is written for: paths, "the finding" and answered/halted are spike terms
- `#finding` — the one file that outlives the scratch directory
