#-----------------------------------------------------------------------------
# Script: tcl_templates.py
# Description: TCL Script Generators for Xilinx Vivado Project Management, Sim, Synth, Impl & Power
#-----------------------------------------------------------------------------
import os

def normalize_path(path_str):
    """Convert Windows backward slashes to forward slashes for TCL compatibility."""
    return os.path.abspath(path_str).replace("\\", "/")

def generate_create_project_tcl(proj_name, proj_dir, target_part=""):
    """
    Generate TCL script to create a Vivado project if it doesn't already exist.
    Dynamically picks an installed FPGA part if none is specified or matched.
    """
    proj_dir_norm = normalize_path(proj_dir)
    tcl = f"""# Vivado Project Creation TCL Script
set proj_name "{proj_name}"
set proj_dir "{proj_dir_norm}"
set requested_part "{target_part}"

file mkdir $proj_dir

if {{ [file exists "$proj_dir/$proj_name.xpr"] }} {{
    puts "INFO: Vivado project already exists at $proj_dir/$proj_name.xpr"
    open_project "$proj_dir/$proj_name.xpr"
}} else {{
    puts "INFO: Creating new Vivado project '$proj_name' in $proj_dir"
    set avail_parts [get_parts]
    set chosen_part ""
    if {{ $requested_part != "" && [llength [get_parts -quiet $requested_part]] > 0 }} {{
        set chosen_part $requested_part
    }} else {{
        set chosen_part [lindex $avail_parts 0]
        puts "INFO: Target part '$requested_part' not found. Defaulting to installed part '$chosen_part'."
    }}
    create_project $proj_name $proj_dir -part $chosen_part -force
    set_property target_language SystemVerilog [current_project]
    set_property simulator_language Mixed [current_project]
}}
puts "INFO: Project initialization complete."
"""
    return tcl

def generate_sync_sources_tcl(proj_file, rtl_files, tb_files, constraint_files=None):
    """
    Generate TCL script to incrementally add new or modified RTL, TB, and XDC constraint files.
    """
    proj_file_norm = normalize_path(proj_file)
    
    rtl_list_tcl = " ".join([f'"{normalize_path(f)}"' for f in rtl_files])
    tb_list_tcl  = " ".join([f'"{normalize_path(f)}"' for f in tb_files])
    xdc_list_tcl = " ".join([f'"{normalize_path(f)}"' for f in (constraint_files or [])])

    tcl = f"""# Vivado Incremental Source Sync TCL Script
set proj_file "{proj_file_norm}"

if {{ [current_project -quiet] == "" }} {{
    open_project $proj_file
}}

# Sync Synthesizable Design Sources (sources_1)
set existing_src_files [get_files -quiet -of_objects [get_filesets sources_1]]
set target_rtl_files [list {rtl_list_tcl}]
set new_rtl_files [list]

foreach f $target_rtl_files {{
    set found 0
    foreach ef $existing_src_files {{
        if {{ [file tail $f] == [file tail $ef] || $f == $ef }} {{
            set found 1
            break
        }}
    }}
    if {{ !$found && [file exists $f] }} {{
        lappend new_rtl_files $f
    }}
}}

if {{ [llength $new_rtl_files] > 0 }} {{
    puts "INFO: Adding new RTL files to sources_1: $new_rtl_files"
    add_files -fileset sources_1 $new_rtl_files
    foreach f $new_rtl_files {{
        if {{ [file extension $f] == ".sv" }} {{
            set_property file_type {{SystemVerilog}} [get_files $f]
        }}
    }}
}} else {{
    puts "INFO: All RTL design files are already present in project."
}}

# Sync Testbench Sources (sim_1)
set existing_sim_files [get_files -quiet -of_objects [get_filesets sim_1]]
set target_tb_files [list {tb_list_tcl}]
set new_tb_files [list]

foreach f $target_tb_files {{
    set found 0
    foreach ef $existing_sim_files {{
        if {{ [file tail $f] == [file tail $ef] || $f == $ef }} {{
            set found 1
            break
        }}
    }}
    if {{ !$found && [file exists $f] }} {{
        lappend new_tb_files $f
    }}
}}

if {{ [llength $new_tb_files] > 0 }} {{
    puts "INFO: Adding new TB files to sim_1: $new_tb_files"
    add_files -fileset sim_1 $new_tb_files
    foreach f $new_tb_files {{
        if {{ [file extension $f] == ".sv" }} {{
            set_property file_type {{SystemVerilog}} [get_files $f]
        }}
    }}
}} else {{
    puts "INFO: All Testbench files are already present in project."
}}

# Sync Constraints Sources (constrs_1)
set existing_xdc_files [get_files -quiet -of_objects [get_filesets constrs_1]]
set target_xdc_files [list {xdc_list_tcl}]
set new_xdc_files [list]

foreach f $target_xdc_files {{
    set found 0
    foreach ef $existing_xdc_files {{
        if {{ [file tail $f] == [file tail $ef] || $f == $ef }} {{
            set found 1
            break
        }}
    }}
    if {{ !$found && [file exists $f] }} {{
        lappend new_xdc_files $f
    }}
}}

if {{ [llength $new_xdc_files] > 0 }} {{
    puts "INFO: Adding new XDC constraint files to constrs_1: $new_xdc_files"
    add_files -fileset constrs_1 $new_xdc_files
}} else {{
    puts "INFO: All Constraint files are already present in project."
}}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
save_project_as -force $proj_file
puts "INFO: Source sync complete."
"""
    return tcl

def generate_run_sim_tcl(proj_file, top_tb, sim_time="1000ns"):
    """
    Generate TCL script to run behavioral simulation using Vivado xsim.
    """
    proj_file_norm = normalize_path(proj_file)

    tcl = f"""# Vivado Behavioral Simulation TCL Script
set proj_file "{proj_file_norm}"
set top_tb "{top_tb}"

if {{ [current_project -quiet] == "" }} {{
    open_project $proj_file
}}

set_property top $top_tb [get_filesets sim_1]
update_compile_order -fileset sim_1

puts "INFO: Launching behavioral simulation for top testbench: $top_tb"
launch_simulation -mode behavioral -simset sim_1

# Run simulation
restart
run {sim_time}
close_sim -quiet
puts "INFO: Behavioral simulation completed successfully."
"""
    return tcl

def generate_open_wave_tcl(proj_file, top_tb, wdb_file):
    """
    Generate TCL script to open pre-simulated waveform database (.wdb) directly in Vivado GUI.
    """
    proj_norm = normalize_path(proj_file)
    wdb_norm  = normalize_path(wdb_file)
    tcl = f"""# Vivado Open Waveform Database TCL Script
open_project "{proj_norm}"
set_property top {top_tb} [get_filesets sim_1]
update_compile_order -fileset sim_1

if {{ [file exists "{wdb_norm}"] }} {{
    puts "INFO: Opening pre-simulated waveform database: {wdb_norm}"
    open_wave_database "{wdb_norm}"
    add_wave /
}} else {{
    puts "WARNING: Waveform file {wdb_norm} not found. Launching behavioral simulation..."
    launch_simulation -mode behavioral -simset sim_1
}}
"""
    return tcl

def generate_full_synth_impl_power_tcl(proj_file, top_module, xdc_file=""):
    """
    Generate TCL script to set top module, synthesize out-of-context, run implementation,
    and export Utilization, Timing, and Power reports.
    """
    proj_norm = normalize_path(proj_file)
    xdc_norm  = normalize_path(xdc_file) if xdc_file else ""

    tcl = f"""# Vivado Synthesis, Implementation & Power Reporting TCL Script
set proj_file "{proj_norm}"
set top_module "{top_module}"
set xdc_file "{xdc_norm}"

if {{ [current_project -quiet] == "" }} {{
    open_project $proj_file
}}

# Set Top Module
set_property top $top_module [get_filesets sources_1]
update_compile_order -fileset sources_1

puts "INFO: Running Out-Of-Context Synthesis for top module '$top_module'..."
synth_design -top $top_module -mode out_of_context

if {{ $xdc_file != "" && [file exists $xdc_file] }} {{
    puts "INFO: Reading constraint file: $xdc_file"
    read_xdc $xdc_file
}}

puts "INFO: Running Logic Optimization (opt_design)..."
opt_design

puts "INFO: Running Placement (place_design)..."
place_design

puts "INFO: Running Routing (route_design)..."
route_design

puts "INFO: Generating Post-Implementation Reports..."
report_utilization -file "${{top_module}}_utilization_impl.rpt"
report_timing_summary -file "${{top_module}}_timing_impl.rpt"
report_power -file "${{top_module}}_power_impl.rpt"

puts "INFO: Full Synthesis, Implementation, and Power Reporting Completed Successfully!"
"""
    return tcl
