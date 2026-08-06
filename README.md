# MacBook Dynamic Island

A small, local-first macOS app that adds a floating, notch-style island to your desktop.

## Features

- Apple Music artwork and playback controls
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
swift build -c release
./scripts/make_app_bundle.sh
open build/MacBookDynamicIslandApp.app
```

The script creates an unsigned local app at `build/MacBookDynamicIslandApp.app`.

## Privacy

Clipboard history and the file shelf stay in memory and are cleared when the app quits. Settings and an optional weather city are saved locally. The app uses no accounts, telemetry, or API keys; network access is limited to optional weather, NBA scores, and an Apple Music artwork fallback.

This is an unofficial personal project and is not affiliated with or endorsed by Apple or the NBA.
