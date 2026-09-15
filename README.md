# SHIVA: Systolic Hardware for Intelligent Variable-Precision Acceleration

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Target PDK](https://img.shields.io/badge/PDK-45nm_NanGate_%2F_FreePDK45-blue.svg)]()
[![Clock Frequency](https://img.shields.io/badge/Sign--Off_Clock-500_MHz_(2.0ns)-brightgreen.svg)]()
[![EDA Tools](https://img.shields.io/badge/EDA-Cadence_Genus_%2F_Joules_%2F_Xcelium-red.svg)]()

**SHIVA** (Systolic Hardware for Intelligent Variable-precision Acceleration) is a software-hardware co-designed accelerator framework featuring a **2D Reconfigurable Baugh-Wooley Systolic Macro-Tile**. It supports dynamic mixed-precision quantization across **INT4**, **INT8**, and **NVFP4** (Microscaling E2M1 Block Floating-Point) formats.

The architecture bridges a closed-loop Python quantization model ([`notebooks/nvfp4_microscaling_model.ipynb`](file:///c:/Users/Vigneswar/.gemini/antigravity-ide/scratch/rtl_workspace/notebooks/nvfp4_microscaling_model.ipynb)) with a synthesized **500 MHz 45nm CMOS hardware implementation** ([`rtl/mac_reconfig_2d_baugh_wooley_nvfp4.sv`](file:///c:/Users/Vigneswar/.gemini/antigravity-ide/scratch/rtl_workspace/rtl/mac_reconfig_2d_baugh_wooley_nvfp4.sv)).

---

## 🌟 Key Features

1. **Multi-Precision Reconfigurable MAC Core:**
   - **4x4 SIMD Mode (`mode_2b = 2'b00`):** 4 parallel 4-bit MAC operations with independent 16-bit accumulators.
   - **Dual 8x4 Horizontal Fusion (`mode_2b = 2'b01`):** 2 parallel 8x4 MAC operations with 24-bit row accumulators.
   - **Dual 4x8 Vertical Fusion (`mode_2b = 2'b10`):** 2 parallel 4x8 MAC operations with 24-bit column accumulators.
   - **Unified 8x8 Mode (`mode_2b = 2'b11`):** 1 full 8x8 MAC operation with a 32-bit fused accumulator.

2. **NVFP4 Microscaling E2M1 Format Support:**
   - Supports 4-bit NVFP4 values containing 1 Sign bit ($S$), 2 Exponent bits ($E$), and 1 Mantissa bit ($M$).
   - Represented quantized magnitude levels: `0.0, ±0.5, ±1.0, ±1.5, ±2.0, ±3.0, ±4.0, ±6.0`.
   - Paired with per-block 8-bit scale exponent offsets (`scale_block`) for micro-scaled Block Floating-Point (BFP) execution.

3. **Software-Hardware Co-Design & Adaptive Trajectory:**
   - closed-loop profiling on LLMs (e.g., Qwen2.5-0.5B across 24 layers, $32 \times 32$ macro-tile partitions).
   - Tracks an online error state register $S$ driven by activation quantization error to dynamically update thresholds:
     $$\tau_{dyn} = \tau_{base} \cdot e^{-\gamma S} \cdot \text{depth\_prior}$$
   - Hardware Tile Comparator (`Cost = ΔW · Φ(X) · S_base`) adaptively assigns INT4, NVFP4 (E2M1), or INT8 formats to weight tiles based on empirical sensitivity.

4. **Low-Power RTL Architectural Innovations:**
   - **Pre-Computed 2s-Complement LUT (`nvfp4_e2m1_remapper`):** Directly maps NVFP4 to 4-bit 2s-complement signed integers with zero runtime adders.
   - **Dual-Rail Input Gating:** Freezes unused operand paths to `4'b0000` when inactive, completely halting dynamic switching power in non-active modes.
   - **Glitch-Free OR Combining:** Replaces 2:1 multiplexers with bitwise 2-input OR gates (`a0_in = int_a0_raw | rem_a0`), eliminating MUX select line switching overhead and logic glitching.
   - **Direct Input-Muxed Accumulator Core:** Minimizes logic depth and avoids MUX tree standard cell bloat.

---

## 📐 Hardware Architecture

### Tile Module Interaction & Datapath

```
                    +---------------------------------------------------+
                    |                Input Operands & Modes             |
                    | A0..A3, B0..B3, mode_2b[1:0], is_nvfp4[1:0]       |
                    +-------------------------+-------------------------+
                                              |
                                              v
                    +---------------------------------------------------+
                    |    Dual-Rail Operand Isolation & Gating           |
                    | (Freezes inactive paths to 4'b0000 during INT4/NVFP4) |
                    +--------------------+------------------------------+
                                         |
                       +-----------------+-----------------+
                       |                                   |
                       v                                   v
        +-----------------------------+     +-----------------------------+
        |  nvfp4_e2m1_remapper (LUT)  |     |  Direct INT4 Pass-Through   |
        |  (Zero Runtime Adders)      |     |  Path                       |
        +--------------+--------------+     +--------------+--------------+
                       |                                   |
                       +-----------------+-----------------+
                                         |
                                         v
                    +---------------------------------------------------+
                    | Bitwise OR Combiner (Glitch-Free Gate Replacement)|
                    | a0_in = int_a0_raw | rem_a0                       |
                    +--------------------+------------------------------+
                                         |
                                         v
                    +---------------------------------------------------+
                    | 2x2 Array of Baugh-Wooley 4-bit Multiplier PEs    |
                    | (nvfp4_baugh_wooley_4b_pe u_pe00 .. u_pe11)       |
                    +--------------------+------------------------------+
                                         |
                                         v
                    +---------------------------------------------------+
                    | Partial Product Merge Units (mergeA, mergeB, P_8b)|
                    +--------------------+------------------------------+
                                         |
                                         v
                    +---------------------------------------------------+
                    | Direct Input-Muxed 32b/24b/16b Accumulator Core   |
                    | (ACC_00_reg, ACC_01_reg, ACC_10_reg, ACC_11_reg)  |
                    +--------------------+------------------------------+
                                         |
                                         v
                    +---------------------------------------------------+
                    | Outputs: acc_00..11, acc_row0/1, acc_col0/1, 32b  |
                    +---------------------------------------------------+
```

---

## 📊 Silicon Sign-Off Results (45nm NanGate / FreePDK45 @ 500 MHz)

Sign-off results obtained using **Cadence Genus Synthesis Solution 20.11** and **Cadence Joules Power Solution** under matched **500 MHz (2.0ns period)** operating conditions (`TypTyp_0.8V_25C`):

| Metric | Standard INT4 Tile (`mac_reconfig_2d_baugh_wooley`) | NVFP4 Microscaling Tile (`mac_reconfig_2d_baugh_wooley_nvfp4`) | Overhead |
| :--- | :---: | :---: | :---: |
| **Technology Node** | 45nm NanGate / FreePDK45 | 45nm NanGate / FreePDK45 | - |
| **Clock Frequency** | **500 MHz** ($T_{clk}=2.0\text{ ns}$) | **500 MHz** ($T_{clk}=2.0\text{ ns}$) | Matched |
| **Cell Count** | 2,884 cells | 3,392 cells | +17.61% |
| **Total Silicon Area** | 2,960.58 $\mu\text{m}^2$ | 3,386.98 $\mu\text{m}^2$ | +14.40% |
| **Register Power** | 0.0376 mW | 0.0548 mW | - |
| **Dynamic Logic Power**| 0.7876 mW | 1.2252 mW | - |
| **Leakage Power** | 1.6774 $\mu\text{W}$ | 1.9400 $\mu\text{W}$ | - |
| **Total Power** | **0.8254 mW** | **1.2803 mW** | **+55.1% (Full Dual-Format)** |

---

## 📁 Repository Directory Structure

```
.
├── rtl/                                # Synthesizable RTL Design Sources
│   ├── mac_reconfig_2d_baugh_wooley.sv        # Standard INT4 2D Reconfigurable Tile
│   ├── mac_reconfig_2d_baugh_wooley_nvfp4.sv    # NVFP4 Microscaling E2M1 Reconfigurable Tile
│   ├── mac_reconfig_2d_baugh_wooley_baseline.sv # Baseline Benchmarking Tile
│   └── systolic_array_reconfig_nxn.sv         # NxN Reconfigurable Systolic Array Wrapper
├── tb/                                 # Self-Checking & Activity Testbenches
│   ├── mac_reconfig_tile_power_tb.sv          # Standard INT4 500 MHz Activity VCD Testbench
│   ├── mac_reconfig_nvfp4_tile_power_tb.sv    # NVFP4 500 MHz Activity VCD Testbench
│   └── mac_reconfig_2d_tb.sv                  # Functional Self-Checking Testbench
├── scripts/                            # Cadence EDA Sign-Off & Vivado Scripts
│   ├── synth_tile_comparison_45nm.tcl         # Genus 45nm Synthesis Script (INT4)
│   ├── synth_nvfp4_tile_45nm.tcl              # Genus 45nm Synthesis Script (NVFP4)
│   ├── calc_tile_power_comparison_45nm.tcl    # Joules 45nm Power Sign-Off (INT4)
│   ├── calc_nvfp4_power_45nm.tcl              # Joules 45nm Power Sign-Off (NVFP4)
│   ├── run_master_power_comparison_45nm.sh    # Master Batch Execution Script @ 500 MHz
│   └── vivado_runner.py                       # Automated Local Vivado Controller
├── notebooks/                          # Software-Hardware Co-Design Notebooks
│   └── nvfp4_microscaling_model.ipynb        # Qwen2.5-0.5B Microscaling & Tile Profiler
├── constraints/                        # Timing & Area XDC Constraints
│   └── mac_reconfig_top.xdc
├── .agents/                            # Repository Guidelines & Rules
│   └── AGENTS.md
└── README.md                           # Project Documentation
```

---

## 🛠️ How to Run & Reproduce

### 1. Software Model Execution (Python Notebook)
Open and run [`notebooks/nvfp4_microscaling_model.ipynb`](file:///c:/Users/Vigneswar/.gemini/antigravity-ide/scratch/rtl_workspace/notebooks/nvfp4_microscaling_model.ipynb) using Jupyter:
```bash
jupyter notebook notebooks/nvfp4_microscaling_model.ipynb
```
*Profiles $32 \times 32$ macro-tile quantization errors on LLM weights/activations and generates hardware trajectory parameters.*

### 2. Local RTL Simulation (Vivado)
To run functional self-checking simulation locally:
```powershell
python scripts/vivado_runner.py --sim mac_reconfig_nvfp4_tile_power_tb
```

### 3. Cadence Genus & Joules 500 MHz Silicon Sign-Off (Linux EDA Server)
Upload RTL sources and execute the master comparative sign-off script:
```bash
# Upload files
scp rtl/mac_reconfig_2d_baugh_wooley_nvfp4.sv user@eda_server:/path/to/mac_reconfig/rtl/

# Execute 500 MHz sign-off on server
cd /path/to/mac_reconfig
chmod +x scripts/run_master_power_comparison_45nm.sh
./scripts/run_master_power_comparison_45nm.sh
```

---

## 📜 Citation & License

This project is licensed under the **MIT License**.

If you use this hardware-software co-design framework or Baugh-Wooley NVFP4 reconfigurable tile in your research, please cite:

```bibtex
@article{shiva2026systolic,
  title={SHIVA: Systolic Hardware for Intelligent Variable-Precision Acceleration using Microscaled NVFP4 and Baugh-Wooley Co-Design},
  author={Vigneswar, T. and Anoop, B.},
  journal={IEEE Transactions on Very Large Scale Integration (VLSI) Systems},
  year={2026}
}
```