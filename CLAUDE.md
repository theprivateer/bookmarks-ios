# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

Build and test via Xcode or `xcodebuild`:

```bash
# Build main app
xcodebuild -project Bookmarks.xcodeproj -scheme Bookmarks -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build share extension
xcodebuild -project Bookmarks.xcodeproj -scheme BookmarksShareExtension -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run tests
xcodebuild -project Bookmarks.xcodeproj -scheme Bookmarks -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Open `Bookmarks.xcodeproj` in Xcode to run on device or simulator interactively.

## Architecture

SwiftUI iOS app with a share extension. No SwiftData — persistence is handled by a remote API.

### Main app (`Bookmarks` target)

- **`BookmarksApp.swift`** — entry point; renders `SettingsView` directly
- **`Features/Settings/SettingsView.swift`** — form for entering and saving API base URL and API key
- **`Shared/SettingsStore.swift`** — reads/writes settings via `UserDefaults(suiteName:)` using the shared App Group `group.com.philstephens.Bookmarks`; both the main app and share extension read from the same store
- **`Shared/BookmarkAPIClient.swift`** — `POST /bookmarks` with `Authorization: Bearer` header; throws `BookmarkAPIError` on misconfiguration or non-2xx responses

### Share extension (`BookmarksShareExtension` target)

- **`ShareViewController.swift`** — `UIViewController` subclass; extracts a `public.url` item from the extension context, calls `BookmarkAPIClient.createBookmark`, auto-dismisses on success
- **`ShareExtensionView.swift`** — SwiftUI view with `.loading`, `.success`, and `.failure` states; embedded via `UIHostingController`
- **`Info.plist`** — sets `CFBundleDisplayName: Add to My Bookmarks`; activation rule restricts to single web URLs; uses `NSExtensionPrincipalClass` (no storyboard)

### Shared files

`SettingsStore.swift` and `BookmarkAPIClient.swift` live under `Bookmarks/Shared/` but must be added to **both** targets in Xcode (File Inspector → Target Membership).

## Required Xcode capabilities

Both targets need the **App Groups** capability with group ID `group.com.philstephens.Bookmarks`. Without this, `SettingsStore` silently returns empty strings and the extension will show a configuration error.

## API

`POST {baseURL}/bookmarks` — body: `{"url": "..."}`, header: `Authorization: Bearer {apiKey}`. Full spec at `docs/openapi.yaml`.

## Rules

Rules in `.claude/rules/` auto-load for `.swift` files: `swift.md` (language guidelines), `swift-swiftui.md` (SwiftUI patterns), `swiftdata.md` (SwiftData patterns).
