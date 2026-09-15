#!/bin/bash
#-----------------------------------------------------------------------------
# Master Comparative 45nm Sign-Off Runner (NanGate / FreePDK45 CMOS @ 500 MHz)
# Compares Standard INT4 Tile vs. Low-Power NVFP4 Tile with Matched 500 MHz Activity
#-----------------------------------------------------------------------------
set -e

SIM_MODEL="/opt/rh/progs/cadence/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/verilog/FreePDK45_lib_v1.0_typical.v"

echo "=========================================================================="
echo " STEP 1: Synthesizing Both Tiles on 45nm @ 500 MHz in Cadence Genus"
echo "=========================================================================="
rm -rf output_files_45nm report_files_45nm
mkdir -p output_files_45nm report_files_45nm

genus -batch -files scripts/synth_tile_comparison_45nm.tcl
genus -batch -files scripts/synth_nvfp4_tile_45nm.tcl

echo "=========================================================================="
echo " STEP 2: Running Activity Simulations in Xcelium (VCD Dumps @ 500 MHz / 2ns)"
echo "=========================================================================="
rm -rf xcelium.d INCA_libs *.vcd

echo "  -> Simulating Standard INT4 45nm Netlist (tile_opt_power_45nm.vcd @ 500 MHz)..."
xrun -clean -timescale 1ns/1ps $SIM_MODEL output_files_45nm/tile_opt_netlist.v tb/mac_reconfig_tile_power_tb.sv \
     +define+DUMP_VCD_FILE=\"tile_opt_power_45nm.vcd\" +access+r

echo "  -> Simulating NVFP4 45nm Netlist (nvfp4_tile_power_45nm.vcd @ 500 MHz)..."
xrun -clean -timescale 1ns/1ps $SIM_MODEL output_files_45nm/nvfp4_tile_opt_netlist.v tb/mac_reconfig_nvfp4_tile_power_tb.sv \
     +define+DUMP_VCD_FILE=\"nvfp4_tile_power_45nm.vcd\" +access+r

echo "=========================================================================="
echo " STEP 3: Calculating Power Sign-Off in Cadence Joules (45nm @ 500 MHz)"
echo "=========================================================================="
genus -batch -files scripts/calc_tile_power_comparison_45nm.tcl
genus -batch -files scripts/calc_nvfp4_power_45nm.tcl

echo "=========================================================================="
echo " EQUIVALENT 500 MHz SIGN-OFF RESULTS SUMMARY (45nm NanGate / FreePDK45)"
echo "=========================================================================="

echo ""
echo "--------------------------------------------------------------------------"
echo " 1. SILICON AREA & CELL COUNT COMPARISON"
echo "--------------------------------------------------------------------------"
if [ -f report_files_45nm/tile_opt_area.rpt ]; then
    echo "[STANDARD INT4 TILE AREA (45nm)]:"
    grep -E "total_area|cell_area|Total area" report_files_45nm/tile_opt_area.rpt || cat report_files_45nm/tile_opt_area.rpt | head -n 25
fi

if [ -f report_files_45nm/nvfp4_tile_opt_area.rpt ]; then
    echo ""
    echo "[NVFP4 MICROSCALING TILE AREA (45nm)]:"
    grep -E "total_area|cell_area|Total area" report_files_45nm/nvfp4_tile_opt_area.rpt || cat report_files_45nm/nvfp4_tile_opt_area.rpt | head -n 25
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 2. DYNAMIC & LEAKAGE POWER COMPARISON (MATCHED 500 MHz CLOCK)"
echo "--------------------------------------------------------------------------"
if [ -f report_files_45nm/tile_opt_power.rpt ]; then
    echo "[STANDARD INT4 TILE POWER (45nm @ 500 MHz)]:"
    grep -A 8 "Total Power" report_files_45nm/tile_opt_power.rpt || cat report_files_45nm/tile_opt_power.rpt | head -n 30
fi

if [ -f report_files_45nm/nvfp4_tile_power.rpt ]; then
    echo ""
    echo "[NVFP4 MICROSCALING TILE POWER (45nm @ 500 MHz)]:"
    grep -A 8 "Total Power" report_files_45nm/nvfp4_tile_power.rpt || cat report_files_45nm/nvfp4_tile_power.rpt | head -n 30
fi

echo ""
echo "=========================================================================="
