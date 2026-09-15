#!/bin/bash
#-----------------------------------------------------------------------------
# Master ASIC Sign-Off Runner: Unified INTxINT / FPxFP / INTxFP MAC Tile (12 Modes)
# Technology: SCL 180nm CMOS PDK @ 100 MHz
# Working Directory: /home/btech_anoop/Documents/mac_reconfig
#-----------------------------------------------------------------------------
set -e

echo "=========================================================================="
echo " STEP 1: Synthesizing Unified 12-Mode MAC Tile in Cadence Genus"
echo "=========================================================================="
rm -rf output_files/mac_unified_tile* report_files/unified_tile*
mkdir -p output_files report_files
genus -batch -files scripts/synth_unified_tile.tcl

echo "=========================================================================="
echo " STEP 2: Running 12-Mode Dynamic Activity Simulation in Xcelium"
echo "=========================================================================="
SCL_SIM_MODEL="/opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/verilog/vcs_sim_model/tsl18fs120_scl.v"

rm -rf xcelium.d INCA_libs mac_unified_tile_power.vcd

xrun -clean -sv $SCL_SIM_MODEL output_files/mac_unified_tile_netlist.v tb/mac_reconfig_unified_tile_power_tb.sv \
     +define+DUMP_VCD_FILE=\"mac_unified_tile_power.vcd\" +access+r

echo "=========================================================================="
echo " STEP 3: Calculating Dynamic & Leakage Power in Cadence Joules"
echo "=========================================================================="
genus -batch -files scripts/calc_unified_tile_power.tcl

echo "=========================================================================="
echo " UNIFIED 12-MODE MAC TILE SIGN-OFF RESULTS (SCL 180nm @ 100 MHz)"
echo "=========================================================================="

echo ""
echo "--------------------------------------------------------------------------"
echo " 1. SILICON AREA & CELL COUNT"
echo "--------------------------------------------------------------------------"
if [ -f report_files/unified_tile_area.rpt ]; then
    cat report_files/unified_tile_area.rpt | head -n 25
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 2. DYNAMIC & LEAKAGE POWER DISSIPATION (100 MHz @ SCL 180nm)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/unified_tile_power.rpt ]; then
    cat report_files/unified_tile_power.rpt
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 3. STATIC TIMING ANALYSIS & SETUP SLACK (Top Critical Paths)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/unified_tile_timing.rpt ]; then
    grep -E "Path [0-9]+:|Endpoint:|Startpoint:|Data Path:|Slack:" report_files/unified_tile_timing.rpt | head -n 25
fi
