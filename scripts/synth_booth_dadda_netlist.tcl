set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db hdl_max_loop_limit 1024
set_db auto_ungroup both
set_db lp_power_analysis_effort high
file mkdir report_files
file mkdir output_files

read_hdl -sv rtl/mac_reconfig_booth_dadda.sv
elaborate mac_reconfig_booth_dadda

set_db [get_db designs] .ungroup_ok true

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
