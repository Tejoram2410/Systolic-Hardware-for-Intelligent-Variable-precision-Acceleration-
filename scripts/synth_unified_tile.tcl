#-----------------------------------------------------------------------------
# Cadence Genus Master Synthesis Script: Unified INTxINT / FPxFP / INTxFP MAC Tile
# Target: 2x2 Reconfigurable MAC Tile (12 Operational Modes)
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db hdl_max_loop_limit 8192
set_db auto_ungroup both
set_db lp_power_analysis_effort high
set_db lp_insert_clock_gating false

file mkdir report_files
file mkdir output_files

puts "\n=================================================================="
puts " STEP 1: READING & ELABORATING UNIFIED MAC TILE (12-MODE DESIGN)"
puts "=================================================================="
if {[llength [get_db designs]] > 0} {
    delete_obj [get_db designs]
}

read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_unified_tile.sv
elaborate mac_reconfig_unified_tile

set_db [get_db designs] .lp_power_optimization_weight 1.0

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
write_hdl mac_reconfig_unified_tile > output_files/mac_unified_tile_netlist.v
write_sdc mac_reconfig_unified_tile > output_files/mac_unified_tile.sdc

# Generate Area, Timing, and Power Reports
report_area > report_files/unified_tile_area.rpt
report_timing -max_paths 20 > report_files/unified_tile_timing.rpt
report_clock_gating > report_files/unified_tile_clock_gating.rpt

puts "\n=================================================================="
puts "  GENUS SYNTHESIS & NETLIST COMPLETED FOR UNIFIED 12-MODE MAC TILE!"
puts "  Netlist written to: output_files/mac_unified_tile_netlist.v"
puts "==================================================================\n"
exit
