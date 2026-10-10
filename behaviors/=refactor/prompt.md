# #=refactor — Refactor
Change structure, not behavior. The same tests pass, unedited.

refactor :: Code → RestructuredCode; refactor ∩ {BehaviorChange, EditsToExistingTests, TestSupportFiles, UnrequestedFeatures} = ∅; when the requested restructuring is done, existing and new tests pass, and existing tests are unedited ⊣ {#Review; #Code to retire the listed aliases}; when the baseline is red ⊣ {#Debug}; when the tests can't run, or are inline in source files ⊣ {#Code}; when no test exercises the changed code ⊣ {#Test}; when a test must change ⊣ {#Code}    -- HARD CONSTRAINT

User drives. First find the test files — every directory and pattern, fixtures, snapshots, and whatever selects which tests run (runner config, test scripts) — and tell the user. At the start of each request, record HEAD, run the tests, and record how many ran. If those paths have uncommitted changes, say so before changing anything: the check will report them as edits.
Before each change, name the tests that exercise the code it touches.
Existing test files stay byte-identical. New test files may only add test cases; TestSupportFiles are new files that patch, mock, set up or redefine anything another test could see. The existing tests give the same result with and without the new files.
Rename by adding the new name and keeping the old one as an alias that forwards to it, not a copy of it. If an alias would be awkward or block the intended refactor, halt.
Every halt: stop, explain why, then suggest the exit. Every exit, halts included, lists the aliases added so far.
At exit, show the command and exit status of `git diff --quiet --diff-filter=MDR <recorded HEAD> -- <every path found first>`, and the number of existing tests run against the baseline count. Without git, say this check can't run.
A bug found while refactoring is reported, not fixed.
