# claude·stats

A minimal, **Claude-themed** desktop widget for macOS that monitors your
Claude.ai usage in real time — a Flutter take on
[claude-usage-widget](https://github.com/SlavomirDurej/claude-usage-widget),
with a warm Claude palette, integrated window chrome, and a glitchy
shader-rendered history chart.

## Features

- **One-click sign in** — "Log in with Claude" opens claude.ai in an embedded
  webview and captures your session automatically (no DevTools). The key is
  stored only in the macOS Keychain. A paste-key fallback is tucked under
  "Advanced".
- **Session (5-hour) + Weekly (7-day) limits** as heat-coloured rings and bars,
  with live "resets in …" countdowns.
- **Warm heat ramp** (coral → amber → red) driven by configurable warn/danger
  thresholds.
- **Shader-based 7-day history chart** — a fragment shader
  (`shaders/usage_chart.frag`) renders the history as a glitchy telemetry
  waveform with chromatic aberration, scanlines, grain and an animated scan
  sweep. Toggle Session/Weekly.
- **Per-model breakdown** (Opus / Sonnet / Cowork …) and **extra-usage** budget.
- **Auto-refresh** (1/5/15/30 min) with a glitch refresh indicator, plus
  threshold **desktop notifications**.
- **Integrated macOS window chrome** — hidden native title bar with the
  traffic-light buttons floating over a full-size content view; drag-to-move;
  optional always-on-top.
- **Compact mode**, 12/24-hour time, reset-date display.
- **Demo mode** — explore the full UI with synthetic data, no key required.

## Sign in

Click **Log in with Claude** and sign in normally in the embedded browser. The
app watches the cookie store and, the moment your `sessionKey` appears, captures
it, resolves your organisation, and starts showing live usage from
`https://claude.ai/api/organizations/{org}/usage` (plus `overage_spend_limit`
and `prepaid/credits`).

> This uses claude.ai's private web API with your own session, exactly like the
> reference widget. Nothing is sent anywhere but claude.ai.

## Run

```bash
flutter pub get
flutter run -d macos
```

Requires Flutter ≥ 3.35 (uses `dart:ui` `FragmentProgram`). Fonts (Inter /
Newsreader / JetBrains Mono) are fetched via `google_fonts` on first run.

## Architecture

```
lib/
  main.dart                  window setup (integrated chrome) + routing + capture harness
  theme/claude_theme.dart    palette, typography, tokens
  models/usage.dart          UsageWindow / ExtraUsage / UsageSnapshot / HistoryPoint
  data/
    claude_api.dart          ClaudeApiClient (organizations → usage → overage/prepaid)
    session_store.dart       Keychain-backed sessionKey / org / settings / history
    demo_data.dart           synthetic snapshot + history
  state/
    app_controller.dart      ChangeNotifier: auth, refresh loop, history, notifications
    settings.dart            persisted preferences
  ui/
    sign_in_screen.dart      one-click login (+ paste fallback) over a glitch hero
    login_webview.dart       embedded claude.ai login, auto-captures sessionKey
    dashboard_screen.dart    rings, chart, per-model, extra usage
    settings_panel.dart      thresholds / interval / toggles / sign-out
    widgets/                 window_scaffold, usage_ring, heat_bar, shader_chart,
                             glitch_hero_panel, glitch_text, countdown_text, app_card
shaders/
  glitch_hero.frag           sign-in background
  usage_chart.frag           history chart (data uploaded via a sampler texture)
```

### Dev: visual capture harness

`main.dart` can screenshot itself (real GPU shaders included), since macOS
`screencapture` needs Screen-Recording permission the toolchain may lack:

```bash
flutter build macos --debug \
  --dart-define=shotpath=/abs/out.png \   # capture content to PNG, then exit
  --dart-define=demo=true \               # start in demo mode
  --dart-define=settings=true             # open the settings panel
open -n build/macos/Build/Products/Debug/claude_stats.app
```

None of these defines affect a normal build. The debug build also disables the
app sandbox (so the capture can write out, and Keychain access is simple); the
release entitlements keep the sandbox on.
```
