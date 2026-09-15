#!/bin/bash
# End-to-End Power Sign-Off Runner for mac_reconfig_booth_dadda_pdk
set -e

echo "=========================================================="
echo " STEP 1: Synthesizing PDK Netlist in Cadence Genus"
echo "=========================================================="
genus -batch -files scripts/synth_booth_dadda_pdk_netlist.tcl

echo "=========================================================="
echo " STEP 2: Running 6 Simulations in Xcelium (VCD Dumps)"
echo "=========================================================="
SCL_SIM_MODEL="/opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/verilog/vcs_sim_model/tsl18fs120_scl.v"
NETLIST="output_files/mac_reconfig_booth_dadda_pdk_netlist.v"

xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_pdk_tb_int4_max.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_pdk_tb_int4_avg.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_pdk_tb_int8_max.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_pdk_tb_int8_avg.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_pdk_tb_combined_max.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_pdk_tb_combined_avg.sv +access+r

echo "=========================================================="
echo " STEP 3: Calculating Power in Genus Joules"
echo "=========================================================="
genus -batch -files scripts/calc_booth_dadda_pdk_power.tcl

echo "=========================================================="
echo " ALL 6 PDK POWER REPORTS GENERATED SUCCESSFULLY!"
echo "=========================================================="
