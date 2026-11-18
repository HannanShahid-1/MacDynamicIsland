# MacBook Dynamic Island

A small, local-first macOS app that adds a floating, notch-style island to your desktop.

## Features

- Now playing with artwork and playback controls for Apple Music, Spotify, and browser video (YouTube in Safari, Chrome, or Firefox), or any other app that shows up in macOS's Now Playing
- Five-item clipboard history and a drag-and-drop file shelf
- Volume, brightness, charging, and AirPods feedback
- Custom layouts, colors, sizing, weather, and NBA scores

## Requirements

- macOS 13 or newer
- Xcode Command Line Tools with Swift 6

## Run locally

From the project folder:

```bash
swift run MacBookDynamicIslandApp
```

## Build the app

```bash
./scripts/make_app_bundle.sh
open build/MacBookDynamicIslandApp.app
```

The script runs a release build and creates an unsigned local app at `build/MacBookDynamicIslandApp.app`.

## Run the tests

```bash
swift test
```

## Project layout

```text
Sources/
  MacBookDynamicIslandCore/     NBA data and now-playing parsing (no UI, unit tested)
  MacBookDynamicIslandApp/
    App/                        Entry point and app delegate
    Models/                     Value types: layout, appearance, now playing, weather, clipboard, files
    Services/                   System and network access: now playing, weather, audio, brightness, power
    Store/                      IslandStore, the app's single observable state, split by feature
    Window/                     The floating panel, its controller, and notch-aware positioning
    Views/                      SwiftUI views, grouped by island mode (Player, NBA, Home, Workspace, Options)
Tests/
  MacBookDynamicIslandCoreTests/
  MacBookDynamicIslandAppTests/ Store behaviour, driven with fake now-playing data
scripts/
  make_app_bundle.sh            Builds the release binary and wraps it in an .app bundle
```

## Privacy

Clipboard history and the file shelf stay in memory and are cleared when the app quits. Settings and an optional weather city are saved locally. The app uses no accounts, telemetry, or API keys; network access is limited to optional weather, NBA scores, and an artwork lookup for Apple Music and Spotify tracks that arrive without a cover.

## How now playing works

The island shows whatever app currently owns macOS's system-wide Now Playing slot, the same one the menu bar and media keys use. Since macOS 15.4 only Apple's own processes may read that information, so the app runs a small script through `/usr/bin/osascript` that reads it and streams it back; nothing leaves the Mac, and no Automation permission is needed. Play, pause, and skip are sent straight to the system.

This relies on a private macOS framework (MediaRemote) and could stop working in a future macOS release. If the script cannot start, the app falls back to talking to Apple Music directly over AppleScript, which does ask for Automation access to Music.

This is an unofficial personal project and is not affiliated with or endorsed by Apple or the NBA.
