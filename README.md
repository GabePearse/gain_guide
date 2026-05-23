# GainGuide

GainGuide is a Flutter workout tracker for planning routines, logging sets, reviewing progress, and staying accountable with friends.

## Features

- Create and manage custom workouts
- Add exercises with reps and weight entries
- Complete workouts and review workout history
- Track progress across saved sessions
- Sign in with local accounts, Google, or Apple
- Add friends, send reminder nudges, and check in
- Schedule smart local workout reminders
- Store app data locally with SQLite

## Tech Stack

- Flutter
- Provider for app state
- sqflite for local persistence
- flutter_local_notifications for reminders
- Google Sign-In and Sign in with Apple

## Getting Started

Install Flutter, then run:

```sh
flutter pub get
flutter run
```

To run checks:

```sh
flutter analyze
flutter test
```

## Project Structure

- `lib/models`: app data models
- `lib/pages`: main app screens
- `lib/providers`: shared workout and account state
- `lib/services`: database, auth, and notification services
- `lib/widgets`: reusable UI components

## Status

This is an early personal fitness app with local-first workout tracking and social accountability features.
