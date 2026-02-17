# AGENTS.md

This file provides guidance to coding agents working in `/Users/wvmillen/looped/looped-iOS`.

## Scope
- This is the repository root.
- Main app target code lives in `looped-iOS/`.
- Unit tests live in `looped-iOSTests/`.
- UI tests live in `looped-iOSUITests/`.
- Xcode project files are in `looped-iOS.xcodeproj/`.

## Product Context
- **App**: Looped (workplace-verified social iOS app).
- **Platform**: iOS, SwiftUI, Combine, async/await.
- **Architecture**: MVVM on the client.
- **Backend**: Separate Java API (HTTP + WebSocket). iOS app is client-only.
- **Core themes**: privacy-first, pseudonymous by default, real-time social features.

## Repo Hygiene
- Do not modify local Xcode user state files unless explicitly asked:
  - `*.xcodeproj/**/xcuserdata/**`
  - `**/*.xcuserstate`
- Do not clean up unrelated diffs/untracked files unless explicitly asked.
- In this multi-agent repo, ignore unrelated changes unless they conflict with your work.

## Design System Rules (App Code)
When editing UI in `looped-iOS/`:
- Use only font tokens from `looped-iOS/Views/Shared/Core/LoopedFonts.swift`.
- Use only color tokens from `looped-iOS/Views/Shared/Core/LoopedColors.swift`.
- Do not use default system colors (`.white`, `.black`, `.gray`, etc.) or generic text styles (`.body`, `.headline`, etc.) unless explicitly approved.
- Prefer adding missing tokens to the design system files instead of hardcoding values.

## Client Responsibilities vs Backend
- iOS handles UI, client state, and API/WebSocket clients.
- Java backend handles business logic, persistence, auth decisions, and verification logic.
- Keep business rules out of SwiftUI views; place app-side behavior in ViewModels/services.

## Testing Guidance
Prioritize useful, non-brittle tests:
- Add most coverage in `looped-iOSTests/` for ViewModels/services.
- Prefer behavior/state assertions over implementation details.
- UI tests in `looped-iOSUITests/` should cover critical flows (auth, feed, messaging) using stable accessibility identifiers.
- Avoid pixel-perfect/color/layout assertions unless there is a specific visual regression requirement.

## Build/Test Notes
- Agents cannot run Xcode UI actions directly.
- User runs build/test in Xcode (`Cmd+R`, `Cmd+U`).
- Agent should still add/update tests and tell user exactly what to run.

## Working Style Expectations
- Keep view code lightweight; move logic into ViewModels.
- Use protocol-based services for testability and dependency injection.
- Prefer async/await for network calls and consistent error handling.
- Make focused changes with clear, minimal diffs.


## Required Testing Policy
- For meaningful bug fixes, add a regression test in the same change whenever practical.
- For new features, add tests for primary behavior and key error/edge states when testable.
- Prefer unit tests in `looped-iOSTests/` for ViewModels/services; reserve `looped-iOSUITests/` for critical user flows.
- If a test is not added, explicitly state why and what was manually verified.
- Always tell the user exactly which tests to run in Xcode after changes (`Cmd+U` or targeted test suites).
