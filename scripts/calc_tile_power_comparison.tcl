#-----------------------------------------------------------------------------
# Cadence Joules / Genus Power Calculation: Standalone Tile Comparative Sign-Off
# Computes Dynamic & Leakage Power for Baseline vs Optimized 2x2 MAC Tiles
# PDK: SCL 180nm | Frequency: 100 MHz
#-----------------------------------------------------------------------------

set_db library /opt/C2S_Work/sclpdkv3/SCLPDK_V3.0_KIT/scl180/stdcell/fs120/6M1L/liberty/lib_flow_ss/tsl18fs120_scl_ss.lib
set_db lp_power_analysis_effort high

file mkdir report_files

# Save help output for report_power to inspect exact Cadence 20.11 options
catch { help report_power > report_files/genus_help_report_power.txt }

proc run_tile_power {netlist_file module_name vcd_file report_name} {
    puts "\n------------------------------------------------------------------"
    puts " RUNNING TILE POWER ANALYSIS: $module_name ($report_name)"
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
        report_power > report_files/$report_name
        
        # 2. Hierarchical & Flat Detailed Power Breakdown
        catch { report_power -hierarchy > report_files/${report_name}_hier.rpt }
        catch { report_power -flat > report_files/${report_name}_flat.rpt }
        catch { report_power -depth 2 > report_files/${report_name}_depth2.rpt }
        catch { report_gates > report_files/${report_name}_gates.rpt }
        
        puts ">>> Successfully generated detailed power reports: report_files/$report_name"
    } else {
        puts "ERROR: Netlist $netlist_file or VCD $vcd_file not found."
    }
}

# 1. Baseline Tile Power Analysis
run_tile_power "output_files/tile_baseline_netlist.v" "mac_reconfig_2d_baugh_wooley_baseline" "tile_baseline_power.vcd" "tile_baseline_power.rpt"

# 2. Optimized Tile Power Analysis
run_tile_power "output_files/tile_opt_netlist.v" "mac_reconfig_2d_baugh_wooley" "tile_opt_power.vcd" "tile_opt_power.rpt"

puts "\n=================================================================="
puts "  TILE POWER SIGN-OFF COMPLETED FOR BOTH TILES!"
puts "==================================================================\n"
exit
