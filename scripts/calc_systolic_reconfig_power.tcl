#-----------------------------------------------------------------------------
# Cadence Genus / Joules Master Power Calculation Script
# Design: Scalable Reconfigurable Systolic Array (N=16, 256 PEs, 64 Tiles)
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high

file mkdir report_files

proc run_power_report {vcd_file top_tb report_name} {
    puts "\n------------------------------------------------------------------"
    puts " RUNNING POWER SIGN-OFF: $report_name (Stimulus: $vcd_file)"
    puts "------------------------------------------------------------------"
    if {[file exists $vcd_file]} {
        if {[llength [get_db designs]] > 0} {
            delete_obj [get_db designs]
        }
        read_hdl -v2001 output_files/systolic_array_reconfig_nxn_netlist.v
        elaborate systolic_array_reconfig_nxn
        read_stimulus -file $vcd_file -dut_instance /$top_tb/dut
        propagate_activity
        report_power > report_files/$report_name
        puts ">>> Successfully generated report: report_files/$report_name"
    } else {
        puts "ERROR: Stimulus file $vcd_file not found. Cannot calculate power."
    }
}

# 1. Peak Stress Power Analysis (Max Activity)
run_power_report "systolic_array_reconfig_nxn_power_max.vcd" "systolic_array_reconfig_nxn_tb_power_max" "systolic_reconfig_power_max.rpt"

# 2. Typical ML Workload Power Analysis (Average Activity)
run_power_report "systolic_array_reconfig_nxn_power_avg.vcd" "systolic_array_reconfig_nxn_tb_power_avg" "systolic_reconfig_power_avg.rpt"

puts "\n=================================================================="
puts "  ALL POWER CALCULATIONS COMPLETED FOR N=16 (256 PEs)!"
puts "==================================================================\n"
exit
