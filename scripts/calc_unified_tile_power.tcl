#-----------------------------------------------------------------------------
# Cadence Genus / Joules Power Sign-Off Script: Unified MAC Tile (12 Modes)
# PDK: SCL 180nm (tsl18fs120_scl_ss.lib) | Target Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high

file mkdir report_files

read_hdl -v2001 output_files/mac_unified_tile_netlist.v
elaborate mac_reconfig_unified_tile

if {[file exists "mac_unified_tile_power.vcd"]} {
    puts "\n------------------------------------------------------------------"
    puts " RUNNING JOULES POWER SIGN-OFF: Unified 12-Mode MAC Tile"
    puts "------------------------------------------------------------------"
    read_stimulus -file mac_unified_tile_power.vcd -dut_instance /mac_reconfig_unified_tile_power_tb/dut
    propagate_activity
    report_power > report_files/unified_tile_power.rpt
    puts ">>> Successfully generated report: report_files/unified_tile_power.rpt"
} else {
    puts "ERROR: Stimulus file mac_unified_tile_power.vcd not found."
}

puts "\n=================================================================="
puts "  UNIFIED MAC TILE POWER SIGN-OFF COMPLETED!"
puts "==================================================================\n"
exit
