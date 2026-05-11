# Working Rules

These rules capture mistakes from the Event Viewer export work so future tasks do not repeat them.

## Requirements First

- Restate the user's actual requirement before changing code.
- Separate hard requirements from implementation ideas.
- Do not replace a required real artifact with a simulated or generated substitute.
- If the user needs a real Event Viewer screen, do not create a lookalike image and present it as equivalent.

## Diagnose Before Iterating

- Check the current state before retrying commands.
- When a command fails, identify the exact failure mode before trying another route.
- Do not repeat an interactive command that is waiting for user authentication without first explaining what input is needed.
- For GitHub work, verify these in order:
  - local repository exists
  - commit exists
  - remote exists
  - authentication works
  - push succeeds

## Security-Sensitive Automation

- Treat security product alerts as design feedback, not as an obstacle to work around silently.
- Do not automate system tools such as `eventvwr.exe` if the goal can be achieved by user-initiated opening.
- Avoid `PowerShell -ExecutionPolicy Bypass` in distributable launchers unless the user explicitly accepts that tradeoff.
- If a tool must open a sensitive Windows utility, prefer a user-clicked button or generated file shortcut over automatic process launch.

## Evidence Integrity

- Do not fabricate, redraw, or approximate evidence that the user intends to submit as an official record.
- Generated summaries and helper images must be labeled as generated, not treated as original screenshots.
- For Windows event evidence, preserve actual `.evtx` data and guide the user to open it in Event Viewer.

## UX For Local Tools

- Do not force the user to browse manually for files after running a launcher.
- After generating output, show a result dialog with direct buttons for the next user action.
- Include the target event details in the result:
  - source
  - event ID
  - logged time
  - message
- Keep generated files in a predictable output directory and show their full paths.

## Release Hygiene

- Update README whenever the user-facing workflow changes.
- Rebuild distribution ZIP after changing distributed files.
- Commit only relevant files.
- Keep unrelated workspace files ignored and out of commits.
- Push only after verifying the local status and the intended branch.
