# Platform support

claude·stats targets three desktop hosts: **macOS**, **Windows**, and **Linux**.
The Flutter UI, the claude.ai API client, storage, settings, history, the
auto-refresh loop and notifications are all platform-agnostic. A handful of
behaviours genuinely differ per OS, and every one of those decisions is funnelled
through a single capability object — [`lib/platform/platform_support.dart`](../lib/platform/platform_support.dart) —
so the rest of the app never branches on `Platform.isX` inline.

## The capability layer

`PlatformSupport` is constructed from a `HostOs` (`macos` / `windows` / `linux`)
and exposes pure-getter capabilities. The live instance is a mutable static
(`PlatformSupport.current`), mirroring the existing `AppColors.current` pattern,
so tests can pump any host's behaviour and every branch stays covered.

| Capability | macOS | Windows | Linux | Why |
|---|:---:|:---:|:---:|---|
| `hasEmbeddedWebview` | ✅ | ✅ | ❌ | `flutter_inappwebview` ships a WebView on macOS (WKWebView) and Windows (WebView2), but declares **no Linux** platform. |
| `usesTrafficLights` | ✅ | ❌ | ❌ | macOS hides the native title bar and floats the traffic-light buttons over the content; Windows/Linux keep their native title bar + window controls. |
| `trayShowsTitle` | ✅ | ❌ | ❌ | Only the macOS `NSStatusItem` renders text beside the icon; elsewhere the live % rides in the tray tooltip. |
| `trayIconIsTemplate` | ✅ | ❌ | ❌ | "Template" (auto-tinted monochrome) icons are a macOS menu-bar concept. |

## Sign-in: webview vs. browser fallback

Authentication is "log into claude.ai, capture the `sessionKey` cookie". How that
capture happens depends on `hasEmbeddedWebview`:

- **macOS / Windows** — the embedded `LoginWebView` (`flutter_inappwebview`)
  opens claude.ai in-app and polls the cookie store; the moment `sessionKey`
  appears it's captured automatically. (A paste-the-key field stays available
  under _Advanced_.)
- **Linux** — there is no embedded webview, so the **Sign-in screen swaps the CTA
  to "Open claude.ai"** (launches the system browser via `url_launcher`) and
  shows the sessionKey paste field up-front. The user signs in in their browser,
  copies the cookie, and pastes it back. No platform-specific cookie decryption
  — just the same capture, surfaced differently.

The `LoginWebView` widget is never constructed on Linux, so the (Linux-less)
`flutter_inappwebview` native plugin is never invoked there.

## Window chrome

`main.dart` only applies `TitleBarStyle.hidden` (the frameless, traffic-light
look) on macOS. Windows and Linux keep their **native title bar** — and with it
the standard minimize / maximize / close controls — while `WindowScaffold` drops
the macOS traffic-light clearance from its in-content title row. A fully custom
frameless chrome with hand-drawn caption buttons on Windows/Linux is a possible
follow-up.

## Building

```bash
flutter build macos      # .app  (released as a .dmg)
flutter build windows    # .exe + bundle
flutter build linux      # bundle (needs GTK/ninja dev packages — see ci.yml)
```

> **Status:** the Windows and Linux runners (`windows/`, `linux/`) are generated
> via `flutter create` and the Dart abstractions are unit-tested, but the
> non-macOS builds are validated in CI rather than hand-tested on real hardware.
> First-run polish on those platforms (icon assets, installer packaging,
> notification backends) may need iteration.
