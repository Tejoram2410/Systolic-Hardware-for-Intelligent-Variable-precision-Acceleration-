#-----------------------------------------------------------------------------
# Cadence Genus Master 6-Mode Power Sign-off TCL Script
# Design: Strict 4-Wire Radix-4 Booth & Reconfigurable Dadda Tree MAC Architecture
# Target RTL: rtl/mac_reconfig_booth_dadda.sv
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib)
# Modes Analyzed:
#   1. INT4 Maximum Power  (int4_max)
#   2. INT4 Average Power  (int4_avg)
#   3. INT8 Maximum Power  (int8_max)
#   4. INT8 Average Power  (int8_avg)
#   5. Combined Max Power  (combined_max)
#   6. Combined Avg Power  (combined_avg)
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high
set_db hdl_max_loop_limit 1024

file mkdir report_files
file mkdir output_files

read_hdl -sv rtl/mac_reconfig_booth_dadda.sv
elaborate mac_reconfig_booth_dadda

create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]

syn_gen
syn_map
syn_opt

write_hdl mac_reconfig_booth_dadda > output_files/mac_reconfig_booth_dadda_netlist.v
write_sdc mac_reconfig_booth_dadda > output_files/mac_reconfig_booth_dadda.sdc

puts "\n=== SYNTHESIS COMPLETE: Gate netlist written out. ===\n"

# Procedure to perform Joules activity propagation and power report
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

puts "\n========================================================"
puts "  ALL 6 BOOTH-DADDA POWER SIGN-OFF REPORTS GENERATED!"
puts "========================================================\n"
exit
