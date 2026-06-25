# Porting Ferdium to iPadOS

This document describes the **Strategy A** port of Ferdium to iPadOS: a native
Swift shell that hosts the existing React/MobX renderer in a `WKWebView` and runs
each messaging service inside its own isolated `WKWebView`. It complements the
native project under [`ipados/`](../ipados) and the renderer-side platform
abstraction under [`src/platform/`](../src/platform).

## Why not "just rebuild the macOS app"?

The desktop app is **Electron** (Chromium + Node.js). Apple does not permit
Electron, Chromium embedding, Node.js runtimes, or JIT browser engines on iPadOS —
all web content must run in **WebKit (`WKWebView`)**. So the port replaces the two
load-bearing desktop layers (the Electron shell and the embedded AdonisJS Node
server) while salvaging the renderer, recipe system, and UX.

## Architecture

```
┌───────────────────────────── Native Swift shell (ipados/) ─────────────────────────────┐
│                                                                                          │
│  FerdiumApp / AppDelegate            HostWebView (WKWebView)                              │
│      │                                   │  loads bundled renderer (esbuild ./build)     │
│      │                                   │  window.ferdiumNative  ⇄  PlatformBridge      │
│      ▼                                   ▼                                                │
│  AppModel ── ServiceWebViewManager ── one WKWebView per service                          │
│      │            │                       │  WKWebsiteDataStore per `partition`           │
│      │            │                       │  recipe-bridge.js (notifications, badges)     │
│      │            ▼                       ▼                                                │
│      ├── NotificationBridge  → UNUserNotificationCenter                                   │
│      ├── DownloadBridge       → WKDownloadDelegate → Files app                            │
│      └── LocalStore           → JSON/SQLite (replaces internal AdonisJS server)           │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

## Capability matrix (Electron → iPadOS)

| Electron feature | iPadOS replacement | Status |
|---|---|---|
| `BrowserWindow` + renderer | Host `WKWebView` (`HostWebView.swift`) | Scaffolded |
| `<webview partition>` per service | One `WKWebView` + `WKWebsiteDataStore` per partition (`ServiceWebViewManager.swift`) | Scaffolded |
| Internal AdonisJS server + `sqlite3` | `LocalStore.swift` (JSON now, SQLite/GRDB later) | Scaffolded |
| `Tray`, `TouchBar`, `globalShortcut`, DBus | Dropped (no desktop equivalents) | Dropped |
| `electron-updater` | App Store updates | Dropped |
| Notifications (`notifications.ts` monkey-patch) | `recipe-bridge.js` → `NotificationBridge` → `UNUserNotificationCenter` | Scaffolded |
| `electron-dl` downloads | `DownloadBridge` (`WKDownloadDelegate`) → Files | Scaffolded |
| `ferdium:` deep links | iOS URL scheme + Universal Links (`Info.plist`, `onOpenURL`) | Scaffolded |
| Camera/mic permissions | `Info.plist` usage strings + WebKit prompts | Scaffolded |
| Spellcheck/context-menu/zoom/find | WebKit-native | Deferred |

## Renderer ⇄ native contract

The renderer talks to native code through a single abstraction,
[`IPlatformBridge`](../src/platform/PlatformBridge.ts):

- `ElectronPlatformBridge` — wraps `ipcRenderer` (desktop, default).
- `WebKitPlatformBridge` — wraps `window.ferdiumNative` (iPadOS).

`getPlatformBridge()` returns the right one based on `isWebKitHost`/`isIpad` from
[`src/environment.ts`](../src/environment.ts). The native shim
(`ipados/.../platform-bridge.js`) is injected at document start and provides
`send` / `request` (promise) / `on` over `WKScriptMessageHandler`.

Service recipes are unchanged web injections: `recipe-bridge.js` re-implements the
`window.ferdium` API and the notification monkey-patch from
[`src/webview/notifications.ts`](../src/webview/notifications.ts), posting events to
native instead of using `ipcRenderer.sendToHost`.

## Building

```bash
# 1. Build the renderer and copy it into the app bundle
./ipados/scripts/bundle-renderer.sh

# 2. Generate the Xcode project from the declarative spec
cd ipados && xcodegen generate

# 3. Build / run from Xcode, or:
xcodebuild -project Ferdium-iPadOS.xcodeproj -scheme Ferdium-iPadOS \
  -destination 'generic/platform=iOS Simulator' build
```

CI runs the same steps in [`.github/workflows/ipados.yml`](../.github/workflows/ipados.yml)
(unsigned simulator build).

## Phased delivery

1. **Spike** — host the renderer in a single `WKWebView`; prove the bridge. *(scaffolded)*
2. **Single service** — one isolated service `WKWebView` with recipe injection,
   unread badges, and notifications. *(scaffolded)*
3. **Multi-service + local API** — per-service isolation, replace `LocalApi`
   backend, workspaces.
4. **UX hardening** — touch/keyboard (`UIKeyCommand`), Split View / Stage Manager,
   settings, downloads, deep links.
5. **Compliance + release** — signing, TestFlight, App Store submission.

## Open questions / risks

- **App Review Guideline 4.7**: an app that loads many third-party messaging sites
  must document recipes as user-driven web content.
- **Recipes assume desktop**: user-agent strings and Electron behaviours mean many
  recipes need iPad-specific handling and some will break.
- **Background limits**: iOS restricts background execution, changing notification
  and unread-poll behaviour versus desktop.
- **Local-first server**: the AdonisJS internal server is a substantial subsystem
  to re-host on-device or eliminate.
