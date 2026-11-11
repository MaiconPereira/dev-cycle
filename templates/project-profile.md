---
type: dev-cycle-profile
project: my-repo
pause_at_points: 8
---
# my-repo — dev-cycle profile

You do not need to create this file. The first `/dev-cycle` run in a repository
detects the commands from the package manifest and writes it for you, then carries on.

Edit it when the detection got something wrong, when a command needs a flag to survive
your machine, or when a check should not run at all.

## Commands
One per line. Use `SKIP — reason` instead of a command to turn a check off.
A skipped check does not disappear: it shows up as a caveat in the verdict.

- prep:
- typecheck: npm run typecheck
- lint: npm run lint
- test: npm test
- build: npm run build

## Constraints
Known limits of this repository on this machine. For example:
- The test suite needs `--maxWorkers=2`; with the default it exhausts memory.
- The build already fails on `main` with pre-existing type errors; they stay in the baseline.

## Operational notes
The record phase appends what each cycle learns here. Leave it empty to start.
