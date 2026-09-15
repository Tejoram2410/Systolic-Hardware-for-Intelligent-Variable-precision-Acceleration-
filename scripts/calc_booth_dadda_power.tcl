set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high

proc run_power_report {vcd_file top_tb report_name} {
    puts "\n--- RUNNING POWER SIGN-OFF: $report_name ---"
    if {[llength [get_db designs]] > 0} {
        delete_obj [get_db designs]
    }
    read_hdl -v2001 output_files/mac_reconfig_booth_dadda_netlist.v
    elaborate mac_reconfig_booth_dadda
    read_stimulus -file $vcd_file -dut_instance /$top_tb/dut
    propagate_activity
    report_power > report_files/$report_name
    puts "Report generated: report_files/$report_name"
}

run_power_report "mac_reconfig_booth_dadda_int4_max.vcd"     "mac_reconfig_booth_dadda_tb_int4_max"     "mac_reconfig_booth_dadda_power_int4_max.rpt"
run_power_report "mac_reconfig_booth_dadda_int4_avg.vcd"     "mac_reconfig_booth_dadda_tb_int4_avg"     "mac_reconfig_booth_dadda_power_int4_avg.rpt"
run_power_report "mac_reconfig_booth_dadda_int8_max.vcd"     "mac_reconfig_booth_dadda_tb_int8_max"     "mac_reconfig_booth_dadda_power_int8_max.rpt"
run_power_report "mac_reconfig_booth_dadda_int8_avg.vcd"     "mac_reconfig_booth_dadda_tb_int8_avg"     "mac_reconfig_booth_dadda_power_int8_avg.rpt"
run_power_report "mac_reconfig_booth_dadda_combined_max.vcd" "mac_reconfig_booth_dadda_tb_combined_max" "mac_reconfig_booth_dadda_power_combined_max.rpt"
run_power_report "mac_reconfig_booth_dadda_combined_avg.vcd" "mac_reconfig_booth_dadda_tb_combined_avg" "mac_reconfig_booth_dadda_power_combined_avg.rpt"

exit
