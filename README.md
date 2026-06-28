# MicGate

MicGate is a small macOS menu bar utility for toggling the input microphone with a global hotkey.

It shows the current microphone state in the menu bar, sends a notification when the state changes,
and lets you record a custom hotkey by pressing the shortcut directly.

## Features

- Toggle microphone input volume between muted and unmuted.
- Uses CoreAudio for microphone control.
- Default hotkey: `Option + /`.
- Menu bar icon reflects the current microphone state.
- Left click toggles the microphone.
- Right click opens the menu.
- Record a custom hotkey interactively.
- Reset the hotkey to default.
- Optionally launch MicGate automatically at login.
- Uses a HID-level `CGEventTap` so hotkeys can still work when apps like Moonlight capture normal hotkeys.

## Permissions

MicGate requires Accessibility permission to listen for the global hotkey.

On first launch, MicGate blocks startup until permission is granted. Use:

```text
System Settings -> Privacy & Security -> Accessibility
```

Add `MicGate.app`, enable it, then return to MicGate and click `Check Again`.

If the hotkey still does not work after replacing or rebuilding the app, remove the old MicGate entry from
Accessibility and add the new build again. macOS can treat rebuilt ad-hoc signed apps as a different binary.

## Build

Command line build:

```sh
Scripts/build-app.sh
```

The app bundle is written to:

```text
Build/Release/MicGate.app
```

The build script compiles with `swiftc`, copies resources, writes `Info.plist`, and ad-hoc signs the app.

GitHub Actions builds a DMG for every push to `master`, publishes it in GitHub Releases, and bumps the minor
version for the published build.

## Xcode

Open:

```text
MicGate.xcodeproj
```

The shared scheme is `MicGate`.

## Formatting

The project uses SwiftFormat with an Airbnb-inspired configuration:

```sh
Scripts/format.sh
```

Install SwiftFormat with:

```sh
brew install swiftformat
```
