# Carrier pin map — LabSC oven controller

Dual-socket carrier board. It accepts **either** an ESP32-C6 mini **or** a WeAct
BlackPill F411CE, in overlapped 2.54 mm socket rows, and the same firmware image
set drives both. Every net therefore lands on **both** sockets.

The assignment below is a **routing result**, derived from the real footprint
geometry to minimise crossings on a 2-layer board — not a preference. Changing
any single line here has knock-on effects; read *Design rules* before editing.

---

## 1. How the sockets nest

Row spacings differ (C6 = 22.86 mm, BlackPill = 15.24 mm), so the two headers
cannot alternate evenly. Nesting them concentrically is better anyway:

```
C6-left ▏ BP-left ┊┊┊┊┊ BP-right ▏ C6-right
 −3.81     0.00   ┊┊┊┊┊  15.24      19.05     (mm, BlackPill pad 1 at origin)
        3.81  ←  15.24 free  →  3.81
```

| Item | Value |
|---|---|
| ESP32-C6 footprint placement | **(X −1.27, Y +10.16), rotation 0** |
| C6 row offset from its BlackPill partner row | **3.81 mm outboard** |
| Y offset | **5 pitches** (12.70 mm) |
| Free centre channel | **15.24 mm** |

Consequences:

- A shared net is **one straight 3.81 mm stub** between two adjacent pads.
- Only the outer (C6) pad ever escapes, and it escapes **outward into open
  board** — no track threads between pads.
- The Y offset (5 pitches) is chosen so the **left column** works out: SPI1's
  PB3/PB4/PB5 land on three clean C6 GPIOs, PB8/PB9 get usable partners, and the
  C6's unusable D12/D13 (native USB) fall harmlessly onto the BlackPill's power
  pins. **There is no free power adjacency** — the C6 runs GND-top / 5V-bottom on
  both rows while the BlackPill has right-side power at the *top* and left-side at
  the *bottom*, so they cannot align. Power is routed deliberately (§7).

### Why the Y offset is 5 pitches

Swept exhaustively against the corrected BlackPill order, not assumed. Hard
constraints: SPI1's PB3/PB4/PB5 must all land on clean C6 GPIOs, USART2's
PA2/PA3 likewise, and D8 stays reserved (§6.1).

| k | usable pairs | SPI1 trio | USART2 | |
|---|---|---|---|---|
| 0 | 16 | PB3→D10 PB4→D11 | PA3→D18 | **broken** |
| 1 | 17 | PB4→D10 PB5→D11 | PA3→D19 PA2→D18 | **broken** |
| 2 | 18 | PB3→D1 PB5→D10 | PA3→D20 PA2→D19 | **broken** |
| 3 | 18 | PB3→D0 PB4→D1 | PA3→D21 PA2→D20 | **broken** |
| 4 | **18** | PB3→D7 PB4→D0 PB5→D1 | PA3→D22 PA2→D21 | viable |
| **5** | 17 | PB3→D6 PB4→D7 PB5→D0 | PA3→D23 PA2→D22 | **chosen** |

k = 0–3 split the SPI trio across dead pairs and are unusable at any price.

k = 4 yields one more pair, but its left column is exactly 8 slots for 8 nets and
the topmost is **PA11 — the BlackPill's USB D−**. Taking it means two signals on
the USB data lines of a board that gets USB plugged in routinely for debug and
power, and it also costs PB9. k = 5 needs only PA12 (USB D+), which is
unavoidable either way, and keeps PB9 usable. One spare pair is not worth the
second USB pin.

`b` = socket row index counted from the BlackPill's USB-C end, `y = 2.54·b`.

---

## 2. Master pin table

### 2.1 Left rows — RF, thermocouples, SPI

| b | y (mm) | BlackPill | ESP32-C6 | Net | Notes |
|---|---|---|---|---|---|
| 0 | 0.00 | PB12 | — | **LED1** | BlackPill-only, see §6.1 |
| 1 | 2.54 | PB13 | — | **LED2** | BlackPill-only, see §6.1 |
| 2 | 5.08 | PB14 | — | **LED3** | BlackPill-only, see §6.1 |
| 3 | 7.62 | PB15 | — | **LED4** | BlackPill-only, see §6.1 |
| 4 | 10.16 | PA8 | — | *NC* | |
| 5 | 12.70 | PA9 | GND | *dead pair* | |
| 6 | 15.24 | PA10 | 3V3 | *dead pair* | C6 3V3 source anchor |
| 7 | 17.78 | PA11 | RST | *dead pair* | |
| 8 | 20.32 | PA12 | D4 | **TC1_CS** | MAX6675 #1, `cs-gpios` reg 1 |
| 9 | 22.86 | PA15 | D5 | **LORA_NSS** | `cs-gpios` reg 0 |
| 10 | 25.40 | PB3 | D6 | **SPI_SCK** | |
| 11 | 27.94 | PB4 | D7 | **SPI_MISO** | |
| 12 | 30.48 | PB5 | D0 | **SPI_MOSI** | |
| 13 | 33.02 | PB6 | D1 | **LORA_NRESET** | active low |
| 14 | 35.56 | PB7 | D8 | *reserved — leave NC* | **deliberately unrouted** so the C6's onboard RGB LED stays usable, see §6.1 |
| 15 | 38.10 | PB8 | D10 | **LORA_BUSY** | polled every transaction |
| 16 | 40.64 | PB9 | D11 | **LORA_DIO9** | IRQ, pull-down |
| 17 | 43.18 | 5V | D12 | *dead pair* | D12 = USB D− |
| 18 | 45.72 | GND | D13 | *dead pair* | D13 = USB D+ |
| 19 | 48.26 | 3V3 | 5V | *dead pair* | ⚠ **do not connect** — 3V3 vs 5V |

### 2.2 Right rows — UART, field I/O, power

Derived from `Kicad-STM32/Symbols/YAAJ_WeAct_BlackPill_Part_Like.kicad_sym`
paired with the `YAAJ_WeAct_BlackPill_2` footprint — **not** from a remembered
pinout. On this board the two power triplets sit at **opposite ends**: left-hand
power at the bottom (b17–b19), right-hand power at the top (b0–b2).

| b | y (mm) | BlackPill | ESP32-C6 | Net | Notes |
|---|---|---|---|---|---|
| 0 | 0.00 | 5V | — | *BP-only* | right-hand power group is at the **top** |
| 1 | 2.54 | GND | — | *BP-only* | |
| 2 | 5.08 | 3V3 | — | *BP-only* | |
| 3 | 7.62 | PB10 | — | *NC* | BlackPill-only spare |
| 4 | 10.16 | PB2 | — | *NC* | BOOT1 — outside the C6 span, so naturally unused |
| 5 | 12.70 | PB1 | GND | *dead pair* | |
| 6 | 15.24 | PB0 | D2 | **TC2_CS** | MAX6675 #2, `cs-gpios` reg 2 |
| 7 | 17.78 | PA7 | D3 | **OPTO_IN1** | contactor dry contact |
| 8 | 20.32 | PA6 | TX (GPIO16) | *spare* | ⚠ ROM drives GPIO16 as UART TX at boot — **output-only**, never an opto input |
| 9 | 22.86 | PA5 | RX (GPIO17) | **OPTO_IN2** | RFU; GPIO17 is ROM RX, an input at boot — safe |
| 10 | 25.40 | PA4 | D15 | **OPTO_OUT2** | RFU output, active-low sink — see §5.2 |
| 11 | 27.94 | PA3 | D23 | **UART_RX** | USART2 |
| 12 | 30.48 | PA2 | D22 | **UART_TX** | USART2 (console) |
| 13 | 33.02 | PA1 | D21 | **KEEPALIVE_555** | software-toggled pulse |
| 14 | 35.56 | PA0 | D20 | **HW_WDT_KICK** | software-toggled pulse |
| 15 | 38.10 | RES | D19 | *dead pair* | BlackPill NRST; no global reset net |
| 16 | 40.64 | PC15 | D18 | *dead pair* | **LSE crystal** — PC14/PC15 are populated |
| 17 | 43.18 | PC14 | D9 | *dead pair* | **LSE crystal**, and D9 is strapping |
| 18 | 45.72 | PC13 | GND | *dead pair* | PC13 = BlackPill onboard LED |
| 19 | 48.26 | VBat | 5V | *dead pair* | ⚠ **do not connect** — VBat is a ≤3.6 V backup input |

**The UART is now two straight stubs.** USART2 is fixed to PA2/PA3, which land at
b12/b11 opposite D22/D23 — both clean C6 GPIOs. Zephyr's `uart0` is matrix-routable,
so it is simply assigned there. No diagonals, no vias, and **every shared net on
this board is now a plain 3.81 mm pair.**

⚠ Two adjacent-pad pairs must **never** be connected: b19-right (`VBat` ↔ C6 `5V`)
and b19-left (`3V3` ↔ C6 `5V`). Both are a 3.81 mm gap between incompatible rails.

---

## 3. Shared SPI bus

One bus, three devices, one chip select each, indexed by the child node's `reg`.
Both MAX6675s are read-only (SCK + SO + CS, no MOSI) and tri-state SO when
deselected, so they coexist with the LR1121. Zephyr sets clock and mode per
device.

| `reg` | Device | CS (C6) | CS (STM32) | Clock | DT node |
|---|---|---|---|---|---|
| 0 | LR1121 (Core1121-XF) | D5 | PA15 | 16 MHz | `lora_lr1121` |
| 1 | MAX6675 #1 — hot zone | D4 | PA12 | 4 MHz | `tc0` |
| 2 | MAX6675 #2 — cold zone | D2 | PB0 | 4 MHz | `tc1` |

**Neither thermocouple sits on a strapping pin.** TC2_CS was moved off D8 (see
§6.1): a safety-relevant temperature reading has no business on the most
compromised pin on the board, and freeing D8 is also what makes the C6's RGB LED
usable. Both CS lines are now on clean, pull-up-tolerant pins.

A third MAX6675 (safety reading) was considered and **dropped** — the carrier ran
out of pins.

MAX6675 modules use right-angle 1×5 headers, pin order **`GND, VCC, SCK, CS, SO`**.
Put **both headers on the top edge** — #1 toward the left, #2 toward the centre —
and run SCK + MISO as a short bus along that edge, tapping each header off it.
Rows b0–b4 carry no routing, so TC1_CS reaches #1 up the left side and TC2_CS
reaches #2 straight up through that dead zone — TC2_CS is at b6, the topmost
usable right-hand row, precisely so that run is short. **No crossings, no vias.**

---

## 4. 12 V field I/O (isolated)

No relays on this board. Screw terminals are **open-drain outputs** (from the
optocoupler transistor) and **dry-contact inputs**.

| Channel | Dir | C6 | STM32 | Sense | Purpose |
|---|---|---|---|---|---|
| OUT1 | out | D20 | PA0 | pulse | hardware watchdog kick → cuts mains to oven |
| OUT2 | out | D15 | PA4 | **active low** | RFU |
| IN1 | in | D3 | PA7 | **active low** | contactor dry contact — responding / welded detection |
| IN2 | in | RX (GPIO17) | PA5 | **active low** | RFU |

Plus, on the logic side and **not** a field terminal:

| Net | C6 | STM32 | Purpose |
|---|---|---|---|
| KEEPALIVE_555 | D21 | PA1 | retriggers the 555 monostable gating the power circuit |

**Both inputs are active low with an external pull-up**, so a failed or unpowered
optocoupler reads as *asserted*. A welded-contactor condition on IN1 therefore
fails toward the alarm state rather than being silently missed, and IN2 inherits
the same property should it ever take on a safety role.

Both inputs are plain geometric pairs on clean pins — no split nets, no vias.
IN2 sits on GPIO17 (the C6's ROM UART RX), which is an *input* during boot and so
takes the external pull-up harmlessly. **Do not move it to GPIO16**: the ROM
drives that pin as UART TX at every boot, and a phototransistor there would
contend with it.

---

## 5. Design rules — read before changing anything

### 5.1 Why these pins

- **SPI1 uses its PB3/PB4/PB5 alternate mapping**, not the PA5/PA6/PA7 default.
  This is the single change that makes the fanout crossing-free: all three bus
  signals sit consecutively on one socket row. The default mapping straddles both
  rows and would force SCK across the whole board.
  Verified in Zephyr: `spi1_sck_pb3`, `spi1_miso_pb4`, `spi1_mosi_pb5`.
- **The STM32 is the anchor.** Its SPI/USART pins are fixed alternate functions;
  the ESP32-C6's GPIO matrix places SPI2 on *any* GPIO. The constrained side
  picks first and the C6 follows — the opposite of the intuitive ordering.
- **Console is USART2 (PA2/PA3)**, not USART1. PA9/PA10 sit at rows b5/b6 where
  the C6's neighbours are GND and 3V3.

### 5.2 ESP32-C6 boot straps

| Pin | Role | How it is handled |
|---|---|---|
| D8 | strapping + onboard RGB LED | **left NC on the carrier.** Reserved for the module's WS2812, see §6.1 |
| D9 | strapping | dead pair, left **NC** |
| D15 | JTAG source select | carries **OPTO_OUT2**, active-low sink, **external 10 k pull-up to 3V3 mandatory** |
| D12 / D13 | native USB (USB-Serial-JTAG) | never used |

⚠ **D15 is the most constrained pin on the board.** It is only *sampled at
reset*, so it is usable afterwards — but if it is low at reset the C6 switches
JTAG to the pin-JTAG group **GPIO4–GPIO7**, which would seize TC1_CS, NSS, SCK
and MISO and kill the entire SPI bus. Hence: active-low drive only (Hi-Z = high =
inactive), external pull-up, and never an input that a field contact could pull
low.

Keeping D15 high is also what makes **D4–D7 safe as ordinary GPIO**, since we
debug over USB-Serial-JTAG.

### 5.3 STM32 pin caveats

| Pin | Caveat | Handling |
|---|---|---|
| PA15 / PB3 / PB4 | JTAG (JTDI / JTDO / NJTRST) with reset pull-ups | harmless with SWD-only debug; PA15's pull-up usefully holds NSS deasserted before firmware runs |
| PA12 | USB D+, 1.5 k pull-up on the BlackPill | fine for a push-pull CS, which also wants to idle high |
| PB2 | BOOT1, has a board pull-down | **Not reachable** — it sits at b4-right, outside the C6's span, so it is unused by construction. Do not route to it: an external pull-up would fight the ~10 k pull-down and break DFU entry. |
| PC13 / PC14 / PC15 | PC13 = onboard LED (weak RTC pin); **PC14/PC15 carry the 32.768 kHz LSE crystal, which is populated on this board** | all three unusable; b16–b18 right are dead pairs |
| VBat | ≤3.6 V RTC backup input | b19-right, sits 3.81 mm from the C6's 5V pad. ⚠ **never connect** |

### 5.4 Failsafe

`KEEPALIVE_555` and `HW_WDT_KICK` **must be toggled from software** — never
hardware PWM/LEDC. LEDC keeps running autonomously through a CPU hang and would
keep the 555 retriggered and the watchdog fed, defeating the entire failsafe.
Gate both on an application-liveness flag; a bare `k_timer` keeps firing even if
the app thread deadlocks. Both pins are Hi-Z at reset until firmware drives them,
so size the external timeouts to survive boot.

Architecture is **de-energize-to-trip**, two independent layers, and there is
**no global reset net** — the watchdog cuts mains and a dead processor stays dead
until a human intervenes. Both `RST` pins are deliberately NC.

---

## 6. Budget — the board is full

| | count |
|---|---|
| C6 module GPIO pins (D0–D13, D15, D18–D23) | 21 |
| − D12 / D13 — native USB (USB-Serial-JTAG) | −2 |
| − D8 — reserved NC for the onboard RGB LED (§6.1) | −1 |
| − D9, D18, D19 — dead pairs (partner is PC14 / PC15 / NRST) | −3 |
| **General C6 pins available for shared nets** | **15** |
| Allocated | **15** |
| **Free** | **0** |

**Every shared net is a true geometric pair** — one 3.81 mm stub each, no split
nets, no diagonals, no vias. The one spare left is b8-right (PA6 ↔ GPIO16), and it
is **output-only**: the C6 ROM drives GPIO16 as UART TX at every boot.

**The ESP32-C6 is the binding constraint on the entire board.** Every remaining
position is either used, a dead pair, or a USB pin. There is no spare shared
GPIO left.

### There are no "STM-only" pins

The BlackPill has 40 header positions, the C6 mini has 30, so **10 BlackPill
positions have no C6 neighbour at all** (rows b0–b4, both sides) plus 6 more
whose C6 neighbour is a power or reset pin. All are left **unconnected by rule** —
wiring anything there would create a function the C6 could not perform. The
BlackPill's surplus pins are simply dead weight.

Convenient side effect: rows b0–b4 carry no routing, and that is exactly where
both modules' USB-C connectors point. Keep that end free of tall parts and both
USB ports are accessible with no cutout.

### 6.1 Indicators — the one deliberate exception to parity

Status indication is the **single place where the two targets differ by design**,
and it costs zero shared pairs:

| Target | Indicator | Pins |
|---|---|---|
| BlackPill F411CE | **4 discrete LEDs** | PB12, PB13, PB14, PB15 — rows b0–b3, left |
| nanoESP32-C6 | **onboard addressable RGB** | GPIO8 (D8), on-module |

This is legitimate where the general parity rule is not, because the C6 already
carries its own indicator: neither target loses a *function*, only the form the
indication takes. PB12–PB15 are BlackPill-only positions with no C6 neighbour at
all, so routing four LEDs there consumes nothing the C6 could have used.

Per `nanoESP32C6.pdf`, the C6 module's LED is an **addressable RGB (WS2812-type)
on GPIO8** — not a simple GPIO LED. It needs exclusive, timing-critical ~800 kHz
signalling, so it is usable **only if nothing else is on that pin**. Hence
**row b14-left is left NC**: that reservation is what buys the C6 an indicator,
and it is also what got the safety-relevant TC2_CS off the board's most
compromised pin. Both goals are served by the same decision.

PC13 (the BlackPill's own onboard LED) is left alone — it is at row b1-right, and
it is a weak-drive RTC-domain pin best avoided anyway.

**Firmware consequence:** the LED aliases exist only on the STM32 target. Put the
indicator behind a small per-target shim (`status_led_set(...)`) — `gpio-leds` on
the BlackPill, `led_strip` / WS2812-over-RMT on the C6 — rather than assuming a
common alias.

⚠ Confirm on the physical module that GPIO8's RGB-LED network does not pull the
pin below the strap threshold at reset. The schematic appears to bias it high and
the board demonstrably boots as sold, but this is read from a low-resolution
drawing — worth one meter check.

---

## 7. Board placement summary

| Item | Placement |
|---|---|
| ESP32-C6 footprint | BlackPill origin + **(X −1.27, Y +10.16)**, rot 0 |
| Core1121 (LR1121) | **Y +17.78** relative to BlackPill origin — puts CS / SCLK / RESET on the exact y of rows b9 / b10 / b13 |
| Radioenge modem | Core1121 + **(X +11.43, Y +17.78)**, rot 0 — rows at −6.35 / 0 / +11.43 / +15.24, min gap 3.81 mm |
| MAX6675 ×2 | right-angle 1x5 headers on the **top edge**, SCK+MISO bussed along it |
| Isolated 12 V block | **right edge**: 555, optocouplers, screw terminals |

Floorplan: RF + thermocouples left, MCU sockets centre, isolated 12 V right. The
mirror image costs 9 crossing nets instead of 2.

Estimated inter-socket wiring cost: **~6–8 vias**, plus ~4 for the UART crossing
the centre channel to reach the Radioenge.

### Power

Isolated 12 V → +5 V → the module's `5V` pin → the module's on-board regulator
supplies 3V3 to the logic domain. A jumper opens the DC-DC path for USB-powered
debugging.

- **Both C6 5V pads (b19, left and right) sit next to incompatible rails** —
  BlackPill 3V3 on the left, VBat on the right. They are internally bonded on the
  module, so connect the 5V net at neither: bring 5V in on the **BlackPill's own
  5V pin at b17-left** and reach the C6 via a bottom-layer run. ⚠ Never bridge
  either b19 pair.
- The BlackPill's power appears twice (5V/GND/3V3 at b17–b19 **left** and again at
  b0–b2 **right**); the pins are common on the module, so wire one group and let
  the pour carry the rest.
- ⚠ **Add a Schottky in the DC-DC's +5 V output.** Neither module has an input
  diode, so closing the jumper with USB plugged in backfeeds the USB host.
- 3V3 is generated at different pins depending on which module is fitted
  (C6: b6-left; BlackPill: b19-left and b17-right), so it needs a bottom-layer
  run through the centre channel, ~3–4 vias.

Open SI item: SPI at 16 MHz on 2 layers with a partly fragmented ground return is
the fastest signal present. Keep solid GND pour under the ~14 mm LR1121 runs;
drop to 8 MHz if it misbehaves (no impact at these data rates).

---

## 8. Open items

### Firmware lags this document

The overlays were last re-pinned at commit `f712a69`, **before** §3 and §4 were
settled. Outstanding delta:

| Item | Overlays have | This doc says |
|---|---|---|
| TC2_CS | `D8` / `PB7` | **`D2` / `PB0`** |
| OPTO_OUT2, OPTO_IN1, OPTO_IN2 | absent | §4 |
| LED1–4 (BlackPill only) | absent | §6.1 |
| D8 (b14-left) | used by TC2_CS | **reserved NC** |
| KEEPALIVE_555 | `D21` / `PB1` | `D21` / **`PA1`** |
| HW_WDT_KICK | `D20` / `PB10` | `D20` / **`PA0`** |

Both targets currently build clean, they simply describe the older map. Apply
§2–§4 to `boards/*.overlay` and re-verify with a build of each target.

### KiCad project (`labsc-radioenge-bluepill`) — not yet touched

1. ⚠ **`symbols/YAAJ_BlackPill.kicad_sym` is a BluePill symbol**, not a
   BlackPill. It has `PB11` (absent on the F411CE LQFP48) and lacks `PB2`,
   `PC14`, `PC15`, `VBat`. Paired with the `YAAJ_WeAct_BlackPill_2` footprint it
   will silently mis-map the entire right-hand header. **The replacement already
   exists**: use `Kicad-STM32/Symbols/YAAJ_WeAct_BlackPill_Part_Like.kicad_sym`
   (40 pins, correct F411CE pinout), which is verified consistent with the
   footprint and with the physical board. Switch the schematic over to it and
   retire the old symbol.
2. ⚠ **`LoRaModuleRadioenge.kicad_mod` is parallel-numbered, not U-shaped** —
   pad 1 and pad 16 sit diagonally opposite. Pads 9–16 are unused so that half is
   harmless, but confirm the module's real pin 1 is at the end this footprint
   places it, or the used row (`GND, AT_RX, AT_TX, VCC …`) mirrors and AT_RX/AT_TX
   swap.

### Hardware to verify

- **GPIO8's RGB-LED network must not pull the pin below the strap threshold at
  reset** (§6.1). Read from a low-resolution schematic; worth one meter check.
- Confirm the `ESP32C6-Minimal` symbol matches the module silkscreen, and that
  `D<n>` == `GPIO<n>`.
- Is mains switched on this PCB, or does the 12 V side drive an external
  contactor? Assumed the latter (12 V creepage only). A mains relay on-board
  needs ≥6–8 mm clearance plus a routed slot under the barrier.

### Pre-existing TODOs

- LoRaWAN credentials in `boards/user_keys.overlay` (all zero).
- `tx-power-cfg-*`, `rssi-calibration-*`, `tx-dbm-to-ua-*` are LR1121-MB1
  reference values — recalibrate for the Core1121-XF BOM.
- Application firmware for the thermocouple reads and the liveness-gated
  keep-alive / watchdog pulses is still the stock periodical-uplink sample.
