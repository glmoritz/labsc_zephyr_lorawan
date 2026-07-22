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
- The Y offset is not arbitrary: it is the only one that lands `GND↔GND` and
  `5V↔5V` as direct adjacent pairs (rows b18 / b19).

`b` = socket row index counted from the BlackPill's USB-C end, `y = 2.54·b`.

---

## 2. Master pin table

### 2.1 Left rows — RF, thermocouples, SPI

| b | y (mm) | BlackPill | ESP32-C6 | Net | Notes |
|---|---|---|---|---|---|
| 0 | 0.00 | PB12 | — | *NC* | no C6 neighbour |
| 1 | 2.54 | PB13 | — | *NC* | |
| 2 | 5.08 | PB14 | — | *NC* | |
| 3 | 7.62 | PB15 | — | *NC* | |
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
| 14 | 35.56 | PB7 | D8 | **TC2_CS** | MAX6675 #2, `cs-gpios` reg 2 |
| 15 | 38.10 | PB8 | D10 | **LORA_BUSY** | polled every transaction |
| 16 | 40.64 | PB9 | D11 | **LORA_DIO9** | IRQ, pull-down |
| 17 | 43.18 | 5V | D12 | *dead pair* | D12 = USB D− |
| 18 | 45.72 | GND | D13 | *dead pair* | D13 = USB D+ |
| 19 | 48.26 | 3V3 | 5V | *dead pair* | ⚠ **do not connect** — 3V3 vs 5V |

### 2.2 Right rows — UART, field I/O, power

| b | y (mm) | BlackPill | ESP32-C6 | Net | Notes |
|---|---|---|---|---|---|
| 0 | 0.00 | VB | — | *NC* | no C6 neighbour |
| 1 | 2.54 | PC13 | — | *NC* | BlackPill onboard LED lives here |
| 2 | 5.08 | PC14 | — | *NC* | |
| 3 | 7.62 | PC15 | — | *NC* | |
| 4 | 10.16 | PA0 | — | *NC* | |
| 5 | 12.70 | PA1 | GND | *dead pair* | |
| 6 | 15.24 | PA2 | D2 | **UART_TX** | STM32 end (USART2) |
| 7 | 17.78 | PA3 | D3 | **UART_RX** | STM32 end (USART2) |
| 8 | 20.32 | PA4 | TX (GPIO16) | **UART_TX** | C6 end (uart0) |
| 9 | 22.86 | PA5 | RX (GPIO17) | **UART_RX** | C6 end (uart0) |
| 10 | 25.40 | PA6 | D15 | **OPTO_OUT2** | RFU output — see §5.2 |
| 11 | 27.94 | PA7 | D23 | **OPTO_IN1** | contactor dry contact |
| 12 | 30.48 | PB0 | D22 | **OPTO_IN2** | RFU input |
| 13 | 33.02 | PB1 | D21 | **KEEPALIVE_555** | software-toggled pulse |
| 14 | 35.56 | PB10 | D20 | **HW_WDT_KICK** | software-toggled pulse |
| 15 | 38.10 | PB2 | D19 | **STATUS_LED** | **active high** — see §6.1 |
| 16 | 40.64 | RST | D18 | *dead pair* | no global reset net |
| 17 | 43.18 | 3V3 | D9 | *dead pair* | D9 strapping, leave NC |
| 18 | 45.72 | GND | GND | **GND** | direct adjacency ✓ |
| 19 | 48.26 | 5V | 5V | **5V** | direct adjacency ✓ |

UART occupies four positions but carries two nets: USART2 is fixed to PA2/PA3
while the C6's ROM console is fixed to GPIO16/17. Both shift by +2 in the same
direction, so they are **two parallel diagonals — no crossing, no via.**

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
| 2 | MAX6675 #2 — cold zone | D8 | PB7 | 4 MHz | `tc1` |

A third MAX6675 (safety reading) was considered and **dropped** — the carrier ran
out of pins. If it is needed later, it costs one shared pair, and the only way to
get one back is to depopulate the status LED (§6.1).

MAX6675 modules use right-angle 1×5 headers, pin order **`GND, VCC, SCK, CS, SO`**.

---

## 4. 12 V field I/O (isolated)

No relays on this board. Screw terminals are **open-drain outputs** (from the
optocoupler transistor) and **dry-contact inputs**.

| Channel | Dir | C6 | STM32 | Sense | Purpose |
|---|---|---|---|---|---|
| OUT1 | out | D20 | PB10 | pulse | hardware watchdog kick → cuts mains to oven |
| OUT2 | out | D15 | PA6 | **active low** | RFU |
| IN1 | in | D23 | PA7 | **active low** | contactor dry contact — responding / welded detection |
| IN2 | in | D22 | PB0 | **active low** | RFU |

Plus, on the logic side and **not** a field terminal:

| Net | C6 | STM32 | Purpose |
|---|---|---|---|
| KEEPALIVE_555 | D21 | PB1 | retriggers the 555 monostable gating the power circuit |

Both inputs are **active low with an external pull-up**: a failed or unpowered
optocoupler reads as *asserted*, so a welded-contactor condition fails toward the
alarm state rather than being silently missed.

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
| D8 | strapping | carries **TC2_CS** — a host-driven output that idles high, which is what the strap wants. Never a device-driven input. |
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
| PB2 | BOOT1, has a board pull-down | carries **STATUS_LED**, active high — the pull-down is exactly what an active-high LED wants (LED off and BOOT1 = 0 at reset). Never put a pulled-**up** net here: it would fight the pull-down and break DFU entry. |

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
| C6 module GPIO-ish pins | 21 |
| − D12/D13 (native USB) | −2 |
| − D9, D18 (dead pairs: BlackPill partner is 3V3 / RST) | −2 |
| **Usable shared pairs** | **16 + 1 UART pair** |
| Allocated | **16 + UART** |
| **Free** | **0** |

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

### 6.1 Status LED

The four status LEDs originally wanted were **dropped** — there is no pin budget.
One carrier LED survives, on the pair freed by dropping MAX6675 #3.

**Why a carrier LED at all, rather than the modules' onboard ones:** neither
onboard LED can serve as a portable status indicator.

| Module | Onboard LED | Usable? |
|---|---|---|
| BlackPill F411CE | plain LED on **PC13** | works, but PC13 is at right-row b1 — a position with **no C6 neighbour**, so it is STM-only and breaks parity |
| nanoESP32-C6 v1.0 | **addressable RGB (WS2812-type) on GPIO8** | no — GPIO8 carries TC2_CS |

Per `nanoESP32C6.pdf`, the C6 module's LED is an **addressable RGB** driven from
GPIO8, not a simple GPIO LED. It needs exclusive, timing-critical ~800 kHz
signalling, so sharing the pin with a chip select rules it out entirely. In
practice it will flash arbitrary colours whenever MAX6675 #2 is read — cosmetic
and harmless, but it is not an indicator you can control.

So `STATUS_LED` on **PB2 ↔ D19** (row b15-right) gives both boards one identical,
independently controlled indicator. **Active high**, which is exactly what PB2's
BOOT1 pull-down wants: LED off and BOOT1 = 0 at reset.

> **Deferral option:** fit the LED and its series resistor as footprints but leave
> them DNP if you would rather bank the pin. Depopulating them frees one shared
> pair — the only route back to a third MAX6675 or any future peripheral.

⚠ Confirm on the physical module that GPIO8's RGB-LED network does not pull the
pin below the strap threshold at reset. The schematic appears to bias it high and
the board demonstrably boots as sold, but this is read from a low-resolution
drawing — worth one meter check, because GPIO8 low at reset is a boot failure.

---

## 7. Board placement summary

| Item | Placement |
|---|---|
| ESP32-C6 footprint | BlackPill origin + **(X −1.27, Y +10.16)**, rot 0 |
| Core1121 (LR1121) | **Y +17.78** relative to BlackPill origin — puts CS / SCLK / RESET on the exact y of rows b9 / b10 / b13 |
| Radioenge modem | Core1121 + **(X +11.43, Y +17.78)**, rot 0 — rows at −6.35 / 0 / +11.43 / +15.24, min gap 3.81 mm |
| MAX6675 ×2 | right-angle headers on the **top edge** (carries no routing) |
| Isolated 12 V block | **right edge**: 555, optocouplers, screw terminals |

Floorplan: RF + thermocouples left, MCU sockets centre, isolated 12 V right. The
mirror image costs 9 crossing nets instead of 2.

Estimated inter-socket wiring cost: **~6–8 vias**, plus ~4 for the UART crossing
the centre channel to reach the Radioenge.

### Power

Isolated 12 V → +5 V → the module's `5V` pin → the module's on-board regulator
supplies 3V3 to the logic domain. A jumper opens the DC-DC path for USB-powered
debugging.

- **Leave the C6's left-hand 5V pad (b19-left) unconnected.** It is internally
  bonded to the right-hand one, and skipping it removes the only dangerous
  adjacency on the board (C6 5V sitting 3.81 mm from BlackPill 3V3).
- ⚠ **Add a Schottky in the DC-DC's +5 V output.** Neither module has an input
  diode, so closing the jumper with USB plugged in backfeeds the USB host.
- 3V3 is generated at different pins depending on which module is fitted
  (C6: b6-left; BlackPill: b19-left and b17-right), so it needs a bottom-layer
  run through the centre channel, ~3–4 vias.

Open SI item: SPI at 16 MHz on 2 layers with a partly fragmented ground return is
the fastest signal present. Keep solid GND pour under the ~14 mm LR1121 runs;
drop to 8 MHz if it misbehaves (no impact at these data rates).
