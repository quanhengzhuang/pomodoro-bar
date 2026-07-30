# TODO

- [x] Save a record when a timer is ended after reaching 5 minutes, with the prior behavior documented in the task.
- [x] Calculate “time outside Pomodoro” as wall-clock time since the first session began minus active timer duration.
- [x] Show the current note in the menu status row.
- [ ] Evaluate whether the note-editing action can be placed in the status row.
- [ ] Group “All Records” into submenus for the last 7 days while retaining the 10 most recent records.
- [x] Remove the dangerous “Clear Records” action and add an action to open `records.json`.
- [x] Allow extending an active countdown by 5 minutes by default; remove “Set Focus Duration” and keep focus fixed at 25 minutes.
- [x] Use `scripts/restart.sh` to run a new version and automatically exit the old instance.
- [x] Unify the application icon, menu bar tomato icon, and README icon.
- [x] Press Space while the menu is open to pause or resume.
- [x] Remove “Reset” and “Skip to Next Session” in favor of “End”.
- [x] Provide Chinese and English versions of all documentation, with language-switch links only in the README.
- [x] Show elapsed time in the first menu row for both count-up and countdown timers.
- [x] Exclude paused time from active session duration and include it in “time outside Pomodoro”.
- [x] Label count-up sessions as “Timer” and use an orange icon for their historical records.
