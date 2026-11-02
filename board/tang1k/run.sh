
#!/usr/bin/env bash
set -euo pipefail

# ==========================================
# Tang Nano 1K - Open-source FPGA build
# GHDL + Yosys + nextpnr + Apicula
# ==========================================

# Work from the script directory
cd "$(dirname "$0")"
exec > >(tee build.log) 2>&1

# --- CONFIGURATION ---
TOP_ENTITY="top"
CST_FILE="./prj/pins.cst"
DEVICE="GW1NZ-LV1QN48C6/I5"
PACK_DEVICE="GW1NZ-1"

JSON_NETLIST="design.json"
PNR_JSON="pnr_design.json"
BITSTREAM="pack.fs"

# --- VHDL SOURCES ---
# Packages must be compiled before dependent modules.

SOURCES=(
    "../../src/version_pkg.vhd"
    "../../rtl_common/src/utilities_pkg.vhd"
    "../../src/conf/top_integration_compact_pkg.vhd"
    "../../rtl_common/src/axi_lite_slave_pkg.vhd"
    "../../rtl_common/src/axi_lite_interconnect_pkg.vhd"
    "../../src/timestamp_pkg.vhd"

    "../../src/uart_axi_lite_bridge.vhd"
    "../../rtl_common/src/axi_lite_slave.vhd"
    "../../rtl_common/src/uart.vhd"
    "../../src/top_integration.vhd"
    "../../src/system_module.vhd"
    "../../rtl_common/src/crc_checksum.vhd"
    "../../src/axil_end_bridge.vhd"
    "../../rtl_common/src/axi_lite_interconnect.vhd"
    "../../rtl_common/src/axi_interconnect_single.vhd"
    "../../src/uart_bank_bridge.vhd"
    "../../src/bank_end_bridge.vhd"
    "src/top.vhd"
    "src/clk_rst_gen.vhd"
)

# ==========================================
# 0. Check source files
# ==========================================

echo "=== 0. Checking source files ==="

for file in "${SOURCES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file"
        exit 1
    fi
done

if [[ ! -f "$CST_FILE" ]]; then
    echo "ERROR: Constraint file not found: $CST_FILE"
    exit 1
fi

echo "All ${#SOURCES[@]} VHDL files found."

# ==========================================
# 1. VHDL synthesis
# ==========================================

echo "=== 1. VHDL synthesis (GHDL + Yosys) ==="

yosys -m ghdl -p \
    "ghdl --std=08 ${SOURCES[*]} -e $TOP_ENTITY; synth_gowin -top $TOP_ENTITY -json $JSON_NETLIST"

echo "Synthesis completed: $JSON_NETLIST"

# ==========================================
# 2. Place and route
# ==========================================

echo "=== 2. Place and route (nextpnr) ==="

nextpnr-gowin \
    --json "$JSON_NETLIST" \
    --write "$PNR_JSON" \
    --device "$DEVICE" \
    --cst "$CST_FILE"

echo "Place and route completed: $PNR_JSON"

# ==========================================
# 3. Bitstream generation
# ==========================================

echo "=== 3. Bitstream generation (Apicula) ==="

gowin_pack \
    -d "$PACK_DEVICE" \
    -o "$BITSTREAM" \
    "$PNR_JSON"

# ==========================================
# 4. Done
# ==========================================

echo ""
echo "=========================================="
echo " BUILD COMPLETED SUCCESSFULLY"
echo "=========================================="
echo "Bitstream: $BITSTREAM"
echo ""

# Optional FPGA programming:
# openFPGALoader -b tangnano1k "$BITSTREAM"