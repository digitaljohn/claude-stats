<p align="center">
  <img src="docs/icon.png" alt="Claude Stats" width="120">
</p>

# claude·stats

> A tiny, Claude-themed desktop widget that tells you how much Claude you have left to Claude.

[![Platform](https://img.shields.io/badge/platform-macOS-1F1E1D?logo=apple)](https://github.com/digitaljohn/claude-stats)
[![Flutter](https://img.shields.io/badge/Flutter-3.35-1F1E1D?logo=flutter)](https://flutter.dev)
[![Tests](https://img.shields.io/badge/tests-230%20passing-D97757)](#testing)
[![Coverage](https://img.shields.io/badge/coverage-100%25-D97757)](#testing)
[![License](https://img.shields.io/badge/license-MIT-A6A399)](LICENSE)
[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-FFDD00?logo=buymeacoffee&logoColor=black)](https://www.buymeacoffee.com/digitaljohn)

A minimal macOS desktop widget that watches your **Claude.ai usage limits** in
real time — session, weekly, per-model — so you find out you're rate-limited
*before* you're mid-sentence on the thing that was definitely going to work this
time.

<p align="center">
  <img src="docs/screenshot.png" alt="claude·stats dashboard" width="380">
</p>

> _Yes, it's a Claude usage monitor. Yes, it was built with Claude (in Claude
> Code). We've achieved full recursion. Please clap._

---

## Where this came from

Full credit where it's due: this is a Flutter cover version of
[**SlavomirDurej/claude-usage-widget**](https://github.com/SlavomirDurej/claude-usage-widget) —
the excellent Electron original that pioneered the "log into claude.ai, read the
usage endpoint, draw some rings" idea. We kept the spirit and the endpoints,
swapped Electron for Flutter, and dressed it in Claude's own warm palette. If you
want the battle-tested cross-platform tool, go star theirs. This one is for
people who type `flutter run` for fun.

## Features

- **Lives in the menu bar.** A custom gauge icon and your **session %** sit up
  in the macOS menu bar like a battery readout, refreshed automatically. Click
  it to bring the window forward.
- **One-click sign in.** Hit **Log in with Claude** and an embedded claude.ai
  browser opens. Sign in like a normal human; the moment your `sessionKey`
  cookie appears, the app grabs it, discovers every org your login can reach, and
  starts pulling live numbers. No DevTools, no copy-pasting cookies at midnight.
  (A paste-the-key fallback is tucked under _Advanced_ for the cookie
  connoisseurs.)
- **Session + Weekly limits** as heat-coloured rings and bars, with live
  `resets in …` countdowns — the two numbers you actually care about, big.
- **A countdown ring that switches gears.** When you hit a limit, the ring stops
  bragging about "100%" and becomes a countdown: full circle = **1 hour** while
  minutes remain, then snaps to a **1-minute** face for the final-seconds
  nail-biter. Watching it empty is weirdly therapeutic.
- **Per-model breakdown** — Opus, Sonnet, Haiku, Cowork, and friends, read from
  the API's `weekly_scoped` limits so a model can't hide from you.
- **Account switcher.** One claude.ai login often spans more than one org — a
  **personal** workspace next to a **corporate/team** one — each with its own
  limits. When the app spots more than one, a switcher appears at the top of the
  dashboard so you can flip between them in a tap. Each org keeps its **own
  7-day history**, so switching never smears one account's usage across another.
- **Keyboard side lights** _(NuPhy Air75 V2 — very experimental)_ — mirror your
  usage onto the keyboard's two side strips: **left = session**, **right =
  weekly**, each a 6-LED fill that runs white → amber → red. A toggle appears
  under **Settings → Keyboard** only when a compatible keyboard is detected.
  Needs a one-time custom-firmware flash — see [`firmware/`](firmware/README.md).
- **7-day history chart** — a crisp `CustomPaint` column chart that goes cream →
  amber → red exactly where you breached a threshold.
- **Auto-refresh** every 1 / 5 / 15 / 30 min, with **desktop notifications**
  when you cross your warn/danger thresholds.
- **Update checks** — compares your version against the latest GitHub release
  and offers a one-click download when a newer one ships.
- **Integrated macOS window chrome.** Hidden native title bar, traffic-light
  buttons floating over a full-size content view, drag-to-move anywhere,
  optional always-on-top. It looks like it belongs.
- **Mini mode** for the corner of your screen, **compact mode**, 12/24-hour
  time, and a **demo mode** so you can play with the whole UI without handing
  over a single cookie.

## How sign-in works (and where your key lives)

Click **Log in with Claude** → sign in in the embedded webview → done. Under the
hood the app polls the cookie store and, when `sessionKey` shows up, reads your
usage from claude.ai's private web API:

```
GET https://claude.ai/api/organizations/{org}/usage
GET https://claude.ai/api/organizations/{org}/overage_spend_limit
GET https://claude.ai/api/organizations/{org}/prepaid/credits
```

Your session key is stored in an **app-private JSON file inside the macOS
sandbox container** (`claude_stats.json`), base64-wrapped so it isn't grep-able
plaintext. To be crystal clear: that's _obfuscation, not encryption_, and it's
**not** the Keychain. It never leaves your machine except to talk to claude.ai —
the same place your browser already sends it.

## Install

**Download** the latest `.dmg` from the [**Releases**](https://github.com/digitaljohn/claude-stats/releases)
page, open it, and drag **claude·stats** into Applications.

> The build is unsigned (no Apple Developer account yet), so macOS Gatekeeper
> blocks it on first launch. Right-click the app → **Open** → confirm, or run
> `xattr -dr com.apple.quarantine /Applications/claude_stats.app`.

**Or build from source** — you'll need the [Flutter SDK](https://flutter.dev)
(3.35+) and Xcode:

```bash
git clone https://github.com/digitaljohn/claude-stats.git
cd claude-stats
flutter pub get
flutter run -d macos     # run it…
flutter build macos      # …or build a release .app
```

Just want to admire the UI without a session key? Add `--dart-define=demo=true`.

## Tech stack

| | |
|---|---|
| **Framework** | Flutter 3.35 / Dart 3.9 |
| **Window chrome** | [`window_manager`](https://pub.dev/packages/window_manager) — frameless title bar + traffic lights |
| **Menu bar** | [`tray_manager`](https://pub.dev/packages/tray_manager) — NSStatusItem icon + live % |
| **Embedded login** | [`flutter_inappwebview`](https://pub.dev/packages/flutter_inappwebview) — WKWebView + cookie capture |
| **Browser launch** | [`url_launcher`](https://pub.dev/packages/url_launcher) — opens release / coffee links |
| **Typography** | [`google_fonts`](https://pub.dev/packages/google_fonts) — Hanken Grotesk (UI) + JetBrains Mono (readouts) |
| **Notifications** | [`local_notifier`](https://pub.dev/packages/local_notifier) |
| **HTTP / storage / time** | `http`, `path_provider`, `intl` |

Charts and rings are hand-painted with `CustomPainter` — no chart library, no
runtime bloat.

## Project layout

```
lib/
├─ data/        claude_api.dart · session_store.dart · update_checker.dart · demo_data.dart
├─ models/      usage.dart           (windows, snapshot, history points)
├─ state/       app_controller.dart  (fetch loop, notifications, modes) · settings.dart
├─ theme/       claude_theme.dart    (the warm Claude palette + type scale)
├─ ui/          dashboard · mini · sign_in · settings · login_webview · tray (menu bar)
│  └─ widgets/  usage_ring · heat_bar · chart_columns · countdown_text · …
└─ main.dart    integrated-chrome + menu-bar bootstrap (+ screenshot harness)
```

## Testing

165 tests, **100% line coverage** — including the painters, the timers, the
fetch loop, and the bit of maths that decides whether your countdown ring is
counting hours or panicking in seconds.

```bash
flutter test --coverage
```

We test the boring stuff so you can trust the pretty stuff.

## The fine print

This app talks to claude.ai's **private, undocumented web API** using **your
own** logged-in session — exactly like the reference widget, and exactly like
your browser does. It is **not affiliated with or endorsed by Anthropic**, and
if they change the API one Tuesday afternoon, the rings may briefly become
abstract art. No warranty, no usage data sold, nothing phones home. Don't ship
your `sessionKey` to anyone, including very polite strangers.

## Support

If this spares you one too many "you've reached your limit" surprises, you can
[**buy me a coffee** ☕](https://www.buymeacoffee.com/digitaljohn) — entirely
optional, deeply appreciated. (There's a coffee button in the title bar, too.)

## License

[MIT](LICENSE) © John Chipps-Harding. Inspired by
[claude-usage-widget](https://github.com/SlavomirDurej/claude-usage-widget).

<sub>Built with Flutter, caffeine, and an unreasonable amount of Claude — the very
resource this app exists to ration.</sub>
