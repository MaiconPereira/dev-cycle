# dev-cycle

A starter kit for **agentic development**: one command takes a ticket from plan to final review, with a specialised agent for each phase and a written record of every decision.

Works with **Claude Code**, **Kiro** and **Codex**. No build step, no installer — copy a folder, set one environment variable.

🇧🇷 [Read in Portuguese](README.pt-BR.md)

---

## Why

Letting an agent write code is easy. Trusting what comes out is not. This kit splits the work into phases with a clear hand-off, so each step produces something you can check:

- The plan states **verifiable** acceptance criteria before any code exists.
- The tests are written **before** the implementation, not to match it afterwards.
- A deterministic script compares errors against a **baseline**, so "it was already broken" is a fact, not an opinion.
- The verdict has **three** states, so "I could not verify this" stops being silently filed as success.
- Every cycle leaves a note, including the ones that failed.

The agent does the mechanical work. You stay the reviewer.

## The cycle

```
Baseline → Plan → Test → Implement → Checks → Review → Verify → Estimate → Record → Final review
                            ▲           │        │        │
                            └──── rejected (up to 3 attempts) ────┘
```

| Phase | What happens | Agent |
|---|---|---|
| **Baseline** | Runs type-check, lint, tests and build **before** any change, and records the errors that already existed. | `dc-checks` |
| **Plan** | Reads the ticket, writes requirements and verifiable acceptance criteria, decides the approach, breaks the work into tasks, flags blocking questions and sizes it. | `dc-plan` |
| **Test** | Writes the tests first and confirms they fail for the right reason. Skipped on trivial tickets. | `dc-test` |
| **Implement** | Writes the production code. No commits. | `dc-implement` |
| **Checks** | Re-runs the same checks and compares **error by error** against the baseline. An error that already existed does not count; a new one rejects the attempt. | `dc-checks` |
| **Review** | Static review of the diff against the plan and the repository's rules, on a fixed severity scale. Only a **Critical** rejects. | `dc-review` |
| **Verify** | Checks every acceptance criterion and every task, with evidence. | `dc-verify` |
| **Estimate** | Scores what was actually delivered, for an effort-versus-delivery metric. | `dc-estimate` |
| **Record** | Writes the ticket note, follow-ups and patterns. Runs on **any** outcome. | `dc-record` |
| **Improve** | On demand, across many cycles: recurring patterns and proposed process changes. | `dc-improve` |

### Outcomes

| Outcome | Meaning |
|---|---|
| **Approved** | Every criterion verified with evidence, every check clean, every task done. |
| **Approved with caveats** | Nothing failed, but something was **not confirmed** — a criterion needing a manual test, a check skipped by the profile, a task not done. Read the caveats before merging. |
| **Rejected** | Three attempts and still a new error, a Critical finding or an unmet criterion. |
| **Blocked at planning** | You chose not to proceed after the open questions or the size estimate. |
| **Interrupted** | The cycle was stopped midway. Run it again to resume. |

### When it stops for you

The cycle runs on its own and only stops here:

| Pause | Why |
|---|---|
| Dirty git tree | The comparison needs a clean starting point. |
| Ticket unreachable | No issue-tracker integration, or the call failed. Paste the description. |
| Blocking question | Different answers would change the scope or the approach. |
| Large task | The estimate reached the profile's limit (default: 8 points). |
| Final review | Always. |

Small questions do not stop the cycle: it adopts an assumption, records it, and leaves it as a follow-up for you to confirm.

---

## Install

### 1. Copy the files

**Claude Code**
```bash
mkdir -p ~/.claude/agents ~/.claude/commands ~/.dev-cycle
cp agents/*.md ~/.claude/agents/
cp commands/*.md ~/.claude/commands/
cp scripts/check-diff.sh ~/.dev-cycle/ && chmod +x ~/.dev-cycle/check-diff.sh
```

**Kiro**
```bash
mkdir -p ~/.kiro/agents ~/.dev-cycle
cp agents/*.md commands/*.md ~/.kiro/agents/
cp scripts/check-diff.sh ~/.dev-cycle/ && chmod +x ~/.dev-cycle/check-diff.sh
```

**Codex** — skills live one folder deep, so each file becomes its own directory:
```bash
mkdir -p ~/.agents/skills ~/.dev-cycle
for f in agents/*.md commands/*.md; do
  n=$(basename "$f" .md)
  mkdir -p ~/.agents/skills/"$n" && cp "$f" ~/.agents/skills/"$n"/SKILL.md
done
cp scripts/check-diff.sh ~/.dev-cycle/ && chmod +x ~/.dev-cycle/check-diff.sh
```

### 2. Set where the notes go

Add to your `~/.zshrc` or `~/.bashrc`:
```bash
export DEV_CYCLE_HOME="$HOME/dev-cycle"
```

Any directory works. If you use Obsidian, point it at a folder inside your vault and the notes become a browsable knowledge base (see [Notes](#notes)). Leave it unset and the cycle uses `~/dev-cycle`.

### 3. Restart your agent

Open a new terminal (so the variable is loaded) and restart the tool. In Claude Code and Kiro, type `/` and check that `dev-cycle` is listed. In Codex, type `$` and look for `dev-cycle`.

> **Claude Code only:** if `DEV_CYCLE_HOME` points outside your project, add it to `permissions.additionalDirectories` in `~/.claude/settings.json`, otherwise the cycle cannot write there.

---

## Use

```bash
/dev-cycle PROJ-123     # run a ticket
/dev-cycle PROJ-123     # run it again to resume a cycle that stopped midway
/dev-cycle-improve      # periodic: analyse the accumulated cycles
```

If there is no issue-tracker integration, or the ticket cannot be read, the cycle asks you to paste the description and acceptance criteria and carries on from there.

In Codex, invoke them as `$dev-cycle PROJ-123`.

Start with a clean git tree. The cycle compares the repository's state before and after; your own uncommitted changes contaminate that comparison.

### First run in a repository

Nothing to set up. On the first run in a repository, the cycle reads your package manifest, works out the commands for type-check, lint, test and build, writes them to `$DEV_CYCLE_HOME/Projects/<repo-name>.md`, and carries on. It tells you what it found in one line:

```
Profile: typecheck=npx tsc --noEmit | lint=npm run lint | test=npx jest --ci | build=npm run build
```

Edit that file when the detection got something wrong, when a command needs a flag to survive your machine, or when a check should not run at all:

- `prep:` runs before every check — loading a runtime version, for example. It can be empty.
- `SKIP — reason` turns a check off. It does not disappear: it becomes a caveat in the verdict, so a missing check is never silent.

There is a commented starting point in [`templates/project-profile.md`](templates/project-profile.md).

### The final review

```
Outcome: approved with caveats
Track: full | Attempts: 2 | Story points: 3
Caveats: 1
  CV1: the disabled checkbox in edit mode needs a manual test (open an existing record)
Open review warnings: 2
Checks not run: build
Cycle files: ~/dev-cycle/Cycles/PROJ-123
Notes: written to ~/dev-cycle/Tickets/PROJ-123.md
Secrets: scan clean
```

From there it is your call. The cycle **asks** before each of these and does none of them on its own: committing, opening a pull request, moving the ticket, writing the score to the issue, or fixing the open warnings.

### Light and full tracks

There is nothing to choose here — the plan decides, and the only difference is whether the Test phase runs. When the plan sizes a ticket at 1 point and it creates no business rule (configuration, copy, a dependency removal), it marks the cycle **light** and the tests are skipped, since the baseline comparison already catches a regression on that kind of change. Everything else runs the **full** track. Baseline, Checks, Review, Verify, Estimate and Record happen either way. The track appears in the final summary so you can see which one ran.

---

## Notes

```
$DEV_CYCLE_HOME/
  _Dashboard.md           overview
  Projects/<repo>.md      profile: commands, constraints, operational notes
  Tickets/<TICKET>.md     one note per ticket: outcome, decisions, attempts, follow-ups
  Patterns/<name>.md      one note per recurring problem
  Cycles/<TICKET>/        each phase's report and the cycle timeline
  Improve/                reports from dev-cycle-improve
```

Nothing goes into the project repository — only code and tests land there.

**Follow-ups** are the part worth watching. Every review warning, task not done, manual test and unconfirmed assumption becomes a `- [ ]` item in the ticket note.

The notes are plain Markdown and readable in any editor. In **Obsidian**, the generated `_Dashboard.md` uses the [Dataview](https://github.com/blacksmithgu/obsidian-dataview) plugin to list recent tickets, open follow-ups across all tickets, and the most frequent patterns. Pattern notes are linked with wikilinks, so Obsidian's backlinks show how often each problem has come up — no tooling needed.

---

## How the baseline comparison works

This is the one piece that is **not** a language model. [`scripts/check-diff.sh`](scripts/check-diff.sh) runs each command, reduces its output to error signatures (file plus error code, without line numbers), and compares the sets:

```
== typecheck: rc 1 -> 1 | new errors: 1 | resolved: 0
+1  src/c.html - error NG8002: Can't bind to 'label'
RESULT: REGRESSION
```

An error that already existed and merely moved lines does not count. A new one rejects the attempt, even when the total was already high. Raw logs stay in `/tmp/dev-cycle/` and never enter the model's context.

It understands the output of **tsc**, **Angular**, **ESLint** and **Jest**. For other tools it still compares exit codes, but it may not spot a new error inside a check that was already failing. Adding a format means one `awk` rule — contributions welcome.

---

## Adapting it

Every agent is a Markdown file with a short frontmatter and a prompt. To change how a phase behaves, edit its file and restart your tool.

The frontmatter carries `name` and `description` (required everywhere), plus `tools` and `model`, which Claude Code and Kiro honour and Codex ignores. The `tools` list is a guardrail, not an optimisation: `dc-review` has no editing tool, so it can only report problems, and `dc-plan` cannot edit code at all. Keep descriptions to one line — they are loaded into every session, so long ones cost context on work that has nothing to do with this cycle.

- **Your own severity scale:** edit `agents/dc-review.md`.
- **Your team's estimation rubric:** install it as a skill and `agents/dc-estimate.md` will defer to it; otherwise it uses the Fibonacci scale defined in the file.
- **Your coding rules:** put them in the repository's own instruction file (`CLAUDE.md`, `AGENTS.md`, `.kiro/steering/`). The review agent reads them and gives them priority over its own checklist.
- **Fewer phases:** delete the agent and remove its step from `commands/dev-cycle.md`.

## Cost

Phases are not equal, and the kit does not treat them as such:

- Mechanical work (running checks, writing the note) runs on a cheaper model; judgement work (planning, implementing, reviewing) runs on a stronger one. The `model` field in each agent file sets this, and tools that do not support it simply ignore it.
- Error comparison is done by the script — logs never reach a model.
- Verify does not re-run the suite; it reads the Checks result for the same attempt.
- The light track removes an entire phase from trivial tasks.
- Improve runs on demand and only reads notes newer than the last analysis.

What really drives cost is rework. A well-described ticket with clear acceptance criteria is a cheaper ticket.

## Security

- Every agent is instructed never to write tokens, passwords, API keys or `.env` contents into reports — values become `[REDACTED]`.
- Before the final gate, the cycle scans the files it wrote for common secret patterns and reports the result.
- The scan is heuristic. Look over your notes before sharing them.

## Limitations

- The checks phase only recognises the four output formats listed above.
- A `SKIP`ed check protects nothing at that point — which is why it becomes a caveat.
- Verify reads code and results; visual behaviour and backend-dependent flows stay as manual tests.
- The 3-attempt limit prevents infinite loops, not failure. Large or ambiguous tickets tend to be rejected: split them.
- Subagent support differs between tools. Where a tool cannot spawn one, the orchestrator follows each agent file in sequence instead — same phases, one context.

## Contributing

Issues and pull requests are welcome, particularly: new output formats for `check-diff.sh`, adapters for other agent tools, and improvements to the phase prompts. Prompts are the product here, so a PR that changes one should say what behaviour it fixes.

## License

[MIT](LICENSE).
