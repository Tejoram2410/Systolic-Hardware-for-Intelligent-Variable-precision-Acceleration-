#-----------------------------------------------------------------------------
# Cadence Genus Power Forensic Script
# Generates Hierarchical, Cell-Type, and Functional-Type Power Breakdowns
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high

file mkdir report_files

proc run_forensic {netlist_file module_name vcd_file prefix} {
    puts "\n=================================================================="
    puts " RUNNING POWER FORENSICS FOR $module_name ($prefix)"
    puts "=================================================================="
    if {[file exists $vcd_file] && [file exists $netlist_file]} {
        if {[llength [get_db designs]] > 0} {
            delete_obj [get_db designs]
        }
        read_hdl -v2001 $netlist_file
        elaborate $module_name
        read_stimulus -file $vcd_file -dut_instance /mac_reconfig_tile_power_tb/dut
        propagate_activity
        
        catch { report_power -by_hierarchy > report_files/${prefix}_power_by_hierarchy.rpt }
        catch { report_power -by_libcell > report_files/${prefix}_power_by_libcell.rpt }
        catch { report_power -by_func_type > report_files/${prefix}_power_by_functype.rpt }
        puts ">>> Generated forensic reports for $prefix"
    } else {
        puts "ERROR: $netlist_file or $vcd_file not found"
    }
}

# 1. Baseline Forensic Power Analysis
run_forensic "output_files/tile_baseline_netlist.v" "mac_reconfig_2d_baugh_wooley_baseline" "tile_baseline_power.vcd" "baseline"

# 2. Optimized Forensic Power Analysis
run_forensic "output_files/tile_opt_netlist.v" "mac_reconfig_2d_baugh_wooley" "tile_opt_power.vcd" "opt"

puts "\n=================================================================="
puts " POWER FORENSIC ANALYSIS COMPLETED!"
puts "==================================================================\n"
exit
