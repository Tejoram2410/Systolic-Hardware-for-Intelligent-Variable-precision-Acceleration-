#!/bin/bash
#-----------------------------------------------------------------------------
# Master Comparative Sign-Off Runner: Baseline Array vs. Optimized Array
# Design: 16x16 Scalable 2D Reconfigurable Systolic Array (256 PEs, 64 Tiles)
# Target: SCL 180nm CMOS PDK @ 100 MHz
# Working Directory: /home/btech_anoop/Documents/mac_reconfig
#-----------------------------------------------------------------------------
set -e

echo "=========================================================================="
echo " STEP 1: Synthesizing Baseline & Optimized 16x16 Arrays in Cadence Genus"
echo "=========================================================================="
rm -rf output_files report_files
mkdir -p output_files report_files
genus -batch -files scripts/synth_systolic_comparison.tcl

echo "=========================================================================="
echo " STEP 2: Running 256-PE Full-Array Activity Simulations in Xcelium"
echo "=========================================================================="
SCL_SIM_MODEL="/opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/verilog/vcs_sim_model/tsl18fs120_scl.v"

rm -rf xcelium.d INCA_libs systolic_*.vcd

echo "  -> [1/4] Simulating Baseline Array Peak Activity (systolic_baseline_power_max.vcd)..."
xrun -clean -sv $SCL_SIM_MODEL output_files/systolic_baseline_netlist.v tb/systolic_array_reconfig_nxn_tb_power_max.sv \
     +define+USE_BASELINE_DUT +define+DUMP_VCD_FILE=\"systolic_baseline_power_max.vcd\" +access+r

echo "  -> [2/4] Simulating Baseline Array ML Average Activity (systolic_baseline_power_avg.vcd)..."
xrun -clean -sv $SCL_SIM_MODEL output_files/systolic_baseline_netlist.v tb/systolic_array_reconfig_nxn_tb_power_avg.sv \
     +define+USE_BASELINE_DUT +define+DUMP_VCD_FILE=\"systolic_baseline_power_avg.vcd\" +access+r

echo "  -> [3/4] Simulating Optimized Array Peak Activity (systolic_opt_power_max.vcd)..."
xrun -clean -sv $SCL_SIM_MODEL output_files/systolic_opt_netlist.v tb/systolic_array_reconfig_nxn_tb_power_max.sv \
     +define+DUMP_VCD_FILE=\"systolic_opt_power_max.vcd\" +access+r

echo "  -> [4/4] Simulating Optimized Array ML Average Activity (systolic_opt_power_avg.vcd)..."
xrun -clean -sv $SCL_SIM_MODEL output_files/systolic_opt_netlist.v tb/systolic_array_reconfig_nxn_tb_power_avg.sv \
     +define+DUMP_VCD_FILE=\"systolic_opt_power_avg.vcd\" +access+r

echo "=========================================================================="
echo " STEP 3: Calculating Full-Array Power Sign-Off in Cadence Joules"
echo "=========================================================================="
echo ">>> [1/2] Computing Baseline Array Power..."
genus -batch -files scripts/calc_systolic_baseline_power.tcl

echo ">>> [2/2] Computing Optimized Array Power..."
genus -batch -files scripts/calc_systolic_opt_power.tcl

echo "=========================================================================="
echo " 16x16 FULL-ARRAY COMPARATIVE SIGN-OFF RESULTS (SCL 180nm @ 100 MHz)"
echo "=========================================================================="

echo ""
echo "--------------------------------------------------------------------------"
echo " 1. SILICON AREA & CELL COUNT COMPARISON (256 PEs / 64 Tiles)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/systolic_baseline_area.rpt ] && [ -f report_files/systolic_opt_area.rpt ]; then
    echo "[BASELINE 16x16 ARRAY AREA]:"
    cat report_files/systolic_baseline_area.rpt | head -n 25
    echo ""
    echo "[OPTIMIZED 16x16 ARRAY AREA]:"
    cat report_files/systolic_opt_area.rpt | head -n 25
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 2. PEAK STRESS POWER COMPARISON (100 MHz)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/systolic_baseline_power_max.rpt ]; then
    echo "[BASELINE ARRAY PEAK POWER]:"
    cat report_files/systolic_baseline_power_max.rpt | head -n 30
fi

if [ -f report_files/systolic_opt_power_max.rpt ]; then
    echo ""
    echo "[OPTIMIZED ARRAY PEAK POWER]:"
    cat report_files/systolic_opt_power_max.rpt | head -n 30
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 3. TYPICAL ML WORKLOAD POWER COMPARISON (100 MHz, Post-ReLU + Sparsity)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/systolic_baseline_power_avg.rpt ]; then
    echo "[BASELINE ARRAY ML POWER]:"
    cat report_files/systolic_baseline_power_avg.rpt | head -n 30
fi

if [ -f report_files/systolic_opt_power_avg.rpt ]; then
    echo ""
    echo "[OPTIMIZED ARRAY ML POWER]:"
    cat report_files/systolic_opt_power_avg.rpt | head -n 30
fi

echo ""
echo "--------------------------------------------------------------------------"
echo " 4. FULL-CHIP TIMING & SETUP SLACK COMPARISON (100 MHz @ SCL 180nm)"
echo "--------------------------------------------------------------------------"
if [ -f report_files/systolic_baseline_timing.rpt ]; then
    echo "[BASELINE ARRAY TIMING (Top Critical Paths)]:"
    grep -E "Path [0-9]+:|Endpoint:|Startpoint:|Data Path:|Slack:" report_files/systolic_baseline_timing.rpt | head -n 25
fi

if [ -f report_files/systolic_opt_timing.rpt ]; then
    echo ""
    echo "[OPTIMIZED ARRAY TIMING (Top Critical Paths)]:"
    grep -E "Path [0-9]+:|Endpoint:|Startpoint:|Data Path:|Slack:" report_files/systolic_opt_timing.rpt | head -n 25
fi
