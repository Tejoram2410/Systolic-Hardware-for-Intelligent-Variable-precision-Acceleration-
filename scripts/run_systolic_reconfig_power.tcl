#-----------------------------------------------------------------------------
# Cadence Genus / Joules Master Synthesis & Power Sign-off TCL Script
# Design: Scalable N x N 2D Reconfigurable Systolic Array Architecture (N=4)
# Target RTL: rtl/mac_reconfig_2d_baugh_wooley.sv, rtl/systolic_array_reconfig_nxn.sv
# PDK: SCL 180nm Standard Cell Library (tsl18fs120_scl_ss.lib)
# Clock: 100 MHz (10.0 ns Period)
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db hdl_max_loop_limit 4096
set_db auto_ungroup both
set_db lp_power_analysis_effort high
set_db lp_insert_clock_gating true

file mkdir report_files
file mkdir output_files

# Step 1: Synthesis
puts "\n=================================================================="
puts " STEP 1: READING & ELABORATING SYSTOLIC ARRAY RECONFIGURABLE RTL (N=16, 256 PEs)"
puts "=================================================================="
read_hdl -sv -define SCL_PDK_SIM rtl/mac_reconfig_2d_baugh_wooley.sv rtl/systolic_array_reconfig_nxn.sv
elaborate systolic_array_reconfig_nxn -parameters {N 16}

set_db [get_db designs] .lp_power_optimization_weight 1.0

create_clock -period 10.0 [get_ports clk]
set_clock_uncertainty 0.2 [get_clocks clk]
set_input_delay -clock clk 2.0 [all_inputs]
set_output_delay -clock clk 2.0 [all_outputs]

puts "\n=================================================================="
puts " STEP 2: RUNNING SYNTHESIS & POWER OPTIMIZATION (SCL 180nm)"
puts "=================================================================="
syn_gen
syn_map
syn_opt

write_hdl systolic_array_reconfig_nxn > output_files/systolic_array_reconfig_nxn_netlist.v
write_sdc systolic_array_reconfig_nxn > output_files/systolic_array_reconfig_nxn.sdc

report_area > report_files/systolic_reconfig_area.rpt
report_timing > report_files/systolic_reconfig_timing.rpt
report_clock_gating > report_files/systolic_reconfig_clock_gating.rpt

puts "\n=== SYNTHESIS COMPLETE: Netlist written to output_files/systolic_array_reconfig_nxn_netlist.v ==="

# Step 3: Procedure to read VCD stimulus and generate Joules/Genus Power Reports
proc run_power_report {vcd_file top_tb report_name} {
    puts "\n------------------------------------------------------------------"
    puts " RUNNING POWER SIGN-OFF: $report_name (VCD: $vcd_file)"
    puts "------------------------------------------------------------------"
    if {[file exists $vcd_file]} {
        if {[llength [get_db designs]] > 0} {
            delete_obj [get_db designs]
        }
        read_hdl -v2001 output_files/systolic_array_reconfig_nxn_netlist.v
        elaborate systolic_array_reconfig_nxn
        read_stimulus -file $vcd_file -dut_instance /$top_tb/dut
        propagate_activity
        report_power > report_files/$report_name
        puts ">>> Successfully generated report: report_files/$report_name"
    } else {
        puts "WARNING: Stimulus file $vcd_file not found. Skipping power calculation for $report_name."
    }
}

# Generate Power Reports
run_power_report "systolic_array_reconfig_nxn_power_max.vcd" "systolic_array_reconfig_nxn_tb_power_max" "systolic_reconfig_power_max.rpt"
run_power_report "systolic_array_reconfig_nxn_power_avg.vcd" "systolic_array_reconfig_nxn_tb_power_avg" "systolic_reconfig_power_avg.rpt"

puts "\n=================================================================="
puts " ALL POWER SIGN-OFF CALCULATIONS COMPLETED!"
puts "==================================================================\n"
exit
