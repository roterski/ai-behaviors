# =refactor

Change structure, not behavior. The same tests pass, unedited.

## Operating Contract

| | |
|---|---|
| **Role** | Refactorer |
| **Who drives** | User — names the restructuring; Claude carries it out |
| **Claude produces** | Restructured code, the names of the tests that cover each change, the aliases left to retire, and the unedited-tests check at exit |
| **Prohibits** | Behavior change, edits to existing tests (files, helpers, fixtures, runner config), test support files (new files that patch, mock, set up or redefine), unrequested features |

## Why this mode exists

`#=code` gets something working. Once it works, refactoring improves its structure, and nothing in `#=code` stops it from also changing behavior. `#tdd` keeps tests green, but lets the tests themselves be edited until they are.

This mode makes the tests the fixed point: the same tests pass, byte-identical. Editing a test to make it pass is the most common way coding agents cheat — over 79% of Claude Opus 4.1's cheating in [ImpossibleBench](https://arxiv.org/abs/2510.20270) was test modification, and read-only tests curbed it. The same study found "stop and explain" works better than a bare "don't", so every halt here is worded that way.

Renames would normally force test edits. Instead, the mode renames by Parallel Change: add the new name, keep the old one as an alias, and list the aliases at exit. Tests keep using the old name until a later `#Code` step retires the aliases.

## Workflow

1. `#Refactor <what to restructure>`.
2. Once per session, Claude finds the test files — every directory and pattern, fixtures, snapshots, and whatever selects which tests run — and tells you.
3. At the start of each request, Claude records HEAD, runs the tests and records how many ran. If those paths have uncommitted changes, Claude warns: the check will report them as edits. Red: stop, `#Debug`. Can't run, or inline in source files: stop, `#Code`.
4. Before each change, Claude names the tests that exercise the code it touches. None: stop, `#Test`.
5. Claude restructures. A bug it notices is reported, not fixed.
6. Done: existing and new tests pass, and existing test files are unchanged since the recorded HEAD. Claude shows the git check below and the number of existing tests run against the baseline count. Every exit, halts included, lists the aliases added so far.

To verify yourself, with `<test paths>` every path from step 2 and `<base>` the HEAD recorded at step 3 (start from a clean test tree; Claude warns when it isn't):

```
git diff --quiet --diff-filter=MDR <base> -- <test paths>
```

It catches modified, deleted and renamed test files, whether unstaged, staged or committed, and ignores new ones. Run it after the tests — snapshot tools write files while running. New test files are listed by `git diff --name-only --diff-filter=A <base>` plus `git ls-files --others --exclude-standard`; read them. Test selection that lives outside files — CLI flags, environment variables — shows up only in the test count. Without git there is no check; Claude says so.

## Exits

| Outcome | Suggests | Why |
|---|---|---|
| Restructuring done; existing and new tests pass, existing unedited | `#Review`; `#Code` to retire the listed aliases | Check the result; then update tests to the new names and drop the aliases |
| Baseline red | `#Debug` | A refactor can't be checked against failing tests |
| Tests can't run, or are inline in source files | `#Code` | Fix the setup first; inline tests can't be held byte-identical apart from the code |
| No test exercises the changed code | `#Test` | Without coverage, "unchanged behavior" is unchecked |
| A test must change (an alias would be awkward, or blocks the intended refactor) | `#Code` | Test edits belong to a mode that allows them; Claude stops and explains why first |

## Conventions

- "Unedited" covers existing test files, test helpers, fixtures, and whatever selects which tests run (runner config such as `bb.edn` or `pytest.ini`, test scripts): byte-identical. Excluding a failing test from the runner is a test edit.
- New test files may add test cases, for example against a new name. Test support files — new files that patch, mock, set up or redefine anything another test sees — are forbidden: one that patches the code back can hide a behavior change from tests that stay byte-identical. The existing tests give the same result with and without the new files.
- An alias forwards to the new name, not a copy of it — in Clojure `(def old #'new)` or a wrapper function, not `(def old new)` — so redefining or mocking the new name still reaches callers of the old one. Mocking the old name no longer reaches callers moved to the new name; a test that mocks it is why to leave those callers on the old name.
- Fixtures hold inputs and expected outputs; editing one changes what is asserted.
- Refactoring test code itself is out of scope — use `#Code`.

## Minority view

Real refactors, such as renames, may need test edits; "tests stay green" (a looser exit rule) allows them. Aliases cover most renames without that. Revisit the rule if users keep overriding the halt, alias-fallback halts dominate, or aliases go unretired.

## Pairs well with

- `#name` — the renames are what aliases are for
- `#scope` — move work to the layer it belongs in
- `#subtract` — refactor toward less code
- `#steel-man` — say what the current design does well before changing it

## Common prompts

- `Extract the parsing out of handler.clj #Refactor` — restructure with the default methodology
- `#=refactor #subtract` — refactor toward less code
- `#Refactor` after `#Review` — act on structural findings
