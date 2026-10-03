# Changelog

All notable changes to Recall are documented in this file.

## 0.3.0 - 2026-10-03

### Added

- Clipboard history support for capturing, restoring, and copying PNG, JPEG, and TIFF images.
- Compact image rows with dimensions and a non-interactive hover preview beside the menu.
- Independent settings for saved text clips, saved images, and image storage.
- Local image-file storage with hash-based deduplication and SQLite metadata.

### Changed

- Reorganized General settings into Storage and Application sections.
- Applied the displayed-items limit to the combined text and image history.
- Limited images to 20 MB each and configurable totals of 50, 100, or 200 MB.
- Limited saved image counts to 5, 10, or 20.
- Show text tooltips only when a text row is truncated.

## 0.2.0 - 2026-10-03

### Added

- Native Settings tabs with an About screen and repository link.
- A dynamic search prompt showing the number of saved clipboard items.
- A screenshot of the clipboard popover in the README.

### Changed

- Refined popover dismissal behavior when opening Settings or confirmation dialogs.
- Updated visible-item limits to 15, 20, and 25.
- Improved ignored-application status presentation in the popover.

## 0.1.0 - 2026-10-03

### Added

- Menu-bar clipboard history with search and keyboard navigation.
- Most-recently-used ordering and deduplication.
- Local SQLite persistence with a configurable history limit.
- Context-aware ranking based on selections in the active application.
- Per-application privacy controls and a clear-history action.
- Launch-at-login support.
- Accessibility labels, keyboard focus behavior, and appearance support.
- Adaptive app icon with Default, Dark, and Mono appearances.

### Privacy

- Clipboard history and settings remain local to the Mac.
- Recall has no cloud sync, analytics, AI, or network data transfer.