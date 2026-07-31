# Use Wall-Clock Time For Active Duration

## Goal

When the user has not paused manually, count-up records should use real elapsed time.

## Changes

- Stop relying on per-second ticks to accumulate count-up duration.
- Track manual pause start time and accumulated paused seconds.
- Compute active duration as `now - startedAt - manual paused duration`.
- Use the same active-duration calculation for countdown display, records, and time inside Pomodoro.

## Affected Files

- `Sources/main.swift`
- `docs/tasks/task-20260731-1039-wall-clock-active-duration.md`
- `docs/en/tasks/task-20260731-1039-wall-clock-active-duration.md`

## Estimated Lines

About 45 lines.

## Result

Implemented. Active duration is now computed as `now - startedAt - manual paused duration`; count-up sessions no longer depend on per-second tick accumulation. `./scripts/build.sh` passes.
