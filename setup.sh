#!/usr/bin/env bash
#
# Post-clone setup for labsc_zephyr_lorawan.
#
#   1) fetch the USP submodules (usp_zephyr + usp, incl. usp's vendored LBM etc.)
#   2) apply local patches to those vendored modules that are needed to build
#      against this container's Zephyr (main HEAD / 4.5-dev):
#        - usp_zephyr's xiao_nrf54l15 board.yml is missing `full_name`, which the
#          newer board schema requires; without it, board resolution aborts for
#          ANY board (the whole usp_zephyr board_root is validated).
#
# Safe to re-run: patches are only applied if not already present.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$here"

echo "==> Initializing submodules (usp_zephyr, usp)…"
git submodule update --init --recursive

echo "==> Applying vendored-module patches to modules/usp_zephyr…"
shopt -s nullglob
for p in "$here"/patches/*.patch; do
    name="$(basename "$p")"
    if git -C modules/usp_zephyr apply --reverse --check "$p" >/dev/null 2>&1; then
        echo "    already applied: $name"
    elif git -C modules/usp_zephyr apply --check "$p" >/dev/null 2>&1; then
        git -C modules/usp_zephyr apply "$p"
        echo "    applied:         $name"
    else
        echo "    WARNING: could not apply $name (context changed?) — review manually"
    fi
done

echo "==> Done. You can now build:"
echo "    /workspace/scripts/zephyr-project.sh set   /workspace/projects/lorawan_uplink"
echo "    /workspace/scripts/zephyr-project.sh build"
