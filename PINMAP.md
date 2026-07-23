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
the topmost is **PA11 — the BlackPill's USB D−**. k = 5 needs only PA12 (USB D+)
and keeps PB9 usable.

**Both USB pins are now banned outright (§5.3)**, which settles it in k = 5's
favour rather than unsettling it: at k = 5 the single offender (PA12 / TC1_CS)
escapes with a ~10 mm run to PA8 at b4, because a chip select does not have to
reach the modem. At k = 4 the offender is PA11 *and* PB9 is lost as well.

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
| 4 | 10.16 | PA8 | — | **TC1_CS** | MAX6675 #1, `cs-gpios` reg 1 — C6 end is D4 at b8, see below |
| 5 | 12.70 | PA9 | GND | *dead pair* | |
| 6 | 15.24 | PA10 | 3V3 | *dead pair* | C6 3V3 source anchor |
| 7 | 17.78 | PA11 | RST | *dead pair* | ⚠ **PA11 = USB D− — banned** (§5.3) |
| 8 | 20.32 | PA12 | D4 → *PA8* | **split row** | ⚠ **PA12 = USB D+ — banned** (§5.3). C6 end = **TC1_CS**, routed up to PA8 at b4 |
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
| 8 | 20.32 | PA6 → *D22* | TX (GPIO16) ← *PA2* | **split row** | BP end = *spare*; C6 end = **UART_TX** (module pad 27) |
| 9 | 22.86 | PA5 → *D23* | RX (GPIO17) ← *PA3* | **split row** | BP end = **OPTO_IN2**; C6 end = **UART_RX** (module pad 26) |
| 10 | 25.40 | PA4 | D15 | **OPTO_OUT2** | RFU output, active-low sink — see §5.2 |
| 11 | 27.94 | PA3 → *GPIO17* | D23 ← *PA5* | **split row** | BP end = **UART_RX**; C6 end = **OPTO_IN2** |
| 12 | 30.48 | PA2 → *GPIO16* | D22 ← *PA6* | **split row** | BP end = **UART_TX**; C6 end = *spare* |
| 13 | 33.02 | PA1 | D21 | **KEEPALIVE_555** | software-toggled pulse |
| 14 | 35.56 | PA0 | D20 | **HW_WDT_KICK** | software-toggled pulse |
| 15 | 38.10 | RES | D19 | *dead pair* | BlackPill NRST; no global reset net |
| 16 | 40.64 | PC15 | D18 | *dead pair* | **LSE crystal** — PC14/PC15 are populated |
| 17 | 43.18 | PC14 | D9 | *dead pair* | **LSE crystal**, and D9 is strapping |
| 18 | 45.72 | PC13 | GND | *dead pair* | PC13 = BlackPill onboard LED |
| 19 | 48.26 | VBat | 5V | *dead pair* | ⚠ **do not connect** — VBat is a ≤3.6 V backup input |

### The UART sits on the C6's bootloader pair (rows b8–b12 are split)

The C6 console is **not** remapped: it stays on the board-default / ROM pair
**TX = GPIO16 (module pad 27), RX = GPIO17 (pad 26)**, so the serial-download
bootloader log and the Zephyr console come out of the same two carrier pads and
one FTDI hookup covers both. That was an explicit trade: an earlier revision
moved Zephyr's `uart0` to GPIO22/23 to buy two straight stubs, at the cost of the
bootloader talking on different pads than the application.

The BlackPill end cannot follow — USART2 is fixed to PA2/PA3 (b12/b11), and no
other USART maps onto PA5/PA6. So four rows in this block are **split**: the
BlackPill pad and the C6 pad at the same `b` belong to *different* nets.

| Net | BlackPill pad | C6 pad | Δy |
|---|---|---|---|
| UART_TX | PA2 (b12) | GPIO16 (b8) | 10.16 mm |
| UART_RX | PA3 (b11) | GPIO17 (b9) | 5.08 mm |
| OPTO_IN2 | PA5 (b9) | D23 (b11) | 5.08 mm |
| spare | PA6 (b8) | D22 (b12) | 10.16 mm |

The two UART runs nest and do not cross each other; OPTO_IN2 and the spare are
the mirror pair and cross them. **All four pads at each end are through-hole, so
a run can drop to the bottom layer at the pad itself — these cost layer changes,
not vias.** The spare carries no net until it is used, so in practice only three
runs share the channel. Every other shared net on the board is still a plain
3.81 mm stub.

Side benefit: the spare is no longer output-only. It used to be PA6 ↔ GPIO16,
which the ROM drives as TX at every boot; it is now PA6 ↔ D22, both clean pins.

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
| 1 | MAX6675 #1 — hot zone | D4 | PA8 | 4 MHz | `tc0` |
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
| IN2 | in | D23 | PA5 | **active low** | RFU |

Plus, on the logic side and **not** a field terminal:

| Net | C6 | STM32 | Purpose |
|---|---|---|---|
| KEEPALIVE_555 | D21 | PA1 | retriggers the 555 monostable gating the power circuit |

**Both inputs are active low with an external pull-up**, so a failed or unpowered
optocoupler reads as *asserted*. A welded-contactor condition on IN1 therefore
fails toward the alarm state rather than being silently missed, and IN2 inherits
the same property should it ever take on a safety role.

Both inputs are on clean, non-strapping pins. IN1 is a plain 3.81 mm pair; IN2 is
one of the four split rows in §2.2 (PA5 at b9, D23 at b11) because the C6 console
occupies GPIO16/17. **Neither input may ever be placed on GPIO16**: the ROM drives
it as UART TX at every boot and would contend with the phototransistor.

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
| **PA11 / PA12** | **USB D− / D+** — D+ carries a 1.5 k pull-up | ⚠ **BANNED from carrier nets.** The BlackPill's USB port is used routinely for flashing and power, so anything on these two contends with a plugged cable. `TC1_CS` used to sit on PA12 and was moved to **PA8** (b4-left); its C6 end stays D4 at b8-left, making that row split and the net a ~10 mm run up the left column through dead space. Nothing else may be placed here. |
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
| Allocated | **14** |
| **Free** | **1** — D22 |

GPIO16/17 are not in that count: they are the ROM UART pair and carry the console
on both sockets.

**Every shared net except the four in §2.2 is a true geometric pair** — one
3.81 mm stub, no diagonal, no layer change. The one spare left is **PA6 (b8-right)
↔ D22 (b12-right)**, and unlike the previous revision's spare it is *not*
output-only — both ends are clean pins.

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
| Core1121 (LR1121) | **bottom-left**. **Y +17.78** relative to BlackPill origin — puts CS / SCLK / RESET on the exact y of rows b9 / b10 / b13. X not yet fixed |
| Radioenge modem | **top-left**, free-standing. X/Y not yet fixed |
| MAX6675 ×2 | right-angle 1x5 headers on the **top edge**, SCK+MISO bussed along it |
| Isolated 12 V block | **right edge**: 555, optocouplers, screw terminals |

Floorplan: RF + thermocouples left, MCU sockets centre, isolated 12 V right.
The mirror image costs 9 crossing nets instead of 2.

**The two modems are no longer nested.** An earlier revision overlapped them
(Radioenge = Core1121 + (X +11.43, Y +17.78), four columns at −6.35 / 0 / +11.43
/ +15.24) to fit both in 21.59 mm instead of ~43 mm. They now sit at separate
sites, top-left and bottom-left. This costs board area, and both modems can now
be populated at once — though only one is ever used.

Estimated inter-socket wiring cost: **~6–8 vias**, plus ~4 for the console UART
crossing the centre channel to reach the Radioenge — that crossing is unchanged
by the move, since the console pair (C6 GPIO16/17, BP PA2/PA3) is on the **right**
column and the Radioenge is on the left.

Edge budget: top = both USB-C plus two MAX6675 headers; left = both modem
sites; right = isolated 12 V.

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

### Firmware is in sync

Both overlays implement §2–§4 as of this commit, verified against the generated
devicetree (not just a successful link):

| Target | Build | Footprint |
|---|---|---|
| `esp32c6_devkitc/esp32c6/hpcore` | clean | 426 KB flash / 106 KB SRAM |
| `blackpill_f411ce` | clean | 219 KB flash / 38 KB SRAM (42 % / 29 %) |

Devicetree nodes and aliases now exposed:

| Alias | C6 | BlackPill |
|---|---|---|
| `tc0` / `tc1` | GPIO4 / GPIO2 | **PA8** / PB0 |
| `keepalive-out` / `hw-wdt-out` | GPIO21 / GPIO20 | PA1 / PA0 |
| `opto-out2` | GPIO15 | PA4 |
| `opto-in1` | GPIO3 | PA7 |
| `expi2c` / `expuart` / `exp-int` | `i2c0` / `uart1` / GPIO23 | `i2c1` / `usart1` / PA8 |
| `led0`…`led3` | *(onboard RGB — not a carrier net)* | PB12…PB15 |
| console | `uart0`, GPIO16/17 (board default) | `usart2`, PA2/PA3 |

`opto_inputs` uses the `gpio-keys` binding purely so devicetree validates; no
input driver is enabled. Read the pins with `GPIO_DT_SPEC_GET(DT_ALIAS(opto_in1),
gpios)` as ordinary GPIOs.

**Still the stock periodical-uplink sample.** The application does not yet read
the thermocouples, poll the contactor feedback, or toggle the liveness-gated
keep-alive / watchdog pulses. That is the next piece of work; the devicetree
exposes everything it needs.

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
   pad 1 sits at (0, 0) and pad 9 directly beside it at (−17.78, 0), so pad 1 and
   pad 16 end up diagonally opposite. Confirm the module's real pin 1 is at the
   end this footprint places it, or **both** rows mirror: `AT_RX`/`AT_TX` swap on
   row A and the whole expansion pinout reverses on row B.
   Row B (pads 9–16, GPIO2–GPIO9) is spare, so only row A is at risk.
3. The modem sites are **no longer nested** (§7): Radioenge top-left, Core1121
   bottom-left. The old overlap placement in earlier revisions of this document
   is obsolete.
4. The schematic carries distinct `UART_AT_RX` / `UART_AT_TX` net labels, but
   §2.2 has no dedicated AT UART — the Radioenge shares the console UART, which
   is why §9 exists. Reconcile the schematic to that, or decide otherwise before
   routing the modem site.

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

---


## 9. AT-mode builds (Radioenge fitted)

There is exactly **one** UART both sockets can reach — BlackPill `usart2` on
PA2/PA3, ESP32-C6 `uart0` on GPIO16/17 (§2.2) — and the Radioenge's AT_RX/AT_TX
hang off it. It is therefore *both* the debug console and the AT port, and those
two cannot coexist: a log backend writing to that line injects bytes into the AT
stream, and a console reading it tries to interpret AT responses.

**When a Radioenge is fitted, build with the `at_modem` snippet:**

```
west build -S at_modem -b blackpill_f411ce .
west build -S at_modem -b esp32c6_devkitc/esp32c6/hpcore .
```

| Symbol | default | `-S at_modem` |
|---|---|---|
| `CONFIG_SHELL` | n | n |
| `CONFIG_UART_CONSOLE` | y | **n** |
| `CONFIG_CONSOLE` | y | **n** |
| `CONFIG_STDOUT_CONSOLE` | y | **n** |
| `CONFIG_LOG_BACKEND_UART` | y | **n** |
| `CONFIG_LOG` | y | y (compiled, no UART backend) |

`CONFIG_SHELL` has never been enabled on this project and must stay off — an
interactive shell on the AT line is actively harmful, not merely noisy. The
snippet pins it to `n` so a later `prj.conf` edit cannot switch it on behind
this constraint.

Use the alias **`atuart`** to get the port from application code; it resolves to
`usart2` on the BlackPill and `uart0` on the C6, so modem code is
target-independent.

Footprints: BlackPill 215984 B / 38008 B with `at_modem` vs 218544 B / 38136 B
without; C6 426052 B vs 426084 B.

Note this Zephyr's `SNIPPET_ROOT` defaults to `${ZEPHYR_BASE}` alone, so
`CMakeLists.txt` appends the application directory — without that the snippet is
not found.

---

## 10. Retired ideas

Kept so they are not re-proposed from scratch.

### Expansion connectors (dropped)

A two-connector I²C + UART + INT expansion port for an industrial daughterboard
(4–20 mA I/O, RS485/Modbus, CAN). Fully designed, implemented in firmware, and
then **dropped: it could only be fed by pins that are bad.**

The board has no slack. Reaching five expansion signals on the BlackPill forced
`LORA_BUSY` off PB8 onto **PA11**, and the pre-existing `TC1_CS` already sat on
**PA12** — the two USB data lines. Spending the USB pins to gain a connector is
the wrong trade on a board whose USB port is used routinely for flashing and
power. Dropping the port also returned `OPTO_IN2` to the field side (2 in / 2 out
again) and freed D18/D19/D22/D23 back to spare.

What was learned and is still true:

- Each MCU's free pads sit on **opposite columns** — the C6's spares are all on
  its right column, the BlackPill's on its left — so no single shared connector
  can serve both sockets without five full-width nets.
- **PB7 is the only free SDA-capable pin on the F411**, so hardware I²C there
  always costs a LoRa signal relocation.
- The C6's ADC1 is GPIO0–GPIO6 and all seven are used, so **no raw analog input
  is available on this carrier at all**.
- The F411 has **no CAN**; the C6 has TWAI. CAN can never be symmetric here.
- A firmware tri-state contract (peripheral nodes `disabled` → pinctrl never
  applied → pins stay Hi-Z) protects a pad facing a foreign GPIO, but **cannot
  protect a pad tied to a power rail**.

If an expansion port is ever revisited, the honest starting point is that it
needs a **third** MCU option or a bigger module — not a cleverer assignment of
what is left on this one.
