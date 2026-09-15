#-----------------------------------------------------------------------------
# Cadence Genus Synthesis Script: 45nm NanGate / FreePDK45
# Baseline Tile vs. Optimized Tile
# PDK: 45nm (FreePDK45_lib_v1.0_typical.lib) | Frequency: 500 MHz (2.0 ns)
#-----------------------------------------------------------------------------

set_db library /opt/rh/progs/cadence/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/liberty/FreePDK45_lib_v1.0_typical.lib
set_db hdl_max_loop_limit 8192
set_db lp_power_analysis_effort high
set_db lp_insert_clock_gating true
set_db lp_insert_discrete_clock_gating_logic true

file mkdir report_files_45nm
file mkdir output_files_45nm

#=============================================================================
# 1. Synthesize Baseline 2D MAC Tile (45nm @ 500 MHz)
#=============================================================================
puts "\n=================================================================="
puts " SYNTHESIZING BASELINE TILE ON 45nm (mac_reconfig_2d_baugh_wooley_baseline)"
puts "=================================================================="
if {[llength [get_db designs]] > 0} {
    delete_obj [get_db designs]
}

read_hdl -sv rtl/mac_reconfig_2d_baugh_wooley_baseline.sv
elaborate mac_reconfig_2d_baugh_wooley_baseline

set_db [get_db designs] .lp_power_optimization_weight 0.5

create_clock -period 2.0 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay -clock clk 0.4 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 0.4 [all_outputs]

syn_gen
syn_map
syn_opt

write_hdl mac_reconfig_2d_baugh_wooley_baseline > output_files_45nm/tile_baseline_netlist.v
write_sdc mac_reconfig_2d_baugh_wooley_baseline > output_files_45nm/tile_baseline.sdc

report_area > report_files_45nm/tile_baseline_area.rpt
catch { report_gates > report_files_45nm/tile_baseline_gates.rpt }
report_timing -max_paths 10 > report_files_45nm/tile_baseline_timing.rpt
report_clock_gating > report_files_45nm/tile_baseline_clock_gating.rpt

#=============================================================================
# 2. Synthesize Optimized 2D MAC Tile (45nm @ 500 MHz)
#=============================================================================
puts "\n=================================================================="
puts " SYNTHESIZING OPTIMIZED TILE ON 45nm (mac_reconfig_2d_baugh_wooley)"
puts "=================================================================="
if {[llength [get_db designs]] > 0} {
    delete_obj [get_db designs]
}

read_hdl -sv rtl/mac_reconfig_2d_baugh_wooley.sv
elaborate mac_reconfig_2d_baugh_wooley

set_db [get_db designs] .lp_power_optimization_weight 0.5

create_clock -period 2.0 [get_ports clk]
set_clock_uncertainty 0.05 [get_clocks clk]
set_input_delay -clock clk 0.4 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 0.4 [all_outputs]

syn_gen
syn_map
syn_opt

write_hdl mac_reconfig_2d_baugh_wooley > output_files_45nm/tile_opt_netlist.v
write_sdc mac_reconfig_2d_baugh_wooley > output_files_45nm/tile_opt.sdc

report_area > report_files_45nm/tile_opt_area.rpt
catch { report_gates > report_files_45nm/tile_opt_gates.rpt }
report_timing -max_paths 10 > report_files_45nm/tile_opt_timing.rpt
report_clock_gating > report_files_45nm/tile_opt_clock_gating.rpt

puts "\n=================================================================="
puts "  45nm TILE SYNTHESIS COMPLETED FOR BOTH BASELINE & OPTIMIZED TILES!"
puts "==================================================================\n"
exit
