#-----------------------------------------------------------------------------
# Cadence Genus Master Synthesis Script: Full 16x16 Array Comparative Benchmark
# Baseline Array (64 Baseline Tiles) vs. Optimized Array (64 Optimized Tiles)
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db hdl_max_loop_limit 8192

# Preserve tile hierarchy for fast modular synthesis (prevents flat state explosion)
set_db auto_ungroup none
set_db dp_sharing none
set_db lp_power_analysis_effort high
set_db lp_insert_clock_gating true

file mkdir report_files
file mkdir output_files

#=============================================================================
# 1. Synthesize Baseline 16x16 Systolic Array (256 PEs, 64 Baseline Tiles)
#=============================================================================
puts "\n=================================================================="
puts " SYNTHESIZING BASELINE 16x16 ARRAY (systolic_array_reconfig_nxn_baseline)"
puts "=================================================================="
if {[llength [get_db designs]] > 0} {
    delete_obj [get_db designs]
}

read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_2d_baugh_wooley_baseline.sv rtl/systolic_array_reconfig_nxn_baseline.sv
elaborate systolic_array_reconfig_nxn_baseline

set_db [get_db designs] .lp_power_optimization_weight 0.5

create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 2.0 [all_outputs]

syn_gen
syn_map
syn_opt

write_hdl systolic_array_reconfig_nxn_baseline > output_files/systolic_baseline_netlist.v
write_sdc systolic_array_reconfig_nxn_baseline > output_files/systolic_baseline.sdc

report_area > report_files/systolic_baseline_area.rpt
report_timing -max_paths 20 > report_files/systolic_baseline_timing.rpt
report_clock_gating > report_files/systolic_baseline_clock_gating.rpt

#=============================================================================
# 2. Synthesize Optimized 16x16 Systolic Array (256 PEs, 64 Optimized Tiles)
#=============================================================================
puts "\n=================================================================="
puts " SYNTHESIZING OPTIMIZED 16x16 ARRAY (systolic_array_reconfig_nxn)"
puts "=================================================================="
if {[llength [get_db designs]] > 0} {
    delete_obj [get_db designs]
}

read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_2d_baugh_wooley.sv rtl/systolic_array_reconfig_nxn.sv
elaborate systolic_array_reconfig_nxn

set_db [get_db designs] .lp_power_optimization_weight 0.5

create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay -clock clk 2.0 [all_outputs]

syn_gen
syn_map
syn_opt

write_hdl systolic_array_reconfig_nxn > output_files/systolic_opt_netlist.v
write_sdc systolic_array_reconfig_nxn > output_files/systolic_opt.sdc

report_area > report_files/systolic_opt_area.rpt
report_timing -max_paths 20 > report_files/systolic_opt_timing.rpt
report_clock_gating > report_files/systolic_opt_clock_gating.rpt

puts "\n=================================================================="
puts "  FULL ARRAY SYNTHESIS COMPLETED FOR BOTH BASELINE & OPTIMIZED ARRAYS!"
puts "==================================================================\n"
exit
