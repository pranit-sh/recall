# Recall

A native, local-only clipboard manager for macOS.

Recall keeps recently copied text and images close at hand from the menu bar.
History, settings, image files, and contextual usage data remain on the Mac.

<img src="docs/images/recall-popover.png" alt="Recall clipboard history popover" width="420">

## Features

- Searchable, deduplicated text and image history
- Compact image rows with dimensions and hover previews
- Keyboard-first navigation
- Context-aware ranking for the active application
- Independent text, image-count, and image-storage limits
- Configurable displayed-item count and ignored applications
- Launch at login with fully local storage

## Requirements

- macOS 14 or later
- Xcode 27 or later

## Getting started

Open `Clipboard.xcodeproj` in Xcode, select the `Clipboard` scheme, and run the
app. Recall appears only in the menu bar.

## Project structure

```text
Clipboard/
  Application/    App lifecycle and composition root
  Domain/         Clipboard models, history rules, and ports
  Infrastructure/ Pasteboard, persistence, and macOS adapters
  Presentation/   SwiftUI views and presentation logic
ClipboardTests/   Unit tests
```

Clipboard metadata is stored locally in
`~/Library/Application Support/Clipboard/history.sqlite3`. Image data is stored
in `~/Library/Application Support/Clipboard/Images/`.

## Build

```shell
xcodebuild -project Clipboard.xcodeproj \
  -scheme Clipboard \
  -configuration Debug \
  -derivedDataPath DerivedData \
  build CODE_SIGNING_ALLOWED=NO
```

```shell
open DerivedData/Build/Products/Debug/Recall.app
```

## Releases

Recall is currently distributed as source code. See [CHANGELOG.md](CHANGELOG.md)
for version history.

## Privacy

Recall does not send clipboard contents or usage data off-device. Ignored
applications can be configured in Settings, and saved history can be cleared at
any time.

## License

Recall is available under the [MIT License](LICENSE).