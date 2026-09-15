#-----------------------------------------------------------------------------
# Script: vivado_runner.py
# Description: Automated Vivado RTL Development, Simulation, Synthesis,
#              Implementation & Power Analysis Controller
#-----------------------------------------------------------------------------
import os
import sys
import glob
import subprocess
import re
import argparse
import time
from pathlib import Path

# Add scripts directory to path to import tcl_templates
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
import tcl_templates

# Target Workspace Paths
WORKSPACE_ROOT  = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RTL_DIR         = os.path.join(WORKSPACE_ROOT, "rtl")
TB_DIR          = os.path.join(WORKSPACE_ROOT, "tb")
CONSTRAINTS_DIR = os.path.join(WORKSPACE_ROOT, "constraints")
SIM_DIR         = os.path.join(WORKSPACE_ROOT, "sim")
PROJ_DIR        = os.path.join(WORKSPACE_ROOT, "vivado_proj")
SCRIPTS_DIR     = os.path.join(WORKSPACE_ROOT, "scripts")
PROJ_NAME       = "rtl_project"
PROJ_FILE       = os.path.join(PROJ_DIR, f"{PROJ_NAME}.xpr")

# Known Vivado installation paths
DEFAULT_VIVADO_PATHS = [
    r"C:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat",
    r"C:\AMDDesignTools\2025.1\Vivado\bin\vivado.bat",
    r"C:\Xilinx\Vivado\2025.2\bin\vivado.bat",
    r"C:\Xilinx\Vivado\2024.2\bin\vivado.bat",
]

def find_vivado_bin():
    """Locate the Vivado batch executable."""
    for path in DEFAULT_VIVADO_PATHS:
        if os.path.exists(path):
            return path
    try:
        res = subprocess.run(["where", "vivado"], capture_output=True, text=True, check=True)
        paths = res.stdout.strip().splitlines()
        if paths:
            return paths[0]
    except Exception:
        pass
    return None

def find_vvgl_bin(vivado_bin):
    """Locate Vivado Visual Graphics Launcher (vvgl.exe)."""
    base_dir = os.path.dirname(vivado_bin)
    vvgl_path = os.path.join(base_dir, "unwrapped", "win64.o", "vvgl.exe")
    if os.path.exists(vvgl_path):
        return vvgl_path
    return None

def is_vivado_gui_running():
    """Check if a Vivado GUI process is currently running."""
    try:
        res = subprocess.run(["tasklist", "/FI", "IMAGENAME eq vivado.exe", "/FO", "CSV"],
                             capture_output=True, text=True)
        if "vivado.exe" in res.stdout.lower():
            return True
    except Exception:
        pass
    return False

def kill_stale_vivado_processes():
    """Terminate stale hanging vivado background processes and clean locks."""
    try:
        subprocess.run(["taskkill", "/F", "/IM", "vivado.exe"], capture_output=True)
        subprocess.run(["taskkill", "/F", "/IM", "java.exe"], capture_output=True)
    except Exception:
        pass

    for pattern in ["*.jou", "*.log", "*.str"]:
        for f in glob.glob(os.path.join(PROJ_DIR, pattern)) + glob.glob(os.path.join(SIM_DIR, pattern)):
            try:
                os.remove(f)
            except Exception:
                pass

def scan_sources():
    """Scan rtl/, tb/, and constraints/ directories for source & constraint files."""
    rtl_files = []
    tb_files  = []
    xdc_files = []

    for ext in ("*.sv", "*.v", "*.vhd", "*.vhdl"):
        rtl_files.extend(glob.glob(os.path.join(RTL_DIR, ext)))
        tb_files.extend(glob.glob(os.path.join(TB_DIR, ext)))

    xdc_files.extend(glob.glob(os.path.join(CONSTRAINTS_DIR, "*.xdc")))

    return rtl_files, tb_files, xdc_files

def run_tcl_script(vivado_bin, tcl_content, script_name="run_cmd.tcl"):
    """Write temporary TCL script and execute Vivado headlessly in batch mode."""
    os.makedirs(SIM_DIR, exist_ok=True)
    tcl_path = os.path.join(SIM_DIR, script_name)
    with open(tcl_path, "w", encoding="utf-8") as f:
        f.write(tcl_content)

    log_path = os.path.join(SIM_DIR, "vivado_exec.log")
    cmd = [vivado_bin, "-mode", "batch", "-source", tcl_path, "-log", log_path, "-nojournal"]

    print("[RUNNER] Executing Vivado (mode=batch)...")
    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, cwd=SIM_DIR)
    
    output_lines = []
    for line in process.stdout:
        output_lines.append(line)
        if "INFO:" in line or "ERROR:" in line or "WARNING:" in line or "STATUS:" in line:
            print(f"  | {line.strip()}")
            
    process.wait()
    time.sleep(1)
    return process.returncode, "\n".join(output_lines)

def launch_vivado_gui_wave(vivado_bin, proj_file, top_tb, force_reopen=False):
    """Launch Vivado GUI loading pre-simulated waveform database (.wdb)."""
    if force_reopen:
        kill_stale_vivado_processes()
        time.sleep(0.5)

    vvgl_bin = find_vvgl_bin(vivado_bin)
    wdb_path  = os.path.join(PROJ_DIR, f"{PROJ_NAME}.sim", "sim_1", "behav", "xsim", f"{top_tb}_behav.wdb")
    
    tcl_content = tcl_templates.generate_open_wave_tcl(proj_file, top_tb, wdb_path)
    os.makedirs(SIM_DIR, exist_ok=True)
    tcl_path = os.path.join(SIM_DIR, "open_wave.tcl")
    with open(tcl_path, "w", encoding="utf-8") as f:
        f.write(tcl_content)

    tcl_norm = tcl_templates.normalize_path(tcl_path)
    vivado_bat_target = vivado_bin.replace("\\Vivado\\bin\\vivado.bat", "/Vivado/bin/vivado.bat")

    if vvgl_bin:
        cmd = f'start "" "{vvgl_bin}" {vivado_bat_target} -mode gui -source "{tcl_norm}"'
    else:
        cmd = f'start "" "{vivado_bin}" -mode gui -source "{tcl_norm}"'

    print(f"[RUNNER] Opening Vivado GUI Waveform Viewer for '{top_tb}'...")
    subprocess.Popen(cmd, shell=True, cwd=WORKSPACE_ROOT)

def parse_simulation_logs(proj_dir, proj_name):
    """Locate and parse simulation log files to generate a clean summary."""
    behav_dir = os.path.join(proj_dir, f"{proj_name}.sim", "sim_1", "behav", "xsim")
    log_files = glob.glob(os.path.join(behav_dir, "simulate.log"))
    if not log_files:
        log_files = glob.glob(os.path.join(behav_dir, "*.log"))

    displays = []
    errors   = []
    warnings = []
    pass_found = False
    fail_found = False

    for lf in log_files:
        try:
            with open(lf, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line_clean = line.strip()
                    if "[PASS]" in line_clean or "SIMULATION PASSED" in line_clean:
                        pass_found = True
                    if "[FAIL]" in line_clean or "SIMULATION FAILED" in line_clean:
                        fail_found = True
                    
                    if line_clean.startswith("[PASS]") or line_clean.startswith("[FAIL]"):
                        if line_clean not in displays:
                            displays.append(line_clean)
                    elif line_clean.startswith("STARTING") or line_clean.startswith("Total Tests"):
                        if line_clean not in displays:
                            displays.append(line_clean)
                    elif "ERROR:" in line_clean or "Fatal:" in line_clean or "$error" in line_clean or "$fatal" in line_clean:
                        if line_clean not in errors:
                            errors.append(line_clean)
                    elif "WARNING:" in line_clean:
                        warnings.append(line_clean)
        except Exception:
            pass

    return {
        "pass": pass_found and not fail_found and len(errors) == 0,
        "displays": displays,
        "errors": errors,
        "warnings_count": len(warnings),
        "logs_checked": log_files
    }

def print_formatted_report(sim_results, top_tb):
    """Print human-perceptible simulation report."""
    print("\n" + "="*70)
    print(f"       HUMAN PERCEPTION REPORT: SIMULATION FOR {top_tb.upper()}")
    print("="*70)
    
    status_str = "SUCCESS (PASSED)" if sim_results["pass"] else "FAILED / ERRORS DETECTED"
    print(f"Overall Status   : {status_str}")
    print(f"Warnings Count   : {sim_results['warnings_count']}")
    print(f"Log Files Parsed : {len(sim_results['logs_checked'])}")
    print("-" * 70)
    print("SIMULATION DISPLAY OUTPUTS:")
    if sim_results["displays"]:
        for d in sim_results["displays"]:
            print(f"  {d}")
    else:
        print("  (No $display outputs recorded)")

    if sim_results["errors"]:
        print("-" * 70)
        print("SIMULATION ERRORS:")
        for e in sim_results["errors"]:
            print(f"  ! {e}")

    print("="*70 + "\n")

def parse_and_print_power_report(top_module):
    """Locate and print post-implementation power report summary."""
    power_rpt_files = glob.glob(os.path.join(SIM_DIR, f"{top_module}_power_impl.rpt"))
    if not power_rpt_files:
        power_rpt_files = glob.glob(os.path.join(SIM_DIR, "*power*.rpt"))

    print("\n" + "="*70)
    print(f"       HUMAN PERCEPTION REPORT: POWER ANALYSIS FOR {top_module.upper()}")
    print("="*70)

    if power_rpt_files:
        rpt_file = power_rpt_files[0]
        try:
            with open(rpt_file, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    if "Total On-Chip Power" in line or "Dynamic" in line or "Device Static" in line or "Junction Temperature" in line:
                        print(f"  {line.strip()}")
        except Exception:
            pass
    else:
        print("  (No power report file found)")

    print("="*70 + "\n")

def main():
    parser = argparse.ArgumentParser(description="Automated Vivado RTL Development, Simulation & Power Analysis Controller")
    parser.add_argument("--create-proj", action="store_true", help="Create Vivado project if missing")
    parser.add_argument("--sync", action="store_true", help="Incrementally sync RTL, TB & XDC source files")
    parser.add_argument("--sim", type=str, help="Top testbench module to simulate")
    parser.add_argument("--sim-time", type=str, default="1000ns", help="Simulation run time (e.g. 500ns, 1us)")
    parser.add_argument("--top", type=str, default="mac_reconfig_top", help="Top module for synthesis & implementation")
    parser.add_argument("--flow", type=str, choices=["sim", "impl", "power", "full"], help="Flow to run: sim, impl, power, full")
    parser.add_argument("--gui", action="store_true", help="Open Vivado GUI detached window")
    parser.add_argument("--wave", action="store_true", help="Open pre-simulated waveform database (.wdb) in Vivado GUI")
    parser.add_argument("--force", action="store_true", help="Force close any existing Vivado GUI window before opening")

    args = parser.parse_args()

    vivado_bin = find_vivado_bin()
    if not vivado_bin:
        print("[ERROR] Could not locate Vivado installation binary (vivado.bat).")
        sys.exit(1)

    print(f"[RUNNER] Located Vivado binary: {vivado_bin}")

    sim_target = args.sim if args.sim else "mac_reconfig_top_tb"

    if args.gui or args.wave:
        if is_vivado_gui_running() and not args.force:
            print("[NOTICE] Vivado GUI is already open. Use --force to close it and reopen with the new waveform.")
            launch_vivado_gui_wave(vivado_bin, PROJ_FILE, sim_target, force_reopen=False)
        else:
            launch_vivado_gui_wave(vivado_bin, PROJ_FILE, sim_target, force_reopen=True)
        return

    # Batch Mode Pipeline
    if not os.path.exists(PROJ_FILE) or args.create_proj:
        print("[RUNNER] Initializing Vivado Project...")
        create_tcl = tcl_templates.generate_create_project_tcl(PROJ_NAME, PROJ_DIR)
        run_tcl_script(vivado_bin, create_tcl, "create_proj.tcl")

    rtl_files, tb_files, xdc_files = scan_sources()
    print(f"[RUNNER] Found {len(rtl_files)} RTL files, {len(tb_files)} Testbench files, and {len(xdc_files)} XDC constraint files in workspace.")
    
    sync_tcl = tcl_templates.generate_sync_sources_tcl(PROJ_FILE, rtl_files, tb_files, xdc_files)
    run_tcl_script(vivado_bin, sync_tcl, "sync_sources.tcl")

    # Run Simulation Flow
    if args.flow in [None, "sim", "full"] and args.sim:
        sim_tcl = tcl_templates.generate_run_sim_tcl(PROJ_FILE, args.sim, args.sim_time)
        ret, out = run_tcl_script(vivado_bin, sim_tcl, "run_sim.tcl")
        sim_results = parse_simulation_logs(PROJ_DIR, PROJ_NAME)
        print_formatted_report(sim_results, args.sim)

    # Run Synthesis, Implementation & Power Flow
    if args.flow in ["impl", "power", "full"]:
        xdc_file = xdc_files[0] if xdc_files else ""
        print(f"[RUNNER] Launching Out-of-Context Synthesis, Implementation & Power Analysis for top module '{args.top}'...")
        flow_tcl = tcl_templates.generate_full_synth_impl_power_tcl(PROJ_FILE, args.top, xdc_file)
        run_tcl_script(vivado_bin, flow_tcl, "run_synth_impl_power.tcl")
        parse_and_print_power_report(args.top)

if __name__ == "__main__":
    main()
