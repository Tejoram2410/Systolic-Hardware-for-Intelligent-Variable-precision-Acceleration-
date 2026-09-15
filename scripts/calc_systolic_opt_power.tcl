#-----------------------------------------------------------------------------
# Cadence Genus / Joules Power Sign-Off: Optimized 16x16 Systolic Array
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
#-----------------------------------------------------------------------------
set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high

file mkdir report_files

read_hdl -v2001 output_files/systolic_opt_netlist.v
elaborate systolic_array_reconfig_nxn

# 1. Optimized Peak Power
if {[file exists "systolic_opt_power_max.vcd"]} {
    puts "\n>>> Processing Optimized Peak Power (systolic_opt_power_max.vcd)..."
    read_stimulus -file systolic_opt_power_max.vcd -dut_instance /systolic_array_reconfig_nxn_tb_power_max/dut
    propagate_activity
    report_power > report_files/systolic_opt_power_max.rpt
    puts ">>> Generated: report_files/systolic_opt_power_max.rpt"
}

# 2. Optimized ML Average Power
if {[file exists "systolic_opt_power_avg.vcd"]} {
    puts "\n>>> Processing Optimized ML Average Power (systolic_opt_power_avg.vcd)..."
    read_stimulus -file systolic_opt_power_avg.vcd -dut_instance /systolic_array_reconfig_nxn_tb_power_avg/dut
    propagate_activity
    report_power > report_files/systolic_opt_power_avg.rpt
    puts ">>> Generated: report_files/systolic_opt_power_avg.rpt"
}

exit
