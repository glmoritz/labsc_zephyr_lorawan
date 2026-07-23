# labsc_zephyr_lorawan — LoRaWAN uplink (ESP32-C6 + Core1121 / LR1121)

Zephyr LoRaWAN firmware for a custom board pairing an **ESP32-C6** host with a
**Waveshare Core1121-XF (Semtech LR1121)** modem, built on Semtech **USP** (which
wraps LoRa Basics Modem). Seeded from `usp_zephyr/samples/usp/lbm/periodical_uplink`.

The custom board is **not routed yet**, so this builds for the off-the-shelf
`esp32c6_devkitc` with a Core1121 wiring overlay. When the board is routed, add a
custom board definition and point `.board` at it.

## Targets

The same app builds for two host boards (each with its own `boards/<board>.overlay`
+ `.conf`); `.board` selects the default:

| Board | Build | Footprint | Notes |
|-------|-------|-----------|-------|
| `esp32c6_devkitc/esp32c6/hpcore` | default (`.board`) | ~426 KB flash / ~106 KB SRAM | needs the hal_espressif C6 SPI workaround (see below) |
| `blackpill_f411ce` | `west build -b blackpill_f411ce` | ~219 KB flash / ~38 KB SRAM | **bare, non-MCUboot flash layout** (384 KB code + 128 KB storage sector); no OTA. STM32F4's 128 KB top sector is the smallest erasable unit, so `storage_partition` = that whole sector. |

Same pin *functions*, different pin *numbers* per board — see each overlay header
for its wiring table.

## Where this lives

This is the *inner project* of the reused e-ink dev environment. It is placed at
`workspace/projects/lorawan_uplink/` inside a checkout of the `zephyr_container`
repo (the container gitignores `workspace/projects/`). The container already ships
everything needed for ESP32-C6: the `riscv64-zephyr-elf` toolchain, `esptool`, and
Espressif `openocd` with `esp32c6.cfg` — **no Docker changes are required.**

## Layout

| Path | Purpose |
|------|---------|
| `CMakeLists.txt` | Registers the two USP modules via `ZEPHYR_EXTRA_MODULES` and builds `src/main.c`. |
| `prj.conf` | USP + LBM + transceiver-driver config (from the sample). |
| `.board` | `esp32c6_devkitc/esp32c6/hpcore` (interim target). |
| `modules/usp_zephyr` | git submodule → `Lora-net/usp_zephyr` (Zephyr glue: driver, DT bindings, shields). |
| `modules/usp` | git submodule → `Lora-net/usp` (USP C library: RAC lib + LBM + radio drivers). |
| `boards/esp32c6_devkitc_esp32c6_hpcore.overlay` | Core1121/LR1121 wiring (SPI + control GPIOs + RF switch + TCXO). |
| `boards/esp32c6_devkitc_esp32c6_hpcore.conf` | Board-scoped Kconfig (placeholder). |
| `boards/user_keys.overlay` | LoRaWAN DevEUI / JoinEUI / AppKey / region. **Fill before joining.** |

## First-time setup

```bash
git clone git@github.com:glmoritz/labsc_zephyr_lorawan.git
cd labsc_zephyr_lorawan
./setup.sh      # inits the usp_zephyr + usp submodules AND applies the vendored-module patches
```

`setup.sh` is safe to re-run. It does `git submodule update --init --recursive` and
then applies the patches in `patches/` (see *Known workarounds* below).

## Carrier pin map (one board, either MCU)

> **[`PINMAP.md`](PINMAP.md) is authoritative** — it carries the complete
> position-by-position table, the 12 V field I/O, the strap rules and the board
> placement offsets. The summary below is kept for orientation only; if the two
> disagree, `PINMAP.md` wins.
>
> `PINMAP.md` **§9** describes the planned **dual expansion connectors** (I²C +
> UART + INT, one per socket) for the industrial-controller revision. Not routed
> and not in the overlays yet.

The target hardware is a **dual-socket carrier**: it accepts *either* an ESP32-C6
mini *or* a WeAct BlackPill F411CE, in overlapped 2.54 mm socket rows, so both
firmware targets drive the same wiring. The pin assignment below is a **routing
result, not a preference** — it was derived from the two footprints' real
geometry to minimise crossings on a 2-layer board.

### How the sockets nest

The row spacings differ (C6 = 22.86 mm, BlackPill = 15.24 mm), so they cannot
alternate evenly. Nesting them concentrically is better anyway:

```
C6-left ▏ BP-left ┊┊┊ BP-right ▏ C6-right
 −3.81     0.00   ┊┊┊  15.24     19.05      (mm, BlackPill pad 1 at origin)
```

Place the **ESP32-C6 footprint at (X −1.27, Y +10.16), rotation 0**. Each C6 row
then sits **3.81 mm outboard of its BlackPill partner row**, offset **5 pitches**
in Y. Consequences:

- A shared net becomes **one straight 3.81 mm stub** between two adjacent pads.
- Only the outer (C6) pad ever needs to escape, and it escapes **outward into
  open board** — no track ever threads between pads.
- The middle **15.24 mm channel is completely free** for power.
- The Y offset is the only one that lands SPI1's `PB3/PB4/PB5` and USART2's
  `PA2/PA3` on clean C6 GPIOs at once (swept exhaustively in `PINMAP.md` §1).
  There is **no** free power adjacency — power is routed deliberately.

### Assignment

`b` = socket row index, counted from the BlackPill's USB-C end (`y = 2.54·b`).

| b | BlackPill | ESP32-C6 | Net |
|---|-----------|----------|-----|
| **LEFT rows — RF + sensors** ||||
| 8 | PA12 | D4 | MAX6675 #1 CS (`cs-gpios` reg 1, node `tc0`) |
| 9 | PA15 | D5 | LR1121 NSS (`cs-gpios` reg 0) |
| 10 | PB3 | D6 | SPI SCK |
| 11 | PB4 | D7 | SPI MISO |
| 12 | PB5 | D0 | SPI MOSI |
| 13 | PB6 | D1 | LR1121 NRESET |
| 14 | PB7 | D8 | **reserved, leave NC** (keeps the C6 RGB LED usable) |
| 15 | PB8 | D10 | LR1121 BUSY |
| 16 | PB9 | D11 | LR1121 DIO9 (IRQ, pull-down) |
| **RIGHT rows — field I/O, UART, power control** ||||
| 6 | PB0 | D2 | MAX6675 #2 CS (`cs-gpios` reg 2, node `tc1`) |
| 7 | PA7 | D3 | OPTO_IN1 — contactor dry contact (active low) |
| 8 | PA6 | *(→ D22)* | spare, BlackPill end |
| 8 | — | TX (GPIO16) | UART TX, C6 end (module pad 27) |
| 9 | PA5 | *(→ D23)* | OPTO_IN2 (RFU, active low), BlackPill end |
| 9 | — | RX (GPIO17) | UART RX, C6 end (module pad 26) |
| 10 | PA4 | D15 | OPTO_OUT2 (RFU, active-low sink) |
| 11 | PA3 | D23 | UART RX (BP end) / OPTO_IN2 (C6 end) |
| 12 | PA2 | D22 | UART TX (BP end) / spare (C6 end) |
| 13 | PA1 | D21 | 555 keep-alive (alias `keepalive-out`) |
| 14 | PA0 | D20 | HW watchdog kick (alias `hw-wdt-out`) |
| **LEDs — BlackPill only** ||||
| 0–3 | PB12–PB15 | — | status LEDs 1–4 (`led0`…`led3`) |

LR1121 DIO7/DIO8 are broken out on the Core1121 header and unused.

### Why these pins and not others

- **SPI1 uses its PB3/PB4/PB5 alternate mapping**, not the PA5/PA6/PA7 default.
  That single change is what makes the fanout crossing-free: all three bus
  signals land consecutively on one socket row. Verified present in Zephyr as
  `spi1_sck_pb3` / `spi1_miso_pb4` / `spi1_mosi_pb5`.
- **The STM32 is the anchor.** Its SPI/USART pins are fixed alternate functions;
  the ESP32-C6's GPIO matrix can put SPI2 on *any* GPIO. So the constrained side
  picks first and the C6 follows — the opposite of the intuitive ordering.
- **Console moves to USART2 (PA2/PA3).** USART1's PA9/PA10 sit at rows b5/b6
  where the C6's neighbours are GND and 3V3.
- **D8 (strapping) carries a chip select** — a host-driven output that idles
  high, which is what the strap wants at boot. Device-driven inputs (BUSY, MISO,
  UART RX) are deliberately kept off D8/D9/D15.
- **D15 must be left unconnected.** It selects the JTAG source; pulling it low
  costs USB-Serial-JTAG debugging. Keeping it high is also what makes D4–D7
  (the pin-JTAG group) safe to use as ordinary GPIO.
- **PA15/PB3/PB4 are JTAG pins** with reset pull-ups — harmless with SWD-only
  debug, and PA15's pull-up usefully holds NSS deasserted before firmware runs.
- **PA12 is USB D+** on the BlackPill (1.5k pull-up); fine for a push-pull CS,
  which also wants to idle high.

### There are no "STM-only" pins

The BlackPill has 40 header positions, the C6 mini has 30, so **10 BlackPill
positions have no C6 neighbour at all** (rows b0–b4, both sides) plus 6 more
whose C6 neighbour is a power or reset pin. Those are all left **unconnected by
rule** — wiring anything there would create a function the C6 could not perform.

The C6 is the binding constraint on the whole board: 21 GPIO-ish pins, minus
D12/D13 (native USB), D9/D18/D19 (dead pairs) and D8 (reserved for the onboard
RGB LED). Nearly all the rest are used; **one shared spare remains** — BlackPill
`PA6` (b8-right) to C6 `D22` (b12-right). The BlackPill's ~16 surplus pins are
dead weight apart from the four LED pins. Both `RST` pins stay NC — there is no
global reset net.

Convenient side effect: rows b0–b4 carry no routing, and that is exactly where
both modules' USB-C connectors point. Keep that end free of tall parts and both
USB ports are accessible with no cutout.

Reserved / avoid on the C6: **D12/D13** (native USB = USB-JTAG), **D16/D17**
(UART0 console), strapping **D8/D9/D15**.

**Shared SPI bus.** The ESP32-C6 has only one general-purpose SPI controller, so
everything hangs off `spi2`. The two MAX6675s are read-only (SCK + SO/MISO + CS,
no MOSI) and tri-state SO when deselected, so they coexist with the LR1121; Zephyr
sets clock/mode per device (LR1121 @ 16 MHz, MAX6675 @ 4 MHz). Read them via the
`maxim,max6675` sensor driver (`CONFIG_MAX6675`), nodes aliased `tc0` / `tc1`.

**Failsafe pulse outputs (D21, D20).** These MUST be toggled from software — never
hardware PWM/LEDC. LEDC keeps running through a CPU hang, which would keep the 555
retriggered and the external watchdog fed, defeating the whole failsafe. Gate the
toggling on an application-liveness flag (a bare `k_timer` keeps firing even if the
app thread deadlocks). Both pins are Hi-Z at reset until firmware drives them, so
size the 555 / watchdog timeouts to survive boot. See the `failsafe_outputs` node
in the overlay (aliases `keepalive-out`, `hw-wdt-out`).

**Disabled peripherals.** `i2c0` (shares D6/D7 with SPI), Wi-Fi, BLE and 802.15.4
are turned off in the overlay. Console/log stay on `uart0` (D16/D17, 115200) on
the C6 and on `usart2` (PA2/PA3, 115200) on the STM32 — the same carrier net.

## Board notes (carrier, not routed yet)

Design decisions already fixed, recorded here so the layout and the firmware stay
in agreement:

- **Radio modems are nested too.** The Core1121 (rows 15.24 mm apart) and the
  Radioenge modem (17.78 mm) cannot overlap concentrically — the socket strips
  would be 1.27 mm apart and physically collide. Place the **Radioenge footprint
  at Core1121 + (X +11.43, Y +17.78), rotation 0**: rows then fall at −6.35 / 0 /
  +11.43 / +15.24, min gap 3.81 mm, 21.59 mm total instead of ~43 mm side by
  side. Both signal rows face the MCU sockets. Only Radioenge pads 1–5 (GND,
  AT_RX, AT_TX, VCC) are electrically used; its second row is mechanical.
- **Place the Core1121 at Y +17.78** relative to the BlackPill origin and its
  CS / SCLK / RESET pads land on the *exact* y of carrier rows b9 / b10 / b13 —
  three dead-straight tracks. Only MISO/MOSI cross (the module orders them
  MOSI-then-MISO), and BUSY jogs one pitch because TC2_CS occupies b14.
- **Floorplan:** RF + MAX6675 on the left edge, isolated 12 V domain (555,
  optocouplers, screw terminals) on the right. The alternative costs 9 crossing
  nets instead of 2.
- **MAX6675 modules** use right-angle 1×5 headers (`GND, VCC, SCK, CS, SO`) on
  the **top edge**, which carries no routing. Run SCK + MISO as a short bus along
  the edge and tap each header off it; only CS1/CS2 arrive individually.
- **UART crosses the middle channel** on the bottom layer (~4 vias) to reach the
  Radioenge. Cheaper than the alternative (USART1 on PB6/PB7) which would put
  UART RX on strapping pin D8, driven by the modem — a boot hazard.
- **Power:** isolated 12 V → +5 V → the module's `5V` pin → the module's on-board
  regulator supplies 3V3. A jumper opens the DC-DC path for USB-powered
  debugging. **Leave the C6's left-hand 5V pad (b19-left) unconnected** — it is
  internally bonded to the right-hand one, and skipping it removes the only
  dangerous adjacency on the board (C6 5V 3.81 mm from BlackPill 3V3).
- ⚠ **Add a Schottky in the DC-DC's +5 V output.** Neither module has an input
  diode, so closing the jumper with USB plugged in backfeeds the USB host.
- **Failsafe is de-energize-to-trip and there is no reset net.** The watchdog
  cuts mains to the oven; a dead processor stays dead until a human intervenes.
- Estimated cost of the whole inter-socket wiring: **~6–8 vias**.
- Open SI item: SPI at 16 MHz on 2 layers with a partly fragmented ground return
  is the fastest signal present. Keep solid GND pour under the ~14 mm LR1121
  runs; drop to 8 MHz if it misbehaves (no impact at these data rates).

## Build / flash / debug

Inside the dev container, via the workspace helper (or the VS Code tasks):

```bash
# from /workspace
./scripts/zephyr-project.sh set   /workspace/projects/lorawan_uplink
./scripts/zephyr-project.sh build            # west build -b esp32c6_devkitc/esp32c6/hpcore
./scripts/zephyr-project.sh flash /dev/ttyACM0
```

Debug uses the workspace `boards/esp32c6-zephyr.cfg` (OpenOCD, built-in USB-JTAG)
and the RISC-V GDB launch config (`riscv64-zephyr-elf-gdb`, `set architecture riscv:rv32`).

## Firmware status

The MAX6675 thermocouples and the two failsafe outputs are **wired in devicetree /
Kconfig only** — the application (`src/main.c`) is still the stock LoRaWAN
periodical-uplink sample and does **not** yet read the thermocouples, toggle the
keep-alive / watchdog pulses, or implement the liveness gating. That logic is the
next step (deferred by design). The board devicetree already exposes it all:
`DEVICE_DT_GET(DT_ALIAS(tc0))` / `tc1`, and `GPIO_DT_SPEC_GET` on
`DT_ALIAS(keepalive_out)` / `hw_wdt_out`.

## TODOs before RF is trustworthy

- **Credentials:** fill `boards/user_keys.overlay` (currently all-zero) and set the region.
- **RF calibration:** the `tx-power-cfg-*`, `rssi-calibration-*`, and `tx-dbm-to-ua-*`
  tables in the overlay are LR1121-MB1 reference values — recalibrate for the
  Core1121-XF BOM.
- **TCXO:** confirm the TCXO supply voltage and wake-up time (`tcxo-voltage`,
  `tcxo-wakeup-time`).
- **TX path:** confirm `lf-tx-path` against the Core1121 R3/R4 population (HP only vs LP+HP).
- **RF switch:** verify the PE4259 DIO5/DIO6 polarity against the PE4259 datasheet.

## Known workarounds (Zephyr 4.5-dev)

The container pins Zephyr to main HEAD (4.4.99 / "4.5-dev"). USP's own code compiles
cleanly on it — but two unrelated things needed working around to build for the C6:

1. **`usp_zephyr` board.yml schema** — its only shipped board (`xiao_nrf54l15`) is
   missing `full_name`, now required by the board schema; without it, board
   resolution aborts for *every* board. Fixed by `patches/0001-…full_name.patch`,
   applied by `setup.sh`. (The board is redundant — upstream Zephyr already ships
   `xiao_nrf54l15` — and we don't use it.)

2. **hal_espressif ESP32-C6 SPI bug** — the pinned HAL revision (`2a5bec2244`) gates
   `esp_hal_gpspi/esp32c6/spi_periph.c` on a Kconfig symbol that does not exist for
   the C6, so it is never compiled and `spi_hal.c` fails to link
   (`undefined reference to spi_periph_signal`). This breaks *all* C6 SPI builds,
   upstream samples included — not USP-specific. Worked around in `CMakeLists.txt`
   by compiling the missing source ourselves.

Both are self-contained in this repo (no container/image changes). If you would
rather have **zero workarounds**, pin the container's Zephyr to a stable release —
`v4.2.0` is the one USP is validated against and predates both issues; that is a
container-side change (a dedicated `Dockerfile` + image rebuild), not a code change
here. Remove the two workarounds above if you take that route.
