"""
Script: generate_architecture_pdf.py
Compiles the complete technical architecture and power sign-off report into
a professional multi-page PDF document with embedded high-resolution figures,
mathematical formulas, structured tables, and clean typography.
"""

import os
import shutil
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle, PageBreak, HRFlowable
)
from reportlab.pdfgen import canvas

brain_dir = r"C:\Users\Vigneswar\.gemini\antigravity-ide\brain\a94d2c18-605d-40ed-83b6-6fb8194ec519"
os.makedirs(brain_dir, exist_ok=True)

fig_names = [
    "fig1_bit_level_matrix.png",
    "fig2_pe_level_csa.png",
    "fig3_tile_level_fusion.png",
    "fig4_array_level_systolic.png",
    "fig5_power_area_charts.png"
]

for f in fig_names:
    src = os.path.join("doc_assets", f)
    dst = os.path.join(brain_dir, f)
    if os.path.exists(src):
        shutil.copy2(src, dst)

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super(NumberedCanvas, self).__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_number(self, page_count):
        self.saveState()
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748B"))
        
        # Header (pages > 1)
        if self._pageNumber > 1:
            self.drawString(54, 750, "Scalable Ultra-Low-Power Reconfigurable Systolic Array Architecture (N=16)")
            self.setStrokeColor(colors.HexColor("#CBD5E1"))
            self.setLineWidth(0.5)
            self.line(54, 742, 558, 742)

        # Footer
        page_text = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(558, 36, page_text)
        self.drawString(54, 36, "Confidential & Proprietary | ASIC Silicon Sign-Off (SCL 180nm @ 100 MHz)")
        self.setStrokeColor(colors.HexColor("#CBD5E1"))
        self.setLineWidth(0.5)
        self.line(54, 48, 558, 48)
        self.restoreState()

def build_pdf():
    pdf_path = "Scalable_Reconfigurable_Systolic_Array_Report.pdf"
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        leftMargin=54,
        rightMargin=54,
        topMargin=54,
        bottomMargin=54
    )

    styles = getSampleStyleSheet()
    
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=19,
        leading=23,
        textColor=colors.HexColor('#0F172A'),
        spaceAfter=5
    )

    subtitle_style = ParagraphStyle(
        'DocSubtitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=colors.HexColor('#475569'),
        spaceAfter=12
    )

    h1_style = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=colors.HexColor('#1E3A8A'),
        spaceBefore=12,
        spaceAfter=5
    )

    h2_style = ParagraphStyle(
        'Heading2_Custom',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        textColor=colors.HexColor('#0F172A'),
        spaceBefore=7,
        spaceAfter=3
    )

    body_style = ParagraphStyle(
        'Body_Custom',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=colors.HexColor('#334155'),
        spaceAfter=5
    )

    formula_style = ParagraphStyle(
        'Formula_Box',
        parent=styles['Normal'],
        fontName='Courier-Bold',
        fontSize=8,
        leading=11,
        textColor=colors.HexColor('#0F172A'),
        backColor=colors.HexColor('#F8FAFC'),
        borderColor=colors.HexColor('#E2E8F0'),
        borderWidth=1,
        borderPadding=5,
        spaceBefore=3,
        spaceAfter=5
    )

    table_cell = ParagraphStyle(
        'TableCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.8,
        leading=10,
        textColor=colors.HexColor('#1E293B')
    )

    table_header = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        leading=10,
        textColor=colors.HexColor('#FFFFFF')
    )

    story = []

    # Title & Metadata
    story.append(Paragraph("Scalable Ultra-Low-Power Reconfigurable Systolic Array", title_style))
    story.append(Paragraph("Full-Stack Mathematical Formulation, Hardware Design, AI Activity Modeling & Silicon Power Sign-Off (N=16, 256 PEs, SCL 180nm @ 100 MHz)", subtitle_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=colors.HexColor('#2563EB'), spaceAfter=8))

    # 1. Executive Summary
    story.append(Paragraph("1. Executive Summary & Architectural Overview", h1_style))
    story.append(Paragraph(
        "This document provides the complete theoretical foundation, microarchitectural derivation, activity-driven testbench modeling, and Cadence Joules gate-level silicon sign-off analysis for a scalable 2D reconfigurable systolic array configured at <b>N = 16</b> (256 physical 4-bit Processing Elements, 64 reconfigurable 2x2 tiles). Target technology: <b>SCL 180nm CMOS (`tsl18fs120_scl_ss.lib`)</b> at <b>100 MHz</b>.",
        body_style
    ))

    # 2. Level 1: Bit-Level Architecture
    story.append(Paragraph("2. Level 1 — Bit-Level Formulation & Universal Sign Pre-Encoding", h1_style))
    story.append(Paragraph(
        "Standard Baugh-Wooley multiplication eliminates two's complement subtraction using <i>-A = ~A - 1</i>, creating a constant bias of <i>2^(2K-1) + 2^K</i> (144 for K=4). To eliminate multiplexers from the partial product critical path during precision reconfiguration, we introduce the <b>Universal Sign-Bit Pre-Encoding Formulation</b>:",
        body_style
    ))
    story.append(Paragraph(
        "Partial Product Gate Formulation:  p_ij = (a_i & b_j) ^ invert_ij<br/>"
        "  - For i < 3, j < 3: invert = 0 (Standard AND)<br/>"
        "  - For i < 3, j = 3: invert = sign_b<br/>"
        "  - For i = 3, j < 3: invert = sign_a<br/>"
        "  - For i = 3, j = 3: invert = sign_a ^ sign_b<br/>"
        "Dynamic Bias Injection:  bias_3 = sign_a ^ sign_b,  bias_4 = sign_a & sign_b,  bias_7 = sign_a | sign_b",
        formula_style
    ))
    story.append(Image("doc_assets/fig1_bit_level_matrix.png", width=470, height=230))
    story.append(Spacer(1, 6))

    # 3. Level 2: PE-Level Architecture
    story.append(Paragraph("3. Level 2 — PE-Level Architecture & Direct SCL Cell Mapping", h1_style))
    story.append(Paragraph(
        "Each 4-bit PE core implements an 8-column Dadda/CSA reduction tree mapped directly to SCL 180nm standard cell primitives (<code>adp1d0</code> 1-bit Full Adders and <code>ah01d0</code> 1-bit Half Adders). The maximum combinational delay is strictly 4 FA stages (< 2.5 ns).",
        body_style
    ))
    story.append(Image("doc_assets/fig2_pe_level_csa.png", width=470, height=230))

    story.append(PageBreak())

    # 4. Level 3: Tile-Level Architecture
    story.append(Paragraph("4. Level 3 — Tile-Level Architecture (2x2 Macro-Tile)", h1_style))
    story.append(Paragraph(
        "A single 2x2 Macro-Tile combines 4 physical 4-bit PEs to execute four precision modes via a shared <b>2D Carry-Save Fusion Crossbar</b> and a <b>Dynamic 32-bit Split/Join Accumulator Unit</b>.",
        body_style
    ))

    tile_data = [
        [Paragraph("Mode", table_header), Paragraph("Bit-Width", table_header), Paragraph("Mathematical Decomposition", table_header), Paragraph("Sign Config (PE00..11)", table_header)],
        [Paragraph("00 (4x4)", table_cell), Paragraph("4x 4b x 4b", table_cell), Paragraph("P_00=A0*B0, P_01=A1*B1, P_10=A2*B2, P_11=A3*B3", table_cell), Paragraph("SS, SS, SS, SS", table_cell)],
        [Paragraph("01 (8x4)", table_cell), Paragraph("2x 8b x 4b", table_cell), Paragraph("Row0 = (A1*B0)*16 + (A0*B0); Row1 = (A3*B1)*16 + (A2*B1)", table_cell), Paragraph("US, SS, US, SS", table_cell)],
        [Paragraph("10 (4x8)", table_cell), Paragraph("2x 4b x 8b", table_cell), Paragraph("Col0 = (A0*B2)*16 + (A0*B0); Col1 = (A1*B3)*16 + (A1*B1)", table_cell), Paragraph("SU, SU, SS, SS", table_cell)],
        [Paragraph("11 (8x8)", table_cell), Paragraph("1x 8b x 8b", table_cell), Paragraph("Fused = (A1*B2)*256 + (A1*B0 + A0*B2)*16 + (A0*B0)", table_cell), Paragraph("UU, SU, US, SS", table_cell)],
    ]
    t_tile = Table(tile_data, colWidths=[55, 60, 235, 120])
    t_tile.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E3A8A')),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.HexColor('#FFFFFF'), colors.HexColor('#F8FAFC')]),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(t_tile)
    story.append(Spacer(1, 5))
    story.append(Image("doc_assets/fig3_tile_level_fusion.png", width=470, height=255))
    story.append(Spacer(1, 8))

    # 5. Level 4: Array-Level Architecture
    story.append(Paragraph("5. Level 4 — Array-Level Architecture (N x N Systolic Mesh)", h1_style))
    story.append(Paragraph(
        "At the array scale, 64 tiles form a 16x16 2D systolic array with <b>Dimension-Aware Register Bypassing</b> (<code>bypass_a = mode_2b[0]</code>, <code>bypass_b = mode_2b[1]</code>). Fused 8-bit operands bypass intermediate intra-tile registers and forward as complete 8-bit bundles in 1 cycle, ensuring seamless wavefront scheduling.",
        body_style
    ))
    story.append(Image("doc_assets/fig4_array_level_systolic.png", width=470, height=255))

    story.append(PageBreak())

    # 6. Activity Measurement Testbench Design & AI Workload Modeling
    story.append(Paragraph("6. Activity Measurement Testbenches & AI Workload Modeling", h1_style))
    story.append(Paragraph(
        "To obtain true silicon sign-off power numbers rather than statistical approximations, two specialized activity measurement testbenches were engineered to generate gate-level Value Change Dump (VCD) traces across all 256 physical PEs in the synthesized gate netlist:",
        body_style
    ))

    story.append(Paragraph("A. Peak Stress Activity Testbench (`systolic_array_reconfig_nxn_tb_power_max.sv`)", h2_style))
    story.append(Paragraph(
        "Designed to provoke the theoretical maximum dynamic switching capacitance (<i>alpha = 1.0</i>) and extreme glitching power. "
        "Each physical PE executes <b>15+ operations per mode</b> with alternating maximum two's complement extremes:<br/>"
        "  - <b>4-bit Multipliers</b>: Injected with <i>-8 (4'b1000) <--> +7 (4'b0111)</i> every clock edge, maximizing the Hamming distance (<i>H_D = 4</i>) across all operand inputs.<br/>"
        "  - <b>8-bit Multipliers</b>: Injected with <i>-128 (8'b10000000) <--> +127 (8'b01111111)</i> (<i>H_D = 8</i>).<br/>"
        "  - <b>Multi-Mode Interleaving</b>: Rapidly sequences through <i>00 -> 01 -> 10 -> 11 -> 00</i> to measure control plane switching overhead.",
        body_style
    ))

    story.append(Paragraph("B. Typical ML Workload Activity Testbench (`systolic_array_reconfig_nxn_tb_power_avg.sv`)", h2_style))
    story.append(Paragraph(
        "Accurately models the statistical distributions encountered in deep neural network inference (CNNs, Vision Transformers, Quantized LLMs):<br/>"
        "  - <b>Post-ReLU Quantized Activations</b>: Unipolar non-negative integer distribution: INT4 in <i>[0, +7]</i>, INT8 in <i>[0, +127]</i>.<br/>"
        "  - <b>Zero-Mean Quantized Weights</b>: Symmetric zero-mean integer distribution: INT4 in <i>[-4, +3]</i>, INT8 in <i>[-64, +63]</i>.<br/>"
        "  - <b>Structured Weight Sparsity (25%)</b>: Modeled with 25% of weights clamped to <i>0</i>, exercising the dynamic operand isolation gating.<br/>"
        "  - <b>Multi-Layer Execution (15+ OPs/PE)</b>: Simulates continuous matrix multiplication across consecutive convolutional/attention layers.",
        body_style
    ))

    # 7. ASIC Silicon Area & Power Sign-Off
    story.append(Paragraph("7. ASIC Silicon Area & Power Sign-Off (SCL 180nm @ 100 MHz)", h1_style))
    story.append(Paragraph(
        "Gate-level power sign-off was performed using Cadence Joules by reading the gate netlist and annotated VCD switching activity files.",
        body_style
    ))

    pwr_data = [
        [Paragraph("Power Component", table_header), Paragraph("Peak Stress (676.02 mW)", table_header), Paragraph("Typical ML (560.34 mW)", table_header), Paragraph("Power Savings", table_header)],
        [Paragraph("Static Leakage Power", table_cell), Paragraph("32.48 uW (0.005%)", table_cell), Paragraph("32.48 uW (0.006%)", table_cell), Paragraph("0.00 uW", table_cell)],
        [Paragraph("Sequential Register Power", table_cell), Paragraph("78.50 mW (11.61%)", table_cell), Paragraph("71.35 mW (12.73%)", table_cell), Paragraph("-7.15 mW (-9.1%)", table_cell)],
        [Paragraph("Combinational Logic Power", table_cell), Paragraph("597.52 mW (88.39%)", table_cell), Paragraph("488.99 mW (87.27%)", table_cell), Paragraph("-108.53 mW (-18.2%)", table_cell)],
        [Paragraph("Total Power Dissipation", table_header), Paragraph("676.02 mW (100.0%)", table_header), Paragraph("560.34 mW (100.0%)", table_header), Paragraph("-115.68 mW (-17.11%)", table_header)],
        [Paragraph("Power Per Physical 4-bit PE", table_cell), Paragraph("2.64 mW / PE", table_cell), Paragraph("2.19 mW / PE", table_cell), Paragraph("-0.45 mW / PE", table_cell)]
    ]
    t_pwr = Table(pwr_data, colWidths=[130, 125, 125, 90])
    t_pwr.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E3A8A')),
        ('BACKGROUND', (0, 4), (-1, 4), colors.HexColor('#0F172A')),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
        ('ROWBACKGROUNDS', (0, 1), (-1, 3), [colors.HexColor('#FFFFFF'), colors.HexColor('#F8FAFC')]),
        ('ROWBACKGROUNDS', (0, 5), (-1, 5), [colors.HexColor('#F1F5F9')]),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 3.5),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3.5),
    ]))
    story.append(t_pwr)
    story.append(Spacer(1, 6))

    story.append(Image("doc_assets/fig5_power_area_charts.png", width=470, height=190))
    story.append(Spacer(1, 6))

    # Metrics Summary Box
    story.append(Paragraph("8. Key Performance & Efficiency Summary", h1_style))
    metrics_data = [
        [Paragraph("Parameter", table_header), Paragraph("Value", table_header), Paragraph("Parameter", table_header), Paragraph("Value", table_header)],
        [Paragraph("Silicon Process Node", table_cell), Paragraph("SCL 180nm (6M1L)", table_cell), Paragraph("Sign-Off Frequency", table_cell), Paragraph("100 MHz (10 ns)", table_cell)],
        [Paragraph("Physical PEs / Tiles", table_cell), Paragraph("256 PEs / 64 Tiles", table_cell), Paragraph("Total Standard Cells", table_cell), Paragraph("113,766 cells", table_cell)],
        [Paragraph("Total Silicon Area", table_cell), Paragraph("2.59 mm² (2592.5k um²)", table_cell), Paragraph("Peak INT4 Compute", table_cell), Paragraph("51.20 GOPS", table_cell)],
        [Paragraph("Energy Efficiency (ML)", table_cell), Paragraph("91.43 GOPS / W", table_cell), Paragraph("Energy Per Operation", table_cell), Paragraph("10.94 pJ / OP", table_cell)],
    ]
    t_met = Table(metrics_data, colWidths=[118, 117, 118, 117])
    t_met.setStyle(TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#1E3A8A')),
        ('GRID', (0, 0), (-1, -1), 0.5, colors.HexColor('#CBD5E1')),
        ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.HexColor('#FFFFFF'), colors.HexColor('#F8FAFC')]),
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'),
        ('TOPPADDING', (0, 0), (-1, -1), 3),
        ('BOTTOMPADDING', (0, 0), (-1, -1), 3),
    ]))
    story.append(t_met)

    doc.build(story, canvasmaker=NumberedCanvas)
    
    dst_pdf = os.path.join(brain_dir, "Scalable_Reconfigurable_Systolic_Array_Report.pdf")
    shutil.copy2(pdf_path, dst_pdf)
    print(f">>> Updated PDF Successfully Re-Compiled: {pdf_path} & {dst_pdf} <<<")

if __name__ == "__main__":
    build_pdf()
