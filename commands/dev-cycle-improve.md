---
name: dev-cycle-improve
description: "Runs the IMPROVE phase over the dev-cycle notes accumulated since the last analysis, and proposes process adjustments. Use periodically — every 5 to 10 tickets — not per ticket."
---

1. Via the shell, resolve the notes root: `echo "${DEV_CYCLE_HOME:-$HOME/dev-cycle}"` → `NOTES_DIR` (a literal absolute path).
2. Validate and create the report folder: `test -d "<NOTES_DIR>/Tickets" && mkdir -p "<NOTES_DIR>/Improve"`. If that fails (notes directory unreachable, or no tickets recorded yet), stop and tell the user — never create anything inside the repository.
3. Delegate to the `dc-improve` agent, with no specific ticket, passing `NOTES_DIR` literally. It works out for itself which ticket notes have not been analysed yet, from `Improve/_accumulated.md`.
4. Present the resulting `Improve/improve-<date>.md` report and highlight the proposed process adjustments. **Do not apply them yourself** — they are the team's call.
