#-----------------------------------------------------------------------------
# Cadence Genus Synthesis Script: Standalone Tile Comparative Benchmark
# Baseline Tile vs. Optimized Tile (In-Situ CSA Fusion + Segmented Accumulator)
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db hdl_max_loop_limit 8192
set_db lp_power_analysis_effort high
set_db lp_insert_clock_gating true

file mkdir report_files
file mkdir output_files

# Save help output for report_power to inspect exact Cadence 20.11 options
catch { help report_power > report_files/genus_help_report_power.txt }
catch { help report_area > report_files/genus_help_report_area.txt }

#=============================================================================
# 1. Synthesize Baseline 2D MAC Tile
#=============================================================================
puts "\n=================================================================="
puts " SYNTHESIZING BASELINE TILE (mac_reconfig_2d_baugh_wooley_baseline)"
puts "=================================================================="
if {[llength [get_db designs]] > 0} {
    delete_obj [get_db designs]
}

read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_2d_baugh_wooley_baseline.sv
elaborate mac_reconfig_2d_baugh_wooley_baseline

set_db [get_db designs] .lp_power_optimization_weight 0.5

create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 2.0 [all_outputs]

syn_gen
syn_map
syn_opt

write_hdl mac_reconfig_2d_baugh_wooley_baseline > output_files/tile_baseline_netlist.v
write_sdc mac_reconfig_2d_baugh_wooley_baseline > output_files/tile_baseline.sdc

report_area > report_files/tile_baseline_area.rpt
catch { report_gates > report_files/tile_baseline_gates.rpt }
report_timing -max_paths 10 > report_files/tile_baseline_timing.rpt
report_clock_gating > report_files/tile_baseline_clock_gating.rpt

#=============================================================================
# 2. Synthesize Optimized 2D MAC Tile (In-Situ CSA Fusion + Segmented Accumulator)
#=============================================================================
puts "\n=================================================================="
puts " SYNTHESIZING OPTIMIZED TILE (mac_reconfig_2d_baugh_wooley)"
puts "=================================================================="
if {[llength [get_db designs]] > 0} {
    delete_obj [get_db designs]
}

read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_2d_baugh_wooley.sv
elaborate mac_reconfig_2d_baugh_wooley

set_db [get_db designs] .lp_power_optimization_weight 0.5

create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 2.0 [all_outputs]

syn_gen
syn_map
syn_opt

write_hdl mac_reconfig_2d_baugh_wooley > output_files/tile_opt_netlist.v
write_sdc mac_reconfig_2d_baugh_wooley > output_files/tile_opt.sdc

report_area > report_files/tile_opt_area.rpt
catch { report_gates > report_files/tile_opt_gates.rpt }
report_timing -max_paths 10 > report_files/tile_opt_timing.rpt
report_clock_gating > report_files/tile_opt_clock_gating.rpt

puts "\n=================================================================="
puts "  TILE SYNTHESIS COMPLETED FOR BOTH BASELINE & OPTIMIZED TILES!"
puts "==================================================================\n"
exit
