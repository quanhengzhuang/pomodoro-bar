# TODO

- [x] Save a record when a timer is ended after reaching 5 minutes, with the prior behavior documented in the task.
- [ ] Confirm the current behavior and semantics of calculating “time outside Pomodoro” up to now.
- [x] Show the current note in the menu status row.
- [ ] Evaluate whether the note-editing action can be placed in the status row.
- [ ] Group “All Records” into submenus for the last 7 days while retaining the 10 most recent records.
- [ ] Remove the dangerous “Clear Records” action and add an action to open `records.json`.
- [ ] Allow extending an active timer by 5 minutes by default; remove “Set Focus Duration” while keeping the default focus duration at 25 minutes.
- [x] Use `scripts/restart.sh` to run a new version and automatically exit the old instance.
- [x] Unify the application icon, menu bar tomato icon, and README icon.
- [x] Press Space while the menu is open to pause or resume.
- [x] Remove “Reset” and “Skip to Next Session” in favor of “End”.
- [x] Provide Chinese and English versions of all documentation, with language-switch links only in the README.
- [x] Show elapsed time in the first menu row for both count-up and countdown timers.
- [ ] Exclude paused time from the session duration instead of deriving duration from the start and end timestamps, and add paused time to “time outside Pomodoro”.
