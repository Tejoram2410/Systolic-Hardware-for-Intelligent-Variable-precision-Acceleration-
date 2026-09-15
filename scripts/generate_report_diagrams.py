"""
Script: generate_report_diagrams.py
Generates high-resolution publication-quality diagrams for:
1. Bit-Level Universal Sign Pre-Encoding Matrix
2. PE-Level 4-bit Dadda/CSA Reduction Tree
3. Tile-Level 2x2 Reconfigurable MAC Fusion & Split/Join Accumulator
4. Array-Level NxN Systolic Mesh & Wavefront Routing
5. Silicon Power & Area Sign-Off Charts (SCL 180nm)
"""

import os
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np

os.makedirs("doc_assets", exist_ok=True)
plt.rcParams['font.sans-serif'] = 'DejaVu Sans'
plt.rcParams['font.family'] = 'sans-serif'

# -----------------------------------------------------------------------------
# 1. Bit-Level Universal Sign Pre-Encoding Matrix
# -----------------------------------------------------------------------------
def generate_bit_level_diagram():
    fig, ax = plt.subplots(figsize=(10, 6), dpi=300)
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6)
    ax.axis('off')

    # Title & Subtitle
    ax.text(5, 5.6, "Level 1: Universal Sign-Bit Pre-Encoding Matrix (Zero-MUX Logic)", 
            fontsize=14, fontweight='bold', ha='center', color='#1E293B')
    ax.text(5, 5.2, "p_ij = (a_i & b_j) ^ invert_ij  |  Bias Injection: bias_3, bias_4, bias_7", 
            fontsize=10, fontstyle='italic', ha='center', color='#475569')

    # Draw Matrix Grid
    cols = ["Col 0 (a0)", "Col 1 (a1)", "Col 2 (a2)", "Col 3 (a3 / MSB)"]
    rows = ["Row 0 (b0)", "Row 1 (b1)", "Row 2 (b2)", "Row 3 (b3 / MSB)"]

    for i in range(4):
        ax.text(2.2 + i * 1.8, 4.6, cols[i], fontsize=10, fontweight='bold', ha='center', color='#0F172A')
        ax.text(0.6, 3.8 - i * 0.9, rows[i], fontsize=10, fontweight='bold', ha='right', color='#0F172A')

    for r in range(4):
        for c in range(4):
            x = 1.3 + c * 1.8
            y = 3.4 - r * 0.9
            
            if r < 3 and c < 3:
                color = '#E0F2FE' # Blue-ish (Standard AND)
                border = '#0284C7'
                txt = f"p{c}{r}\n(AND)"
            elif r == 3 and c < 3:
                color = '#FEF3C7' # Yellow (sign_b invert)
                border = '#D97706'
                txt = f"p{c}{r}\n(^ sign_b)"
            elif r < 3 and c == 3:
                color = '#DCFCE7' # Green (sign_a invert)
                border = '#16A34A'
                txt = f"p{c}{r}\n(^ sign_a)"
            else: # r == 3 and c == 3
                color = '#FEE2E2' # Red (sign_a ^ sign_b)
                border = '#DC2626'
                txt = f"p{c}{r}\n(^ a^b)"

            rect = patches.FancyBboxPatch((x, y), 1.6, 0.7, boxstyle="round,pad=0.05", 
                                          facecolor=color, edgecolor=border, linewidth=1.5)
            ax.add_patch(rect)
            ax.text(x + 0.8, y + 0.35, txt, fontsize=9, ha='center', va='center', fontweight='bold', color='#1E293B')

    # Legend / Bias injection box
    bias_box = patches.FancyBboxPatch((8.7, 0.7), 1.1, 4.0, boxstyle="round,pad=0.08",
                                       facecolor='#F1F5F9', edgecolor='#94A3B8', linewidth=1.5)
    ax.add_patch(bias_box)
    ax.text(9.25, 4.4, "Bias Terms", fontsize=9, fontweight='bold', ha='center', color='#0F172A')
    ax.text(9.25, 3.5, "Col 3:\nsign_a ^ b", fontsize=8, ha='center', color='#334155')
    ax.text(9.25, 2.5, "Col 4:\nsign_a & b", fontsize=8, ha='center', color='#334155')
    ax.text(9.25, 1.5, "Col 7:\nsign_a | b", fontsize=8, ha='center', color='#334155')

    plt.tight_layout()
    plt.savefig("doc_assets/fig1_bit_level_matrix.png", dpi=300)
    plt.close()

# -----------------------------------------------------------------------------
# 2. PE-Level 4-bit Dadda/CSA Reduction Tree
# -----------------------------------------------------------------------------
def generate_pe_level_diagram():
    fig, ax = plt.subplots(figsize=(11, 6), dpi=300)
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 6)
    ax.axis('off')

    ax.text(5.5, 5.6, "Level 2: 4-bit Baugh-Wooley PE Reduction Tree (Direct SCL Primitives)", 
            fontsize=14, fontweight='bold', ha='center', color='#1E293B')
    ax.text(5.5, 5.2, "Mapped to SCL 180nm: adp1d0 (1b Full Adder) & ah01d0 (1b Half Adder) | Max Delay: 4 FA", 
            fontsize=10, fontstyle='italic', ha='center', color='#475569')

    # Columns 0 to 7
    col_labels = ["Col 7 (2^7)", "Col 6 (2^6)", "Col 5 (2^5)", "Col 4 (2^4)", "Col 3 (2^3)", "Col 2 (2^2)", "Col 1 (2^1)", "Col 0 (2^0)"]
    x_positions = np.linspace(1.0, 9.8, 8)

    for i, (col, x) in enumerate(zip(col_labels, x_positions)):
        ax.text(x, 4.6, col, fontsize=9, fontweight='bold', ha='center', color='#0F172A')

    # Draw reduction nodes per column
    col_data = [
        ["bias_7", "XOR(c6)"],                       # Col 7
        ["p33", "FA (adp1d0)", "HA (ah01d0)"],       # Col 6
        ["p32, p23", "3x FA", "Carry -> Col 6"],     # Col 5
        ["p31, p22, p13", "bias_4", "3x FA Tree"],  # Col 4
        ["p30, p21, p12", "p03, bias_3", "3x FA"],   # Col 3
        ["p20, p11, p02", "FA + HA"],                # Col 2
        ["p10, p01", "HA (ah01d0)"],                 # Col 1
        ["p00", "Direct Wire"]                       # Col 0
    ]

    for idx, (x, data) in enumerate(zip(x_positions, col_data)):
        for row_idx, item in enumerate(data):
            y = 3.8 - row_idx * 0.9
            box = patches.FancyBboxPatch((x - 0.55, y - 0.3), 1.1, 0.6, boxstyle="round,pad=0.04",
                                          facecolor='#EFF6FF', edgecolor='#3B82F6', linewidth=1.2)
            ax.add_patch(box)
            ax.text(x, y, item, fontsize=7.5, ha='center', va='center', fontweight='medium', color='#1E3A8A')

    # Output product bus
    out_box = patches.FancyBboxPatch((0.5, 0.4), 10.0, 0.7, boxstyle="round,pad=0.05",
                                     facecolor='#1E293B', edgecolor='#0F172A', linewidth=1.5)
    ax.add_patch(out_box)
    ax.text(5.5, 0.75, "8-bit Signed / Unsigned Raw Product Output: prod[7:0]", 
            fontsize=10, fontweight='bold', ha='center', color='#FFFFFF')

    plt.tight_layout()
    plt.savefig("doc_assets/fig2_pe_level_csa.png", dpi=300)
    plt.close()

# -----------------------------------------------------------------------------
# 3. Tile-Level 2x2 Reconfigurable MAC Fusion & Split/Join Accumulator
# -----------------------------------------------------------------------------
def generate_tile_level_diagram():
    fig, ax = plt.subplots(figsize=(11, 7), dpi=300)
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 7)
    ax.axis('off')

    ax.text(5.5, 6.6, "Level 3: 2x2 Reconfigurable MAC Tile Architecture (Ideas 1, 2, 3, 4)", 
            fontsize=14, fontweight='bold', ha='center', color='#1E293B')
    ax.text(5.5, 6.2, "2D CSA Crossbar Fusion + 100% Split/Join 32-bit Dynamic Accumulator Banking", 
            fontsize=10, fontstyle='italic', ha='center', color='#475569')

    # Mode Decoder Box
    dec_box = patches.FancyBboxPatch((0.5, 4.8), 2.2, 1.0, boxstyle="round,pad=0.05",
                                     facecolor='#FEF3C7', edgecolor='#D97706', linewidth=1.5)
    ax.add_patch(dec_box)
    ax.text(1.6, 5.4, "Mode Decoder\n(mode_2b[1:0])", fontsize=9, fontweight='bold', ha='center', color='#78350F')
    ax.text(1.6, 4.95, "00: 4x4 | 01: 8x4\n10: 4x8 | 11: 8x8", fontsize=7.5, ha='center', color='#92400E')

    # 4 PE Blocks
    pe_names = ["PE00 (4b)", "PE01 (4b)", "PE10 (4b)", "PE11 (4b)"]
    pe_coords = [(3.2, 5.0), (5.0, 5.0), (6.8, 5.0), (8.6, 5.0)]

    for name, (px, py) in zip(pe_names, pe_coords):
        p_box = patches.FancyBboxPatch((px, py), 1.5, 0.9, boxstyle="round,pad=0.05",
                                       facecolor='#DCFCE7', edgecolor='#16A34A', linewidth=1.3)
        ax.add_patch(p_box)
        ax.text(px + 0.75, py + 0.45, name + "\n(Core Mult)", fontsize=8, fontweight='bold', ha='center', color='#065F46')

    # 2D CSA Fusion Crossbar
    csa_box = patches.FancyBboxPatch((3.0, 3.2), 7.3, 1.2, boxstyle="round,pad=0.08",
                                     facecolor='#E0E7FF', edgecolor='#4338CA', linewidth=1.5)
    ax.add_patch(csa_box)
    ax.text(6.65, 4.0, "2D Carry-Save Fusion Crossbar (Weighted Reduction)", fontsize=10, fontweight='bold', ha='center', color='#312E81')
    ax.text(6.65, 3.5, "P00 (2^0 weight) + {P01, P10} (2^4 weight) + P11 (2^8 weight) --> Merged Sum/Carry", 
            fontsize=8, ha='center', color='#3730A3')

    # Dynamic Split/Join Accumulator Bank (64 Flip-Flops)
    acc_box = patches.FancyBboxPatch((0.5, 0.6), 9.8, 2.0, boxstyle="round,pad=0.08",
                                     facecolor='#F8FAFC', edgecolor='#334155', linewidth=1.5)
    ax.add_patch(acc_box)
    ax.text(5.4, 2.3, "Dynamic Split/Join 32-bit Accumulator Unit (64 Total Flip-Flops)", 
            fontsize=10, fontweight='bold', ha='center', color='#0F172A')

    # Sub-register banks
    banks = [("Mode 00: 4x 16-bit ACC", "acc_00 [15:0] | acc_01 [15:0] | acc_10 [15:0] | acc_11 [15:0]", 1.7),
             ("Mode 01 / 10: 2x 24-bit ACC", "acc_row0/col0 [23:0]    |    acc_row1/col1 [23:0]", 1.2),
             ("Mode 11: 1x 32-bit Unified ACC", "Fused Macro Accumulator: acc_32b [31:0]", 0.7)]

    for title, desc, ypos in banks:
        ax.text(1.0, ypos, title + ":", fontsize=8, fontweight='bold', color='#1E293B')
        ax.text(4.2, ypos, desc, fontsize=8, color='#475569')

    plt.tight_layout()
    plt.savefig("doc_assets/fig3_tile_level_fusion.png", dpi=300)
    plt.close()

# -----------------------------------------------------------------------------
# 4. Array-Level NxN Systolic Mesh & Wavefront Routing
# -----------------------------------------------------------------------------
def generate_array_level_diagram():
    fig, ax = plt.subplots(figsize=(10, 7), dpi=300)
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 7)
    ax.axis('off')

    ax.text(5.0, 6.6, "Level 4: Scalable N x N (16x16) Systolic Mesh & Wavefront Dataflow", 
            fontsize=14, fontweight='bold', ha='center', color='#1E293B')
    ax.text(5.0, 6.2, "256 Physical PEs in 64 Macro-Tiles | Dynamic Dimension-Aware Forwarding & Bypassing", 
            fontsize=10, fontstyle='italic', ha='center', color='#475569')

    # Grid of tiles
    tile_coords = [(2.0, 4.2), (4.5, 4.2), (7.0, 4.2),
                   (2.0, 2.2), (4.5, 2.2), (7.0, 2.2)]
    tile_labels = ["Tile (0,0)", "Tile (0,1)", "Tile (0, N/2-1)",
                   "Tile (1,0)", "Tile (1,1)", "Tile (1, N/2-1)"]

    for (x, y), label in zip(tile_coords, tile_labels):
        t_box = patches.FancyBboxPatch((x, y), 1.8, 1.2, boxstyle="round,pad=0.06",
                                       facecolor='#F0FDF4', edgecolor='#16A34A', linewidth=1.5)
        ax.add_patch(t_box)
        ax.text(x + 0.9, y + 0.7, label, fontsize=9, fontweight='bold', ha='center', color='#14532D')
        ax.text(x + 0.9, y + 0.35, "2x2 PEs (4b)\nAcc Slice", fontsize=7.5, ha='center', color='#166534')

    # Arrows for horizontal and vertical dataflow
    ax.annotate("", xy=(4.3, 4.8), xytext=(3.9, 4.8), arrowprops=dict(arrowstyle="->", lw=2, color="#2563EB"))
    ax.annotate("", xy=(6.8, 4.8), xytext=(6.4, 4.8), arrowprops=dict(arrowstyle="->", lw=2, color="#2563EB"))
    ax.annotate("", xy=(4.3, 2.8), xytext=(3.9, 2.8), arrowprops=dict(arrowstyle="->", lw=2, color="#2563EB"))
    ax.annotate("", xy=(6.8, 2.8), xytext=(6.4, 2.8), arrowprops=dict(arrowstyle="->", lw=2, color="#2563EB"))

    ax.annotate("", xy=(2.9, 3.6), xytext=(2.9, 4.0), arrowprops=dict(arrowstyle="->", lw=2, color="#DC2626"))
    ax.annotate("", xy=(5.4, 3.6), xytext=(5.4, 4.0), arrowprops=dict(arrowstyle="->", lw=2, color="#DC2626"))
    ax.annotate("", xy=(7.9, 3.6), xytext=(7.9, 4.0), arrowprops=dict(arrowstyle="->", lw=2, color="#DC2626"))

    # Top Inputs and Left Inputs
    ax.text(2.9, 5.8, "B_in[1:0]\n(Vert)", fontsize=8, fontweight='bold', ha='center', color='#DC2626')
    ax.text(5.4, 5.8, "B_in[3:2]\n(Vert)", fontsize=8, fontweight='bold', ha='center', color='#DC2626')
    ax.text(0.8, 4.8, "A_in[1:0]\n(Horiz)", fontsize=8, fontweight='bold', ha='center', color='#2563EB')
    ax.text(0.8, 2.8, "A_in[3:2]\n(Horiz)", fontsize=8, fontweight='bold', ha='center', color='#2563EB')

    # Legend box
    leg_box = patches.FancyBboxPatch((1.0, 0.4), 8.0, 1.2, boxstyle="round,pad=0.06",
                                     facecolor='#F8FAFC', edgecolor='#64748B', linewidth=1.2)
    ax.add_patch(leg_box)
    ax.text(5.0, 1.25, "Dynamic Bypassing Rules: bypass_a = mode[0], bypass_b = mode[1]", 
            fontsize=9, fontweight='bold', ha='center', color='#0F172A')
    ax.text(5.0, 0.75, "4x4 Mode: 1-cycle hop per PE (31-cycle wavefront latency) | 8x8 Mode: 1-cycle hop per Tile (15-cycle latency)", 
            fontsize=8, ha='center', color='#334155')

    plt.tight_layout()
    plt.savefig("doc_assets/fig4_array_level_systolic.png", dpi=300)
    plt.close()

# -----------------------------------------------------------------------------
# 5. Silicon Power & Area Sign-Off Charts (SCL 180nm)
# -----------------------------------------------------------------------------
def generate_power_area_charts():
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5), dpi=300)

    # 1. Power Comparison Bar Chart
    categories = ['Peak Stress\nWorkload', 'Typical ML\nWorkload']
    internal_pwr = [449.22, 375.85]
    switching_pwr = [226.77, 184.45]
    leakage_pwr = [0.032, 0.032]

    bar_width = 0.55
    ax1.bar(categories, internal_pwr, width=bar_width, label='Internal Power (mW)', color='#3B82F6')
    ax1.bar(categories, switching_pwr, width=bar_width, bottom=internal_pwr, label='Switching Power (mW)', color='#10B981')
    
    # Text annotations on bars
    ax1.text(0, 676.02 + 15, "676.02 mW\n(75.74 GOPS/W)", ha='center', fontsize=9, fontweight='bold', color='#1E293B')
    ax1.text(1, 560.34 + 15, "560.34 mW\n(91.43 GOPS/W)\n[-17.1%]", ha='center', fontsize=9, fontweight='bold', color='#065F46')

    ax1.set_ylim(0, 800)
    ax1.set_ylabel("Power Dissipation (mW)", fontsize=10, fontweight='bold')
    ax1.set_title("Silicon Power Sign-Off (SCL 180nm @ 100 MHz)", fontsize=11, fontweight='bold', color='#0F172A')
    ax1.legend(loc='upper right', fontsize=8.5)
    ax1.grid(axis='y', linestyle='--', alpha=0.5)

    # 2. Area Distribution Donut Chart
    labels = ['PE Multipliers\n(256 Cores)', 'CSA Fusion\nTrees & Logic', 'Accumulators\n(64 Flops/Tile)', 'Forwarding &\nBypassing']
    sizes = [18.2, 40.2, 34.1, 7.5]
    colors = ['#6366F1', '#38BDF8', '#F59E0B', '#10B981']

    wedges, texts, autotexts = ax2.pie(sizes, labels=labels, autopct='%1.1f%%', startangle=140, 
                                       colors=colors, textprops=dict(color="#1E293B", fontsize=8.5, fontweight='bold'),
                                       pctdistance=0.75, wedgeprops=dict(width=0.45, edgecolor='white', linewidth=2))

    for autotext in autotexts:
        autotext.set_color('#FFFFFF')
        autotext.set_fontsize(9)

    ax2.set_title("Silicon Area Breakdown (Total: 2.59 mm²)", fontsize=11, fontweight='bold', color='#0F172A')

    plt.tight_layout()
    plt.savefig("doc_assets/fig5_power_area_charts.png", dpi=300)
    plt.close()

if __name__ == "__main__":
    generate_bit_level_diagram()
    generate_pe_level_diagram()
    generate_tile_level_diagram()
    generate_array_level_diagram()
    generate_power_area_charts()
    print(">>> All 5 High-Resolution Architectural & Power Diagrams Generated in 'doc_assets/' <<<")
