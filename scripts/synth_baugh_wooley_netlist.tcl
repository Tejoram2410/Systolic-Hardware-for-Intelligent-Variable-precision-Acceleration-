#-----------------------------------------------------------------------------
# Cadence Genus Synthesis Script for mac_reconfig_baugh_wooley
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db hdl_max_loop_limit 1024
set_db auto_ungroup both
set_db lp_power_analysis_effort high
set_db lp_insert_clock_gating true

file mkdir report_files
file mkdir output_files

read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_baugh_wooley.sv
elaborate mac_reconfig_baugh_wooley

set_db [get_db designs] .lp_power_optimization_weight 1.0

# Timing Constraints (100 MHz Clock)
create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]

syn_gen
syn_map
syn_opt

# Write Outputs
write_hdl mac_reconfig_baugh_wooley > output_files/mac_reconfig_baugh_wooley_netlist.v
write_sdc mac_reconfig_baugh_wooley > output_files/mac_reconfig_baugh_wooley.sdc

report_area > report_files/mac_reconfig_baugh_wooley_area.rpt
report_timing > report_files/mac_reconfig_baugh_wooley_timing.rpt
report_clock_gating > report_files/mac_reconfig_baugh_wooley_clock_gating.rpt
report_gates > report_files/mac_reconfig_baugh_wooley_gates.rpt
report_power > report_files/mac_reconfig_baugh_wooley_synth_power.rpt

puts "\n========================================================"
puts "  GENUS LOW-POWER SYNTHESIS & NETLIST COMPLETED!"
puts "========================================================\n"
exit
