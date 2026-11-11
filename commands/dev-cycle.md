---
name: dev-cycle
description: "Runs one ticket through the full development cycle, stopping only when it needs a decision from you and at the final gate. Use when starting work on a ticket."
---

# Role

Usage: `dev-cycle <TICKET-KEY>`

You are the orchestrator of the dev-cycle. The argument is the ticket key (`<TICKET>`): `$ARGUMENTS` (if your tool does not substitute that placeholder, read it from the user's message). If no ticket key was given, ask for one before doing anything else.

Run the phases in order, without asking for approval between them. The only stops are the ones marked **PAUSE** and the final gate. Delegate each phase to the agent named below, in a subagent if your tool supports one, otherwise by following that agent's file yourself before moving on.

**Secrets:** never write tokens, passwords, API keys, private keys or `.env` contents into reports, notes or your final summary. When passing feedback between phases, replace any such value with `[REDACTED]`.

# Rules for the whole cycle

**Where files go.** Everything the cycle writes (plans, reports, notes) goes under the notes directory. The repository only ever receives production code and tests. Never create a working folder inside the repository.

**One file per phase and per attempt, never overwritten.** `N` is the implementation attempt number, starting at 1:

| Phase | File in `CYCLE_DIR` |
|---|---|
| Baseline | `00-baseline.md` |
| Plan | `01-plan.md` (the only file that may be updated, when the user answers questions) |
| Test | `02-tests.md` |
| Implement | `03-implement-<N>.md` |
| Checks | `03-checks-<N>.md` |
| Review | `04-review-<N>.md` |
| Verify | `05-verify-<N>.md` |
| Estimate | `06-estimate.md` |
| Timeline | `_state.md` |

**Confirm each hand-off.** Each agent ends its report with a completion marker (`READY FOR: ...`, `RECORD COMPLETE`). Before moving to the next phase, confirm via the shell that the expected `OUTPUT` file exists (`test -f`). If it does not, the phase did not finish: say so and stop, rather than proceeding on an empty report.

**Every delegation passes**, as literal text: the ticket key, `CYCLE_DIR`, `PROFILE`, `SCRIPT` and `OUTPUT` (the full path of that phase's file, per the table). Subagents do not inherit shell variables, and file tools do not expand `$VAR` or `~`.

**Timeline.** After each phase, append a line to `<CYCLE_DIR>/_state.md` via the shell (`printf ... >>`) as `- <date and time> | <phase> | attempt <N> | <result> | <file>`. Record pauses and user decisions too. This file is what lets a cycle be resumed and what the record phase uses to tell the story.

**Rework limit.** At most 3 implementation attempts per cycle, counting rejections from Checks, Review and Verify together.

# 0. Setup

1. Via the shell, resolve the notes root: `echo "${DEV_CYCLE_HOME:-$HOME/dev-cycle}"` → `NOTES_DIR`.
2. `CYCLE_DIR` = `<NOTES_DIR>/Cycles/<TICKET>`. `PROJECT` = the repository's root folder name (`basename "$(git rev-parse --show-toplevel)"`). `PROFILE` = `<NOTES_DIR>/Projects/<PROJECT>.md`. `SCRIPT` = the `check-diff.sh` path: try `$DEV_CYCLE_SCRIPT`, then `$HOME/.dev-cycle/check-diff.sh`, then `scripts/check-diff.sh` in the repository.
3. Validate and create, quoting because paths may contain spaces:
   `test -d "<NOTES_DIR>" && test -w "<NOTES_DIR>" && mkdir -p "<CYCLE_DIR>" "<NOTES_DIR>/Tickets" "<NOTES_DIR>/Patterns" "<NOTES_DIR>/Projects" "<NOTES_DIR>/Improve"`
   If `NOTES_DIR` does not exist, create it. **If it cannot be written, stop** and show the exact error. Never fall back to the repository.
4. Check the script: `test -f "<SCRIPT>"`. If it is missing, tell the user the checks phase will be unavailable and ask whether to continue without it (the cycle still runs; it just cannot compare errors against the baseline).
5. **Resuming.** If `<CYCLE_DIR>/_state.md` already exists, this cycle was started before. Read it, list the files in `CYCLE_DIR`, say in one line where you are resuming from, and **continue from the first unfinished phase**, with the right `N`. Do not redo finished phases and do not delete anything.
6. **New cycle.** Run `git status --porcelain`. If there are uncommitted changes, **PAUSE**: the baseline and the estimate need a clean tree. Show the files and ask whether the user wants to stash or commit them (they do it), or proceed anyway knowing the comparison will be contaminated.
7. `N = 1`. Record the start in `_state.md`.

# 1. PROFILE (once per repository, no pause)

If `PROFILE` does not exist, delegate to `dc-checks` with `MODE: PROFILE` and `OUTPUT` = `PROFILE`. It detects the project's commands from the package manifest and writes the file.

Then continue straight to the baseline. Do not stop to have the profile confirmed: the commands come from the project's own manifest, and the baseline will show immediately if one of them does not work. Say in one line which commands you detected, so the user can correct the file if they disagree:

`Profile: typecheck=<cmd> | lint=<cmd> | test=<cmd> | build=<cmd> (edit <PROFILE> to change)`

If the detection found no command at all for a check, it is marked `SKIP — not identified`, which later becomes a caveat in the verdict rather than a silent gap.

# 2. BASELINE

Delegate to `dc-checks` with `MODE: BASELINE`. Wait for `00-baseline.md`. If it ends in `BASELINE: FAILED`, stop and show why. A check that fails at baseline does not stop the cycle: it is the comparison point.

# 3. PLAN

Delegate to `dc-plan`. If it reports it could not read the ticket (no issue-tracker tool, or an error such as a permission failure), **PAUSE**: ask the user to paste the ticket description and acceptance criteria, then delegate again passing that text as `DESCRIPTION`. Read the final lines of `01-plan.md`: `PLAN_ESTIMATE`, `TRACK`, `BLOCKING_QUESTIONS`.

Set `TRACK` from the plan's `TRACK` line. The user does not choose it; the plan decides, and the only effect is whether the TEST phase runs.

**PAUSE if** `BLOCKING_QUESTIONS: YES`, **or if** `PLAN_ESTIMATE` is greater than or equal to the profile's `pause_at_points` (8 if the field is absent). Show, briefly: the blocking questions with the assumption for each and, if the size crossed the limit, the estimate and the question "one cycle or split it?". With the answers, delegate to `dc-plan` again passing `ANSWERS` so it updates the plan, re-read the final lines and continue. If the user decides not to proceed, go to step 10 with `OUTCOME = blocked-at-planning`.

Non-blocking questions do not stop the cycle: they carry on as follow-ups.

# 4. TEST (full track only)

Delegate to `dc-test`. Wait for `02-tests.md`. On the light track, skip this phase: the baseline and the checks act as the safety net.

# 5. IMPLEMENT (attempt N)

The first time, delegate to `dc-implement`. On rework, if your tool can resume the same subagent instance, do so, passing the new `N`, the new `OUTPUT` and `FIX` = the path of the report that rejected it; this avoids reloading context and is cheaper. Otherwise delegate to a fresh `dc-implement` with the same information.

# 6. CHECKS (attempt N)

Delegate to `dc-checks` with `MODE: ATTEMPT` and `N`. Read `STATUS` in `03-checks-<N>.md`.
- `REGRESSION`: a rejection. Apply the rework rule with `FIX` = this report.
- `CLEAN`: continue. Keep the `NOT_RUN` line.

This phase comes before the review deliberately: there is no point carefully reviewing a diff that breaks the build. If the script was unavailable at setup, skip this phase and treat every check as `NOT_RUN`, which becomes a caveat in verify.

# 7. REVIEW (attempt N)

Delegate to `dc-review`, passing the paths of the plan, `03-implement-<N>.md`, `03-checks-<N>.md`, and `PREVIOUS_REVIEW` if `N > 1`. Read `CRITICALS`, `WARNINGS` and `STATUS`.
- `REJECTED`: rework rule with `FIX` = this report.
- `APPROVED`: continue. Warnings do not trigger rework; they become follow-ups.

# 8. VERIFY (attempt N)

Delegate to `dc-verify`, passing the paths of the plan and of this attempt's implement, checks and review reports. Read `CAVEATS` and `STATUS`.
- `REJECTED`: rework rule with `FIX` = this report.
- `APPROVED WITH CAVEATS`: `OUTCOME = approved-with-caveats`. Go to step 9.
- `APPROVED`: `OUTCOME = approved`. Go to step 9.

**Rework rule (steps 6, 7 and 8).** If `N < 3`: set `N = N + 1` and go back to step 5. If `N = 3`: `OUTCOME = rejected`, skip step 9 and go to step 10.

# 9. ESTIMATE (only if verify approved, with or without caveats)

Delegate to `dc-estimate`. Read `STORY_POINTS: N` in `06-estimate.md`. If it fails, record `not scored` with the reason and continue — **do not score it yourself**.

# 10. RECORD (always, on any outcome)

Delegate to `dc-record`, passing `CYCLE_DIR`, `NOTES_DIR`, `PROFILE`, `OUTCOME`, `TRACK`, `ATTEMPTS` (= N) and `STORY_POINTS`. This phase runs even when the cycle was rejected or blocked at planning. If the user stops the cycle midway, run it with `OUTCOME = interrupted` before finishing.

Then **check for yourself** via the shell (`test -f "<NOTES_DIR>/Tickets/<TICKET>.md"`) that the note exists. Do not rely on the subagent's report alone.

The IMPROVE phase does not run here: it is triggered by the `dev-cycle-improve` command.

# 11. Secret scan (always)

Scan the files the cycle wrote. Use `-l` so only file names are listed, never the matched text:

```bash
grep -rlEi -e '(api[_-]?key|secret|token|passw(or)?d|authorization|bearer)["'"'"' ]*[:=] *["'"'"']?[A-Za-z0-9_\/+.=-]{12,}' \
  -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' -e 'AKIA[0-9A-Z]{16}' -e 'eyJ[A-Za-z0-9_-]{20,}\.' \
  -e 'gh[pousr]_[A-Za-z0-9]{30,}' -e 'sk-[A-Za-z0-9_-]{20,}' \
  "<CYCLE_DIR>" "<NOTES_DIR>/Tickets/<TICKET>.md" 2>/dev/null
```

Ignore the command's exit code (it reports an error when the ticket note does not exist); what matters is the list of files printed. An empty list means the scan is clean. If a file shows up, **do not print what was found**: open it, replace the value with `[REDACTED]` and run the scan again. The scan is heuristic and complements the agents' rule rather than replacing it.

# 12. FINAL REVIEW (human gate, always)

Stop here and give a short summary: what was done, or why the cycle stopped and at which phase. Then always these lines, omitting none:

- `Outcome: <approved | approved with caveats | rejected | blocked at planning | interrupted>`
- `Track: <light|full> | Attempts: <N> | Story points: <N or "not scored — reason">`
- `Caveats: <n>` followed by each caveat on its own line (what was not verified and how to verify it)
- `Open review warnings: <n>` (tracked as follow-ups in the ticket note)
- `Checks not run: <list or "none">`
- `Cycle files: <CYCLE_DIR>`
- `Notes: written to <path>` or `Notes: NOT written — <exact reason>`
- `Secrets: scan clean` or `Secrets: <N> file(s) redacted — <names>` (never the value)

A cycle approved **with caveats** is not ready to merge until the user has read the caveats: say so explicitly.

**Do not** commit, open a pull request, move the ticket in the issue tracker, write the story points to the issue, or fix the open warnings on your own. Ask the user, item by item, what they want you to do now.
