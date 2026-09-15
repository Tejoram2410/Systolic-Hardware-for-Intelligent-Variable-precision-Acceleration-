#!/bin/bash
#-----------------------------------------------------------------------------
# Master Single-Step Power Sign-Off Runner for Scalable Reconfigurable Systolic Array
# Configuration: N = 16 (256 Physical PEs, 64 Reconfigurable 2x2 Tiles)
# Server Target: Cadence Genus + Xcelium + Joules on SCL 180nm PDK
# Working Directory: /home/btech_anoop/Documents/mac_reconfig
#-----------------------------------------------------------------------------
set -e

echo "=========================================================================="
echo " STEP 1: Synthesizing Scalable Systolic Array (N=16, 256 PEs) in Genus"
echo "=========================================================================="
mkdir -p output_files report_files
genus -batch -files scripts/synth_systolic_reconfig_netlist.tcl

echo "=========================================================================="
echo " STEP 2: Running 256-PE Activity Simulations in Xcelium (VCD Dumps)"
echo "=========================================================================="
SCL_SIM_MODEL="/opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/verilog/vcs_sim_model/tsl18fs120_scl.v"
NETLIST="output_files/systolic_array_reconfig_nxn_netlist.v"

rm -rf xcelium.d INCA_libs *.vcd

echo "  -> Running Peak Stress Activity Simulation (Max Toggling)..."
if command -v xrun &> /dev/null; then
    xrun -clean -sv $SCL_SIM_MODEL $NETLIST tb/systolic_array_reconfig_nxn_tb_power_max.sv +access+r
    echo "  -> Running Typical ML Workload Simulation (Average Activity)..."
    xrun -clean -sv $SCL_SIM_MODEL $NETLIST tb/systolic_array_reconfig_nxn_tb_power_avg.sv +access+r
elif command -v irun &> /dev/null; then
    irun -clean -sv $SCL_SIM_MODEL $NETLIST tb/systolic_array_reconfig_nxn_tb_power_max.sv +access+r
    echo "  -> Running Typical ML Workload Simulation (Average Activity)..."
    irun -clean -sv $SCL_SIM_MODEL $NETLIST tb/systolic_array_reconfig_nxn_tb_power_avg.sv +access+r
elif command -v ncverilog &> /dev/null; then
    ncverilog +sv $SCL_SIM_MODEL $NETLIST tb/systolic_array_reconfig_nxn_tb_power_max.sv +access+r
    echo "  -> Running Typical ML Workload Simulation (Average Activity)..."
    ncverilog +sv $SCL_SIM_MODEL $NETLIST tb/systolic_array_reconfig_nxn_tb_power_avg.sv +access+r
else
    echo "ERROR: No Cadence simulator (xrun, irun, ncverilog) found in PATH."
    exit 1
fi

echo "=========================================================================="
echo " STEP 3: Calculating Power Reports in Cadence Genus / Joules (SCL 180nm)"
echo "=========================================================================="
genus -batch -files scripts/calc_systolic_reconfig_power.tcl

echo "=========================================================================="
echo " ALL POWER & AREA REPORTS GENERATED SUCCESSFULLY FOR N=16 (256 PEs)!"
echo "=========================================================================="

echo ""
echo "=========================================================================="
echo " CONSOLIDATED REPORT SUMMARY (N=16, 256 PEs, SCL 180nm @ 100 MHz)"
echo "=========================================================================="

if [ -f report_files/systolic_reconfig_area.rpt ]; then
    echo ""
    echo "--- 1. AREA & GATE COUNT SUMMARY ---"
    grep -E "total_area|cell_area|Total area" report_files/systolic_reconfig_area.rpt || cat report_files/systolic_reconfig_area.rpt | head -n 30
fi

if [ -f report_files/systolic_reconfig_power_max.rpt ]; then
    echo ""
    echo "--- 2. PEAK STRESS POWER (Max Switching Activity on 256 PEs) ---"
    grep -A 8 "Total Power" report_files/systolic_reconfig_power_max.rpt || cat report_files/systolic_reconfig_power_max.rpt | head -n 35
fi

if [ -f report_files/systolic_reconfig_power_avg.rpt ]; then
    echo ""
    echo "--- 3. TYPICAL ML WORKLOAD POWER (Realistic Activity on 256 PEs) ---"
    grep -A 8 "Total Power" report_files/systolic_reconfig_power_avg.rpt || cat report_files/systolic_reconfig_power_avg.rpt | head -n 35
fi
