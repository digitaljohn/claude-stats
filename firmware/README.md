# Keyboard side-light firmware (NuPhy Air75 V2)

claude·stats can mirror your usage onto the **side LED strips** of a **NuPhy
Air75 V2** — left strip = session %, right strip = weekly %, each a 6-LED fill
that runs green → amber → red as you approach a limit.

The catch: NuPhy's **stock firmware does not expose the side LEDs to the
computer at all** (they're driven entirely on-keyboard, and they're not part of
the host-addressable RGB matrix). So this needs a **small one-time custom-QMK
flash**. Everything here is additive and reversible — re-flashing NuPhy's stock
firmware restores the keyboard exactly.

> ✅ **Built, flashed and verified on a real Air75 V2.** It compiles clean
> (~55 KB), flashes over `dfu-util`, and the gauge renders correctly on the side
> strips. It's still custom firmware you're flashing, though — read
> [Recovery](#recovery) first.

---

## How it works

The app talks to the keyboard's QMK **raw-HID** vendor interface (USB VID
`0x19F5`, usage page `0xFF60`, usage `0x61`) — the same channel VIA uses, a
plain vendor collection that has nothing to do with typing. It sends one tiny
report whenever your usage changes; the firmware paints the two side strips.

Connection must be **wired USB-C or the 2.4 GHz dongle** — Bluetooth does not
expose raw HID.

### Wire protocol

32-byte output report, report ID `0`:

| Byte | Meaning                                  |
|------|------------------------------------------|
| 0    | command — `0xC1` set gauge, `0xC0` release |
| 1    | left fill percent (0–100) — **session**  |
| 2–4  | left R, G, B (0–255)                      |
| 5    | right fill percent (0–100) — **weekly**  |
| 6–8  | right R, G, B (0–255)                     |
| 9–31 | zero                                      |

`0xC0` (release) hands the strips back to the keyboard's own animations. The app
sends it when you switch the feature off, sign out, or quit.

---

## Build & flash

You need the [QMK toolchain](https://docs.qmk.fm/#/newbs_getting_started) and a
NuPhy Air75 V2 QMK source tree. The community fork
[`qbane/qmk_firmware_nuphy`](https://github.com/qbane/qmk_firmware_nuphy) builds
cleanly; these instructions match its layout
(`keyboards/nuphy/air75_v2/ansi/`).

### 1. Make a keymap with raw HID enabled

```bash
cd keyboards/nuphy/air75_v2/ansi/keymaps
cp -r via claude_stats              # the fork ships a `via` keymap; base on it
```

Set `keymaps/claude_stats/rules.mk` to exactly:

```make
VIA_ENABLE = no
RAW_ENABLE = yes
```

> Disable VIA: it owns `raw_hid_receive` itself, which would collide with ours.
> `RAW_ENABLE` keeps the `0xFF60` interface. You keep the keymap's key layout;
> remapping is a separate concern.

### 2. Handle the report — `keymaps/claude_stats/keymap.c`

Append:

```c
#ifdef RAW_ENABLE
#include "raw_hid.h"

extern void cs_gauge_set(uint8_t, uint8_t, uint8_t, uint8_t,
                         uint8_t, uint8_t, uint8_t, uint8_t);
extern void cs_gauge_release(void);

void raw_hid_receive(uint8_t *data, uint8_t length) {
    if (length < 1) return;
    switch (data[0]) {
        case 0xC1: // [0xC1, leftPct, lr,lg,lb, rightPct, rr,rg,rb]
            if (length >= 9)
                cs_gauge_set(data[1], data[2], data[3], data[4],
                             data[5], data[6], data[7], data[8]);
            break;
        case 0xC0:
            cs_gauge_release();
            break;
    }
}
#endif
```

### 3. Render the gauge — `ansi/side.c`

NuPhy already gives us everything: `side_rgb_set_color()`, the `SIDE_LINE` count
(6 lines), and `side_led_index_tab[line] = { left_led, right_led }` ordered
front → back. Add this block near the other side helpers (e.g. just after
`set_right_rgb`):

```c
// ── claude·stats host gauge ─────────────────────────────────────────────────
static bool    cs_active = false;
static uint8_t cs_lp, cs_lr, cs_lg, cs_lb, cs_rp, cs_rr, cs_rg, cs_rb;

void cs_gauge_set(uint8_t lp, uint8_t lr, uint8_t lg, uint8_t lb,
                  uint8_t rp, uint8_t rr, uint8_t rg, uint8_t rb) {
    cs_active = true;
    cs_lp = lp; cs_lr = lr; cs_lg = lg; cs_lb = lb;
    cs_rp = rp; cs_rr = rr; cs_rg = rg; cs_rb = rb;
}

void cs_gauge_release(void) { cs_active = false; }

static uint8_t cs_fill(uint8_t pct) {
    uint16_t n = ((uint16_t)pct * SIDE_LINE + 50) / 100; // nearest LED
    return n > SIDE_LINE ? SIDE_LINE : (uint8_t)n;
}

static void cs_gauge_render(void) {
    uint8_t ln = cs_fill(cs_lp), rn = cs_fill(cs_rp);
    for (uint8_t line = 0; line < SIDE_LINE; line++) {
        uint8_t l = side_led_index_tab[line][0]; // left strip  (LEDs 5..0)
        uint8_t r = side_led_index_tab[line][1]; // right strip (LEDs 6..11)
        // fill from the bottom up: light the last `ln`/`rn` lines
        if (line >= SIDE_LINE - ln) side_rgb_set_color(l, cs_lr, cs_lg, cs_lb);
        else                        side_rgb_set_color(l, 0, 0, 0);
        if (line >= SIDE_LINE - rn) side_rgb_set_color(r, cs_rr, cs_rg, cs_rb);
        else                        side_rgb_set_color(r, 0, 0, 0);
    }
}
```

Then, at the **very top of `side_led_show(void)`**, take over when active:

```c
void side_led_show(void) {
    if (cs_active) {            // claude·stats owns the side LEDs
        cs_gauge_render();
        side_rgb_refresh();
        return;
    }
    // ... existing body unchanged ...
```

Finally, so a Fn keypress always rescues you (e.g. if the app quits hard), clear
the override when the side-light **mode** key is pressed — add one line at the
top of `side_mode_control`:

```c
void side_mode_control(uint8_t dir) {
    cs_active = false;          // Fn + side-mode exits the claude·stats gauge
    // ... existing body ...
```

### 4. Compile & flash

```bash
qmk compile -kb nuphy/air75_v2/ansi -km claude_stats
```

Put the board in bootloader (hold **Esc** while plugging in USB, or the board's
reset combo), then flash the resulting `.bin`/`.uf2` with
[QMK Toolbox](https://github.com/qmk/qmk_toolbox). Keep it **wired** for both
flashing and using the feature.

Then in claude·stats → **Settings → Keyboard → NuPhy side lights**. The toggle
only appears when a keyboard is detected.

> Keep the side-light brightness above zero (Fn + M + ↑) — at brightness 0 the
> firmware powers the side LED rail down and the gauge can't show.

---

## Recovery

This is fully reversible. Flash NuPhy's official stock firmware from
[nuphy.com/pages/firmwares-for-air75](https://nuphy.com/pages/firmwares-for-air75)
(or their [QMK firmwares](https://nuphy.com/pages/qmk-firmwares)) the same way,
and the keyboard is back to factory. Pressing **Fn + side-mode** exits the gauge
without re-flashing.
