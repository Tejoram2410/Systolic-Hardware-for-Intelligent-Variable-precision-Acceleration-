#-----------------------------------------------------------------------------
# Cadence Joules / Genus Power Calculation: 45nm NanGate / FreePDK45 @ 500 MHz
#-----------------------------------------------------------------------------

set_db library /opt/rh/progs/cadence/FOUNDRY/digital/45nm/NangateOpenCellLibrary_v1.00_20080225/liberty/FreePDK45_lib_v1.0_typical.lib
set_db lp_power_analysis_effort high

file mkdir report_files_45nm

proc run_tile_power {netlist_file module_name vcd_file report_name} {
    puts "\n------------------------------------------------------------------"
    puts " RUNNING 45nm TILE POWER ANALYSIS: $module_name ($report_name)"
    puts "------------------------------------------------------------------"
    if {[file exists $vcd_file] && [file exists $netlist_file]} {
        if {[llength [get_db designs]] > 0} {
            delete_obj [get_db designs]
        }
        read_hdl -v2001 $netlist_file
        elaborate $module_name
        read_stimulus -file $vcd_file -dut_instance /mac_reconfig_tile_power_tb/dut
        propagate_activity
        
        # 1. Summary Report
        report_power > report_files_45nm/$report_name
        
        # 2. Hierarchical & Flat Detailed Power Breakdown
        catch { report_power -hierarchy > report_files_45nm/${report_name}_hier.rpt }
        catch { report_power -flat > report_files_45nm/${report_name}_flat.rpt }
        catch { report_power -depth 2 > report_files_45nm/${report_name}_depth2.rpt }
        catch { report_gates > report_files_45nm/${report_name}_gates.rpt }
        
        puts ">>> Successfully generated 45nm power report: report_files_45nm/$report_name"
    } else {
        puts "ERROR: Netlist $netlist_file or VCD $vcd_file not found."
    }
}

# 1. Baseline Tile Power Analysis
run_tile_power "output_files_45nm/tile_baseline_netlist.v" "mac_reconfig_2d_baugh_wooley_baseline" "tile_baseline_power_45nm.vcd" "tile_baseline_power.rpt"

# 2. Optimized Tile Power Analysis
run_tile_power "output_files_45nm/tile_opt_netlist.v" "mac_reconfig_2d_baugh_wooley" "tile_opt_power_45nm.vcd" "tile_opt_power.rpt"

puts "\n=================================================================="
puts "  45nm TILE POWER SIGN-OFF COMPLETED FOR BOTH TILES!"
puts "==================================================================\n"
exit
