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
| `esp32c6_devkitc/esp32c6/hpcore` | default (`.board`) | ~425 KB flash / ~106 KB SRAM | needs the hal_espressif C6 SPI workaround (see below) |
| `blackpill_f411ce` | `west build -b blackpill_f411ce` | ~213 KB flash / ~38 KB SRAM | **bare, non-MCUboot flash layout** (384 KB code + 128 KB storage sector); no OTA. STM32F4's 128 KB top sector is the smallest erasable unit, so `storage_partition` = that whole sector. |

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

## Pin map (ESP32-C6 dev board ⇄ Core1121 + peripherals)

Full assignment the overlay assumes. All peripherals share the C6's single
general-purpose SPI (`spi2`); each device just adds one chip-select. Change the
GPIOs in the overlay if you wire it differently.

| Signal | ESP32-C6 (Dxx = GPIOxx) | Notes |
|--------|-------------------------|-------|
| SPI SCK  | D6  | shared `spi2` |
| SPI MISO | D2  | shared `spi2` |
| SPI MOSI | D7  | shared `spi2` (LR1121 only; MAX6675 is read-only) |
| LR1121 NSS    | D10 | `cs-gpios` reg 0 |
| LR1121 NRESET | D11 | active-low |
| LR1121 BUSY   | D18 | polled every SPI transaction |
| LR1121 DIO9 (IRQ) | D3 | interrupt line (pull-down) |
| LR1121 DIO7 / DIO8 | — | broken out on the Core1121 header, unused |
| MAX6675 #1 CS | D19 | `cs-gpios` reg 1 (node `tc0`) |
| MAX6675 #2 CS | D20 | `cs-gpios` reg 2 (node `tc1`) |
| 555 keep-alive pulse | D21 | alias `keepalive-out` — **software-toggled** |
| HW watchdog kick | D22 | alias `hw-wdt-out` — **software-toggled** |
| UART1 (yours) | D0 / D1 | not claimed by this overlay |
| 3V3 / GND | 3V3 / GND | LR1121 + MAX6675 both 3.3 V |

Reserved / avoid: **D12/D13** (native USB = USB-JTAG), **D16/D17** (UART0
console), strapping **D8/D9/D15**. Free after all of the above: D4, D5, D8, D9,
D15, D23.

**Shared SPI bus.** The ESP32-C6 has only one general-purpose SPI controller, so
everything hangs off `spi2`. The two MAX6675s are read-only (SCK + SO/MISO + CS,
no MOSI) and tri-state SO when deselected, so they coexist with the LR1121; Zephyr
sets clock/mode per device (LR1121 @ 16 MHz, MAX6675 @ 4 MHz). Read them via the
`maxim,max6675` sensor driver (`CONFIG_MAX6675`), nodes aliased `tc0` / `tc1`.

**Failsafe pulse outputs (D21, D22).** These MUST be toggled from software — never
hardware PWM/LEDC. LEDC keeps running through a CPU hang, which would keep the 555
retriggered and the external watchdog fed, defeating the whole failsafe. Gate the
toggling on an application-liveness flag (a bare `k_timer` keeps firing even if the
app thread deadlocks). Both pins are Hi-Z at reset until firmware drives them, so
size the 555 / watchdog timeouts to survive boot. See the `failsafe_outputs` node
in the overlay (aliases `keepalive-out`, `hw-wdt-out`).

**Disabled peripherals.** `i2c0` (shares D6/D7 with SPI), Wi-Fi, BLE and 802.15.4
are turned off in the overlay. Console/log stay on `uart0` (D16/D17, 115200); to
reclaim D16/D17, move the console to the native USB (USB-Serial-JTAG) — not done
yet, ask if you want it.

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
