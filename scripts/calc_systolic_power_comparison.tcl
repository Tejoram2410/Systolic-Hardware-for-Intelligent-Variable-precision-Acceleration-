#-----------------------------------------------------------------------------
# Cadence Genus / Joules Master Power Calculation Script: Full 16x16 Array Comparison
# Baseline Array vs. Optimized Array
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high

file mkdir report_files

proc run_array_power {netlist_file design_name vcd_file top_tb report_name} {
    puts "\n------------------------------------------------------------------"
    puts " RUNNING POWER SIGN-OFF: $report_name (Stimulus: $vcd_file)"
    puts "------------------------------------------------------------------"
    if {[file exists $vcd_file] && [file exists $netlist_file]} {
        if {[llength [get_db designs]] > 0} {
            delete_obj [get_db designs]
        }
        read_hdl -v2001 $netlist_file
        elaborate $design_name
        read_stimulus -file $vcd_file -dut_instance /$top_tb/dut
        propagate_activity
        report_power > report_files/$report_name
        puts ">>> Successfully generated report: report_files/$report_name"
    } else {
        puts "ERROR: File $vcd_file or $netlist_file not found. Cannot calculate power."
    }
}

# 1. Baseline Array Power (Max & Avg)
run_array_power "output_files/systolic_baseline_netlist.v" "systolic_array_reconfig_nxn_baseline" "systolic_baseline_power_max.vcd" "systolic_array_reconfig_nxn_tb_power_max" "systolic_baseline_power_max.rpt"
run_array_power "output_files/systolic_baseline_netlist.v" "systolic_array_reconfig_nxn_baseline" "systolic_baseline_power_avg.vcd" "systolic_array_reconfig_nxn_tb_power_avg" "systolic_baseline_power_avg.rpt"

# 2. Optimized Array Power (Max & Avg)
run_array_power "output_files/systolic_opt_netlist.v" "systolic_array_reconfig_nxn" "systolic_opt_power_max.vcd" "systolic_array_reconfig_nxn_tb_power_max" "systolic_opt_power_max.rpt"
run_array_power "output_files/systolic_opt_netlist.v" "systolic_array_reconfig_nxn" "systolic_opt_power_avg.vcd" "systolic_array_reconfig_nxn_tb_power_avg" "systolic_opt_power_avg.rpt"

puts "\n=================================================================="
puts "  FULL ARRAY COMPARATIVE POWER SIGN-OFF COMPLETED!"
puts "==================================================================\n"
exit
