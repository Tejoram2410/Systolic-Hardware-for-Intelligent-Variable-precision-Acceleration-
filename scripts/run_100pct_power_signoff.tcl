#-----------------------------------------------------------------------------
# Cadence Genus 100% Gate-Level Toggle Power Sign-off TCL Script
# Design: Strict 4-Wire Datapath 2x2 PE Reconfigurable MAC Architecture
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib)
#-----------------------------------------------------------------------------

# Step 1: Set Target PDK Liberty Library & Effort
set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high
set_db hdl_max_loop_limit 1024

# Create Output Report Directory
file mkdir report_files
file mkdir output_files

# Step 2: Read RTL & Synthesize Gate-Level Netlist
read_hdl -sv rtl/mac_reconfig_top.sv
elaborate mac_reconfig_top

# Define 100 MHz Clock Constraint (10 ns period)
create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]

# Synthesize to Gates
syn_gen
syn_map
syn_opt

# Write out Synthesized Gate-Level Netlist and Constraints
write_hdl mac_reconfig_top > output_files/mac_reconfig_top_netlist.v
write_sdc mac_reconfig_top > output_files/mac_reconfig_top.sdc

puts "\n========================================================"
puts "  SYNTHESIS COMPLETE: Gate netlist written out."
puts "========================================================\n"

# Step 3: Run True Gate-Level Joules Power Sign-Off for INT4 Mode
puts "\n--- RUNNING INT4 100% GATE-LEVEL POWER SIGN-OFF ---"
delete_obj [get_db designs]
read_hdl -v2001 output_files/mac_reconfig_top_netlist.v
elaborate mac_reconfig_top

read_stimulus -file mac_reconfig_top_int4_gls.vcd -dut_instance /mac_reconfig_top_tb_int4/dut
propagate_activity
report_power > report_files/mac_reconfig_top_power_int4_100pct_gls.rpt

# Step 4: Run True Gate-Level Joules Power Sign-Off for INT8 Mode
puts "\n--- RUNNING INT8 100% GATE-LEVEL POWER SIGN-OFF ---"
read_stimulus -file mac_reconfig_top_int8_gls.vcd -dut_instance /mac_reconfig_top_tb_int8/dut
propagate_activity
report_power > report_files/mac_reconfig_top_power_int8_100pct_gls.rpt

# Step 5: Run True Gate-Level Joules Power Sign-Off for COMBINED INT4/INT8 Dynamic Switching Mode
puts "\n--- RUNNING COMBINED DYNAMIC RECONFIGURATION GATE-LEVEL POWER SIGN-OFF ---"
read_stimulus -file mac_reconfig_top_combined_gls.vcd -dut_instance /mac_reconfig_top_tb_combined/dut
propagate_activity
report_power > report_files/mac_reconfig_top_power_combined_100pct_gls.rpt

puts "\n========================================================"
puts "  100% GATE-LEVEL POWER SIGN-OFF COMPLETE!"
puts "========================================================\n"
exit
