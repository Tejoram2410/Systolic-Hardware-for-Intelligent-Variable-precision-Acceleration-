#!/bin/bash
#-----------------------------------------------------------------------------
# Master Comparative Sign-Off Runner: Baseline Tile vs. Optimized Tile
# Target: SCL 180nm CMOS PDK @ 100 MHz
# Working Directory: /home/btech_anoop/Documents/mac_reconfig
#-----------------------------------------------------------------------------
set -e

echo "=========================================================================="
echo " STEP 1: Synthesizing Baseline & Optimized Tiles in Cadence Genus"
echo "=========================================================================="
rm -rf output_files report_files
mkdir -p output_files report_files
genus -batch -files scripts/synth_tile_comparison.tcl

echo "=========================================================================="
echo " STEP 2: Running Standalone Activity Simulations in Xcelium (VCD Dumps)"
echo "=========================================================================="
SCL_SIM_MODEL="/opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/verilog/vcs_sim_model/tsl18fs120_scl.v"

rm -rf xcelium.d INCA_libs tile_*.vcd

echo "  -> Simulating Baseline Tile Netlist (tile_baseline_power.vcd)..."
xrun -clean -sv $SCL_SIM_MODEL output_files/tile_baseline_netlist.v tb/mac_reconfig_tile_power_tb.sv \
     +define+USE_BASELINE_DUT +define+DUMP_VCD_FILE=\"tile_baseline_power.vcd\" +access+r

echo "  -> Simulating Optimized Tile Netlist (tile_opt_power.vcd)..."
xrun -clean -sv $SCL_SIM_MODEL output_files/tile_opt_netlist.v tb/mac_reconfig_tile_power_tb.sv \
     +define+DUMP_VCD_FILE=\"tile_opt_power.vcd\" +access+r

echo "=========================================================================="
echo " STEP 3: Calculating Power Sign-Off in Cadence Joules (SCL 180nm)"
echo "=========================================================================="
genus -batch -files scripts/calc_tile_power_comparison.tcl

echo "=========================================================================="
echo " COMPARATIVE SIGN-OFF RESULTS SUMMARY (SCL 180nm @ 100 MHz)"
echo "=========================================================================="

echo ""
echo "--------------------------------------------------------------------------"
echo " 1. SILICON AREA & CELL COUNT COMPARISON"
echo "--------------------------------------------------------------------------"
if [ -f report_files/tile_baseline_area.rpt ] && [ -f report_files/tile_opt_area.rpt ]; then
    echo "[BASELINE TILE AREA]:"
    grep -E "total_area|cell_area|Total area" report_files/tile_baseline_area.rpt || cat report_files/tile_baseline_area.rpt | head -n 25
    echo ""
    echo "[OPTIMIZED TILE AREA]:"
    grep -E "total_area|cell_area|Total area" report_files/tile_opt_area.rpt || cat report_files/tile_opt_area.rpt | head -n 25
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 2. DYNAMIC & LEAKAGE POWER COMPARISON (100 MHz)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/tile_baseline_power.rpt ]; then
    echo "[BASELINE TILE POWER]:"
    grep -A 8 "Total Power" report_files/tile_baseline_power.rpt || cat report_files/tile_baseline_power.rpt | head -n 30
fi

if [ -f report_files/tile_opt_power.rpt ]; then
    echo ""
    echo "[OPTIMIZED TILE POWER]:"
    grep -A 8 "Total Power" report_files/tile_opt_power.rpt || cat report_files/tile_opt_power.rpt | head -n 30
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 3. GENUS HELP REPORT_POWER OUTPUT (FIRST 40 LINES)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/genus_help_report_power.txt ]; then
    head -n 40 report_files/genus_help_report_power.txt
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 4. HIERARCHICAL / DETAILED POWER REPORTS GENERATED:"
echo "--------------------------------------------------------------------------"
ls -la report_files/*.rpt || true
