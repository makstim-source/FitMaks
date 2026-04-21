# FitMaks Agent Instructions

FitMaks is a SwiftUI iOS app for food tracking, AI-assisted nutrition parsing, HealthKit steps, workouts, streaks, onboarding, themes, and daily progress.

## Safety

- Never commit API keys, tokens, secrets, private certificates, or generated credentials.
- Do not print, inspect, or quote secret values from `FitMaks/Config.swift`. Treat it as sensitive even if it exists locally.
- If a change touches authentication, API calls, or app configuration, verify that no secret is added to source control.
- Do not reset or revert user work unless explicitly asked.

## Product Rules

- Food entries created by async AI recognition must be saved to the date that was selected when the request started, not whatever date is selected when the response returns.
- Calories, protein, and steps have a 3% success tolerance for daily completion and perfect-day logic.
- Gym days add a step credit, and step summaries should explain real steps plus gym bonus.
- Protein progress should use the app's blue/cyan visual language, including when the user is below goal.
- Future calendar days should not show completion icons or sleep markers.
- Keep the app friendly on small iPhone screens: avoid clipped text, overlapping stats, and oversized buttons.

## Code Style

- Prefer small SwiftUI subviews over very large view bodies.
- Keep business rules centralized in shared helpers such as day-progress and goal-calculation logic.
- Avoid duplicating calorie, protein, steps, BMR, streak, and perfect-day calculations across views.
- Use clear names for extracted views and helper methods; avoid clever abbreviations.
- Preserve the existing visual direction unless the task explicitly asks for a redesign.

## Review Priorities

When reviewing pull requests, prioritize:

1. Bugs, crashes, data-loss risks, and regressions in date handling.
2. Secret leaks or unsafe handling of API keys.
3. SwiftData model changes, migrations, and persistence behavior.
4. HealthKit permission, step-count, and workout-credit correctness.
5. AI parsing consistency and user correction flows.
6. UI clipping, text overflow, and usability on narrow screens.
7. Missing tests or missing manual verification for risky changes.

## Verification

For code changes, prefer running:

```sh
xcodebuild -project FitMaks.xcodeproj -scheme FitMaks -destination 'generic/platform=iOS' -derivedDataPath /tmp/FitMaksDerivedData CODE_SIGNING_ALLOWED=NO build
```

For larger refactors, also run:

```sh
xcodebuild -project FitMaks.xcodeproj -scheme FitMaks -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/FitMaksDerivedData CODE_SIGNING_ALLOWED=NO build-for-testing
```

If Xcode-generated Swift macro warnings mention missing temporary replacement paths, first try a clean build or clear DerivedData before treating them as app-code failures.
