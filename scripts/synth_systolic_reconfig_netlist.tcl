#-----------------------------------------------------------------------------
# Cadence Genus Master Synthesis Script for Scalable Reconfigurable Systolic Array
# Target: N = 16 (256 Physical PEs, 64 Tiles)
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
# Optimization: Hierarchical preservation & fast modular synthesis
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db hdl_max_loop_limit 8192

# Preserve tile hierarchy to synthesize 256 PEs fast (prevents flat state explosion)
set_db auto_ungroup none
set_db dp_sharing none
set_db lp_power_analysis_effort high
set_db lp_insert_clock_gating true

file mkdir report_files
file mkdir output_files

puts "\n=================================================================="
puts " STEP 1: READING & ELABORATING SYSTOLIC ARRAY RECONFIGURABLE RTL (N=16, 256 PEs)"
puts "=================================================================="
read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_2d_baugh_wooley.sv rtl/systolic_array_reconfig_nxn.sv
elaborate systolic_array_reconfig_nxn

set_db [get_db designs] .lp_power_optimization_weight 0.5

# 100 MHz Timing Constraints
create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 2.0 [all_outputs]

puts "\n=================================================================="
puts " STEP 2: RUNNING SYNTHESIS & POWER OPTIMIZATION (SCL 180nm)"
puts "=================================================================="
syn_gen
syn_map
syn_opt

# Write Gate-Level Netlist and Constraints
write_hdl systolic_array_reconfig_nxn > output_files/systolic_array_reconfig_nxn_netlist.v
write_sdc systolic_array_reconfig_nxn > output_files/systolic_array_reconfig_nxn.sdc

# Generate Area, Timing, and Clock-Gating Reports
report_area > report_files/systolic_reconfig_area.rpt
report_timing > report_files/systolic_reconfig_timing.rpt
report_clock_gating > report_files/systolic_reconfig_clock_gating.rpt

puts "\n=================================================================="
puts "  GENUS LOW-POWER SYNTHESIS & NETLIST COMPLETED FOR N=16 (256 PEs)!"
puts "  Netlist written to: output_files/systolic_array_reconfig_nxn_netlist.v"
puts "==================================================================\n"
exit
