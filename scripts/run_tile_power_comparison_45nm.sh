#!/bin/bash
#-----------------------------------------------------------------------------
# Master Comparative Sign-Off Runner: Baseline Tile vs. Optimized Tile
# Target: 45nm NanGate / FreePDK45 CMOS PDK @ 500 MHz
#-----------------------------------------------------------------------------
set -e

echo "=========================================================================="
echo " STEP 1: Synthesizing Baseline & Optimized Tiles on 45nm in Cadence Genus"
echo "=========================================================================="
rm -rf output_files_45nm report_files_45nm
mkdir -p output_files_45nm report_files_45nm
genus -batch -files scripts/synth_tile_comparison_45nm.tcl

echo "=========================================================================="
echo " STEP 2: Running Activity Simulations in Xcelium (VCD Dumps @ 500 MHz)"
echo "=========================================================================="
rm -rf xcelium.d INCA_libs tile_*_45nm.vcd

SIM_MODEL="/opt/rh/progs/cadence/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/verilog/FreePDK45_lib_v1.0_typical.v"

echo "  -> Simulating Baseline 45nm Netlist (tile_baseline_power_45nm.vcd)..."
xrun -clean -timescale 1ns/1ps $SIM_MODEL output_files_45nm/tile_baseline_netlist.v tb/mac_reconfig_tile_power_tb.sv \
     +define+USE_BASELINE_DUT +define+DUMP_VCD_FILE=\"tile_baseline_power_45nm.vcd\" +access+r

echo "  -> Simulating Optimized 45nm Netlist (tile_opt_power_45nm.vcd)..."
xrun -clean -timescale 1ns/1ps $SIM_MODEL output_files_45nm/tile_opt_netlist.v tb/mac_reconfig_tile_power_tb.sv \
     +define+DUMP_VCD_FILE=\"tile_opt_power_45nm.vcd\" +access+r

echo "=========================================================================="
echo " STEP 3: Calculating Power Sign-Off in Cadence Joules (45nm @ 500 MHz)"
echo "=========================================================================="
genus -batch -files scripts/calc_tile_power_comparison_45nm.tcl

echo "=========================================================================="
echo " COMPARATIVE SIGN-OFF RESULTS SUMMARY (45nm NanGate / FreePDK45 @ 500 MHz)"
echo "=========================================================================="

echo ""
echo "--------------------------------------------------------------------------"
echo " 1. SILICON AREA & CELL COUNT COMPARISON"
echo "--------------------------------------------------------------------------"
if [ -f report_files_45nm/tile_baseline_area.rpt ] && [ -f report_files_45nm/tile_opt_area.rpt ]; then
    echo "[BASELINE TILE AREA (45nm)]:"
    grep -E "total_area|cell_area|Total area" report_files_45nm/tile_baseline_area.rpt || cat report_files_45nm/tile_baseline_area.rpt | head -n 25
    echo ""
    echo "[OPTIMIZED TILE AREA (45nm)]:"
    grep -E "total_area|cell_area|Total area" report_files_45nm/tile_opt_area.rpt || cat report_files_45nm/tile_opt_area.rpt | head -n 25
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 2. DYNAMIC & LEAKAGE POWER COMPARISON (500 MHz)"
echo "--------------------------------------------------------------------------"
if [ -f report_files_45nm/tile_baseline_power.rpt ]; then
    echo "[BASELINE TILE POWER (45nm)]:"
    grep -A 8 "Total Power" report_files_45nm/tile_baseline_power.rpt || cat report_files_45nm/tile_baseline_power.rpt | head -n 30
fi

if [ -f report_files_45nm/tile_opt_power.rpt ]; then
    echo ""
    echo "[OPTIMIZED TILE POWER (45nm)]:"
    grep -A 8 "Total Power" report_files_45nm/tile_opt_power.rpt || cat report_files_45nm/tile_opt_power.rpt | head -n 30
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 3. HIERARCHICAL / DETAILED POWER REPORTS GENERATED:"
echo "--------------------------------------------------------------------------"
ls -la report_files_45nm/*.rpt || true
