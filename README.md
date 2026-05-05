# Bookmarks

An iOS app for saving URLs to a self-hosted bookmarks API via the system share sheet.

## What it does

- **Settings screen** — stores your API base URL and API key
- **Share extension** — appears as "Add to My Bookmarks" in the iOS share sheet; sends the current URL to the API and auto-dismisses on success

## Requirements

- iOS 18+
- A running instance of the [Bookmarks API](docs/openapi.yaml)
- An Apple Developer account (required for App Groups capability)

## Setup

### 1. Xcode configuration

The share extension target (`BookmarksShareExtension`) requires two capabilities on **both** the main app and extension targets:

| Capability | Value |
|---|---|
| App Groups | `group.com.philstephens.Bookmarks` |

Add via: target → Signing & Capabilities → `+` Capability.

### 2. Add shared sources to the extension target

`Bookmarks/Shared/SettingsStore.swift` and `Bookmarks/Shared/BookmarkAPIClient.swift` must be members of both targets. Select each file in Xcode, open the File Inspector (⌥⌘1), and tick `BookmarksShareExtension` under Target Membership.

### 3. Configure the app

Run the `Bookmarks` scheme, enter your API base URL (e.g. `https://bookmarks.example.com/api/v1`) and API key, then tap **Save**. Verify the values persist after a force-quit and reopen before testing the extension.

### 4. Test the extension

Switch to the `BookmarksShareExtension` scheme and run — Xcode will ask which host app to launch; pick Safari. Open any page, tap Share, and "Add to My Bookmarks" will appear in the actions row. If it doesn't, tap **More** and enable it there.

## Project structure

```
Bookmarks/
├── BookmarksApp.swift                  # App entry point
├── Features/
│   └── Settings/
│       └── SettingsView.swift          # API configuration screen
└── Shared/
    ├── SettingsStore.swift             # Reads/writes settings via App Group UserDefaults
    └── BookmarkAPIClient.swift         # POST /bookmarks API call

BookmarksShareExtension/
├── ShareViewController.swift           # UIViewController; extracts URL, drives state
├── ShareExtensionView.swift            # SwiftUI loading/success/error UI
└── Info.plist                          # Extension config; sets display name and activation rule
```

## API

The extension calls `POST /bookmarks` with a JSON body of `{"url": "..."}` and an `Authorization: Bearer <key>` header. See [docs/openapi.yaml](docs/openapi.yaml) for the full spec.
