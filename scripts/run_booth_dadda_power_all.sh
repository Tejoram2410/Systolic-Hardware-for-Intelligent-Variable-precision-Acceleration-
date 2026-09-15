#!/bin/bash
# End-to-End Power Sign-Off Runner for mac_reconfig_booth_dadda
set -e

echo "=========================================================="
echo " STEP 1: Synthesizing New Netlist in Cadence Genus"
echo "=========================================================="
cat << 'EOF' > scripts/synth_booth_dadda_netlist.tcl
set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
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
exit
EOF

genus -batch -files scripts/synth_booth_dadda_netlist.tcl

echo "=========================================================="
echo " STEP 2: Running 6 Gate-Level Simulations in Xcelium (VCD Dumps)"
echo "=========================================================="
SCL_SIM_MODEL="/opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/verilog/vcs_sim_model/tsl18fs120_scl.v"
NETLIST="output_files/mac_reconfig_booth_dadda_netlist.v"

xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_tb_int4_max.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_tb_int4_avg.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_tb_int8_max.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_tb_int8_avg.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_tb_combined_max.sv +access+r
xrun -sv $SCL_SIM_MODEL $NETLIST tb/mac_reconfig_booth_dadda_tb_combined_avg.sv +access+r

echo "=========================================================="
echo " STEP 3: Running Genus Joules Power Sign-Off on Fresh VCDs"
echo "=========================================================="
cat << 'EOF' > scripts/calc_booth_dadda_power.tcl
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
EOF

genus -batch -files scripts/calc_booth_dadda_power.tcl

echo "=========================================================="
echo " ALL 6 POWER REPORTS GENERATED SUCCESSFULLY!"
echo "=========================================================="
