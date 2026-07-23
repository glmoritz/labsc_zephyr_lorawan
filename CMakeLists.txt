# Copyright (c) 2024 Semtech Corporation
# SPDX-License-Identifier: Apache-2.0
#
# LoRaWAN periodical uplink for ESP32-C6 + Waveshare Core1121 (LR1121).
# Seeded from usp_zephyr/samples/usp/lbm/periodical_uplink.

cmake_minimum_required(VERSION 3.20.0)

# USP is delivered as two Zephyr modules that must both be registered:
#   - usp         : the USP C library (RAC lib + LoRa Basics Modem + radio
#                   drivers). Registered so ${ZEPHYR_USP_MODULE_DIR} resolves;
#                   it is cmake-ext/kconfig-ext, so usp_zephyr drives its build.
#   - usp_zephyr  : the Zephyr glue (drivers, subsys, board_root, dts_root).
# We vendor both as git submodules under modules/ and add them here instead of
# using a west manifest, because the dev container bakes Zephyr into the image
# (west topdir = /opt/toolchains) and is not driven by a workspace manifest.
list(APPEND ZEPHYR_EXTRA_MODULES
  ${CMAKE_CURRENT_SOURCE_DIR}/modules/usp
  ${CMAKE_CURRENT_SOURCE_DIR}/modules/usp_zephyr
)

# This Zephyr's SNIPPET_ROOT defaults to ${ZEPHYR_BASE} alone — the application
# directory is NOT searched automatically — so register ourselves here to make
# `west build -S expansion` resolve snippets/expansion/ (PINMAP.md §9).
list(APPEND SNIPPET_ROOT ${CMAKE_CURRENT_SOURCE_DIR})

find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(lorawan_uplink)

target_sources(app PRIVATE
  src/main.c
)

# Apply the same compile definitions as the LBM library (INTERFACE target
# exported by usp_zephyr).
target_link_libraries(app PRIVATE lbm_compile_definitions)

# --- Workaround: hal_espressif ESP32-C6 SPI HAL bug ---------------------------
# In the hal_espressif revision pinned by this container's Zephyr (main HEAD,
# rev 2a5bec2244), zephyr/esp32c6/CMakeLists.txt compiles esp_hal_gpspi/spi_hal.c
# unconditionally but gates the per-SoC esp32c6/spi_periph.c (which *defines*
# `spi_periph_signal`) behind CONFIG_PM_POWER_DOWN_PERIPHERAL_IN_LIGHT_SLEEP — a
# symbol that does not exist for the C6, so it is never true. Result: any C6 SPI
# build (upstream samples included) fails to link with an undefined reference to
# `spi_periph_signal`. Add the missing source ourselves. Not USP-related.
# Remove once the container's Zephyr/hal_espressif revision fixes this.
if(CONFIG_SOC_SERIES_ESP32C6 AND CONFIG_SPI)
  zephyr_library_sources(
    ${ZEPHYR_HAL_ESPRESSIF_MODULE_DIR}/components/esp_hal_gpspi/${CONFIG_SOC_SERIES}/spi_periph.c)
endif()
