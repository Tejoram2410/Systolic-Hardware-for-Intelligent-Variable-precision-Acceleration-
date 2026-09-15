# RTL Development & Automated Vivado Simulation Guidelines

Whenever working on Verilog / SystemVerilog / VHDL design tasks in this repository, follow these rules:

1. **Source Code Conventions**:
   - Synthesizable RTL design sources must be placed in `rtl/` (e.g. `rtl/my_module.sv`).
   - Testbenches must be self-checking with pass/fail markers and placed in `tb/` (e.g. `tb/my_module_tb.sv`).

2. **Automated Simulation Workflow**:
   - Always verify design changes by executing:
     ```powershell
     python scripts/vivado_runner.py --sim <testbench_name>
     ```
   - Inspect the generated **HUMAN PERCEPTION REPORT** for errors, assertion failures, or warnings.
   - If tests fail, analyze the root cause in `rtl/` or `tb/`, correct the code, and re-run the simulation command until 100% of tests pass.

3. **Vivado Process Safety**:
   - The automation runner automatically checks for existing Vivado GUI instances and avoids spawning redundant windows or duplicate source file additions.
   - Use `--gui` only when explicit interactive waveform visualization is requested by the user.
