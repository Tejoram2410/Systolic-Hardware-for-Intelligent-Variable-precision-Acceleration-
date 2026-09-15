//-----------------------------------------------------------------------------
// Module: mac_reconfig_2d_baugh_wooley.sv
// Description: OPTIMIZED 2D Reconfigurable 2x2 MAC Tile with Mode-Specific Integrated Clock Gating (ICG).
// Precision Modes:
//   - 00: 4x4 SIMD (4 parallel 4-bit signed MACs)
//   - 01: Dual 8x4 Horizontal Fusion (2 parallel 8x4 signed MACs)
//   - 10: Dual 4x8 Vertical Fusion (2 parallel 4x8 signed MACs)
//   - 11: Unified 8x8 Mode (1 full 8-bit signed MAC with 32-bit Fused Accumulator)
// Technology: SCL 180nm Standard Cell Primitives (an02d1, nd02d1, adp1d0, ah01d0)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SCL_PDK_SIM
// Simulation Models for SCL 180nm PDK Standard Cells (for Vivado local simulation)
module ah01d0 (
    output logic S,
    output logic CO,
    input  logic A,
    input  logic B
);
    assign S  = A ^ B;
    assign CO = A & B;
endmodule

module adp1d0 (
    output logic S,
    output logic CO,
    output logic P,
    input  logic A,
    input  logic B,
    input  logic CI
);
    assign S  = A ^ B ^ CI;
    assign CO = (A & B) | (B & CI) | (A & CI);
    assign P  = A ^ B;
endmodule

module an02d1 (
    output logic Z,
    input  logic A,
    input  logic B
);
    assign Z = A & B;
endmodule

module nd02d1 (
    output logic Z,
    input  logic A,
    input  logic B
);
    assign Z = ~(A & B);
endmodule
`endif

//=============================================================================
// 4x4 Baugh-Wooley Multiplier Core with Direct SCL Standard Cells
//=============================================================================
module baugh_wooley_4b_pe (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       sign_a,
    input  logic       sign_b,
    output logic [7:0] prod
);
    logic p00, p10, p20, p30;
    logic p01, p11, p21, p31;
    logic p02, p12, p22, p32;
    logic p03, p13, p23, p33;

    // Row 0
    assign p00 = a[0] & b[0];
    assign p10 = a[1] & b[0];
    assign p20 = a[2] & b[0];
    assign p30 = (a[3] & b[0]) ^ sign_a;

    // Row 1
    assign p01 = a[0] & b[1];
    assign p11 = a[1] & b[1];
    assign p21 = a[2] & b[1];
    assign p31 = (a[3] & b[1]) ^ sign_a;

    // Row 2
    assign p02 = a[0] & b[2];
    assign p12 = a[1] & b[2];
    assign p22 = a[2] & b[2];
    assign p32 = (a[3] & b[2]) ^ sign_a;

    // Row 3
    assign p03 = (a[0] & b[3]) ^ sign_b;
    assign p13 = (a[1] & b[3]) ^ sign_b;
    assign p23 = (a[2] & b[3]) ^ sign_b;
    assign p33 = (a[3] & b[3]) ^ (sign_a ^ sign_b);

    // Hardwired Bias Constants
    logic bias_bit3, bias_bit4, bias_bit7;
    assign bias_bit3 = sign_a ^ sign_b;
    assign bias_bit4 = sign_a & sign_b;
    assign bias_bit7 = sign_a | sign_b;

    // Direct SCL Standard Cell CSA Reduction Tree
    assign prod[0] = p00;

    logic s1, c1;
    ah01d0 u_ha_col1 (.S(s1), .CO(c1), .A(p10), .B(p01));
    assign prod[1] = s1;

    logic s2_0, c2_0, s2_1, c2_1;
    adp1d0 u_fa_col2 (.S(s2_0), .CO(c2_0), .P(), .A(p20), .B(p11), .CI(p02));
    ah01d0 u_ha_col2 (.S(s2_1), .CO(c2_1), .A(s2_0), .B(c1));
    assign prod[2] = s2_1;

    logic s3_0, c3_0, s3_1, c3_1, s3_2, c3_2;
    adp1d0 u_fa_col3_0 (.S(s3_0), .CO(c3_0), .P(), .A(p30), .B(p21), .CI(p12));
    adp1d0 u_fa_col3_1 (.S(s3_1), .CO(c3_1), .P(), .A(s3_0), .B(p03), .CI(bias_bit3));
    adp1d0 u_fa_col3_2 (.S(s3_2), .CO(c3_2), .P(), .A(s3_1), .B(c2_0), .CI(c2_1));
    assign prod[3] = s3_2;

    logic s4_0, c4_0, s4_1, c4_1, s4_2, c4_2;
    adp1d0 u_fa_col4_0 (.S(s4_0), .CO(c4_0), .P(), .A(p31), .B(p22), .CI(p13));
    adp1d0 u_fa_col4_1 (.S(s4_1), .CO(c4_1), .P(), .A(s4_0), .B(bias_bit4), .CI(c3_0));
    adp1d0 u_fa_col4_2 (.S(s4_2), .CO(c4_2), .P(), .A(s4_1), .B(c3_1), .CI(c3_2));
    assign prod[4] = s4_2;

    logic s5_0, c5_0, s5_1, c5_1;
    adp1d0 u_fa_col5_0 (.S(s5_0), .CO(c5_0), .P(), .A(p32), .B(p23), .CI(c4_0));
    adp1d0 u_fa_col5_1 (.S(s5_1), .CO(c5_1), .P(), .A(s5_0), .B(c4_1), .CI(c4_2));
    assign prod[5] = s5_1;

    logic s6_0, c6_0;
    adp1d0 u_fa_col6_0 (.S(s6_0), .CO(c6_0), .P(), .A(p33), .B(c5_0), .CI(c5_1));
    assign prod[6] = s6_0;

    assign prod[7] = bias_bit7 ^ c6_0;

endmodule

//=============================================================================
// Top-Level 2D Reconfigurable MAC Tile (Genus-Guided Low Power Module)
//=============================================================================
module mac_reconfig_2d_baugh_wooley (
    input  logic              clk,
    input  logic              rst_n,
    input  logic [1:0]        mode_2b,
    input  logic              valid_in,
    input  logic              clr_acc,

    input  logic signed [3:0] A0, B0,
    input  logic signed [3:0] A1, B1,
    input  logic signed [3:0] A2, B2,
    input  logic signed [3:0] A3, B3,

    output logic              valid_out,
    output logic signed [15:0] acc_00,
    output logic signed [15:0] acc_01,
    output logic signed [15:0] acc_10,
    output logic signed [15:0] acc_11,
    output logic signed [23:0] acc_row0,
    output logic signed [23:0] acc_row1,
    output logic signed [23:0] acc_col0,
    output logic signed [23:0] acc_col1,
    output logic signed [31:0] acc_32b
);

    // 1. Universal Sign Pre-Encoding Matrix
    logic sign_a_00, sign_b_00;
    logic sign_a_01, sign_b_01;
    logic sign_a_10, sign_b_10;
    logic sign_a_11, sign_b_11;

    assign sign_a_00 = ~mode_2b[0]; // 1 in 4x4 & 4x8; 0 in 8x4 & 8x8
    assign sign_b_00 = ~mode_2b[1]; // 1 in 4x4 & 8x4; 0 in 4x8 & 8x8
    assign sign_a_01 = 1'b1;        // Always signed A_high / A1
    assign sign_b_01 = ~mode_2b[1]; // 1 in 4x4 & 8x4; 0 in 4x8 & 8x8
    assign sign_a_10 = ~mode_2b[0]; // 1 in 4x4 & 4x8; 0 in 8x4 & 8x8
    assign sign_b_10 = 1'b1;        // Always signed B_high / B2
    assign sign_a_11 = 1'b1;        // Always signed across all modes
    assign sign_b_11 = 1'b1;

    // 2. Dynamic Input Operand Isolation (Explicit bitwise AND guarantees AND2 gates)
    logic [3:0] a0_iso, b0_iso, a1_iso, b1_iso;
    logic [3:0] a2_iso, b2_iso, a3_iso, b3_iso;

    assign a0_iso = {4{valid_in}} & A0;
    assign b0_iso = {4{valid_in}} & B0;
    assign a1_iso = {4{valid_in}} & A1;
    assign b1_iso = {4{valid_in}} & B1;
    assign a2_iso = {4{valid_in}} & A2;
    assign b2_iso = {4{valid_in}} & B2;
    assign a3_iso = {4{valid_in}} & A3;
    assign b3_iso = {4{valid_in}} & B3;

    // 3. 2x2 Multiplier PE Cores
    logic [7:0] P_00_raw, P_01_raw, P_10_raw, P_11_raw;

    baugh_wooley_4b_pe u_pe00 (.a(a0_iso), .b(b0_iso), .sign_a(sign_a_00), .sign_b(sign_b_00), .prod(P_00_raw));
    baugh_wooley_4b_pe u_pe01 (.a(a1_iso), .b(b1_iso), .sign_a(sign_a_01), .sign_b(sign_b_01), .prod(P_01_raw));
    baugh_wooley_4b_pe u_pe10 (.a(a2_iso), .b(b2_iso), .sign_a(sign_a_10), .sign_b(sign_b_10), .prod(P_10_raw));
    baugh_wooley_4b_pe u_pe11 (.a(a3_iso), .b(b3_iso), .sign_a(sign_a_11), .sign_b(sign_b_11), .prod(P_11_raw));

    // 3b. Mode Decoding
    logic mode_is_4b, mode_is_8x4, mode_is_4x8, mode_is_8b;
    assign mode_is_4b  = (mode_2b == 2'b00);
    assign mode_is_8x4 = (mode_2b == 2'b01);
    assign mode_is_4x8 = (mode_2b == 2'b10);
    assign mode_is_8b  = (mode_2b == 2'b11);

    // 4. Shared Merge Units (mergeA, mergeB) with Direct-Wired Low Nibbles
    logic [7:0] mergeA_hi_in, mergeB_lo_in;

    assign mergeA_hi_in = mode_is_4x8 ? P_10_raw : P_01_raw;
    assign mergeB_lo_in = mode_is_4x8 ? P_01_raw : P_10_raw;

    logic signed [15:0] mergeA_out;
    logic signed [15:0] mergeB_out;

    // Low nibble [3:0] is direct-wired (high operand low-nibble is 0 due to << 4 shift)
    assign mergeA_out[3:0]  = P_00_raw[3:0];
    assign mergeA_out[15:4] = $signed({{8{P_00_raw[7]}}, P_00_raw[7:4]}) + $signed({{4{mergeA_hi_in[7]}}, mergeA_hi_in});

    assign mergeB_out[3:0]  = mergeB_lo_in[3:0];
    assign mergeB_out[15:4] = $signed({{8{mergeB_lo_in[7]}}, mergeB_lo_in[7:4]}) + $signed({{4{P_11_raw[7]}}, P_11_raw});

    logic signed [15:0] P_row0, P_row1;
    logic signed [15:0] P_col0, P_col1;

    assign P_row0 = mergeA_out;
    assign P_row1 = mergeB_out;
    assign P_col0 = mergeA_out;
    assign P_col1 = mergeB_out;

    // Mode 11: Unified 8x8 Mode Partial Product Fusion Tree (Parallel CSA Tree)
    logic signed [15:0] P_00_8b_ext, P_01_8b_ext, P_10_8b_ext, P_11_8b_ext;
    logic signed [15:0] mid_sum_8b;
    logic signed [15:0] P_8b;

    assign P_00_8b_ext = mode_is_8b ? {8'b0, P_00_raw} : 16'sd0;
    assign P_01_8b_ext = mode_is_8b ? {{8{P_01_raw[7]}}, P_01_raw} : 16'sd0;
    assign P_10_8b_ext = mode_is_8b ? {{8{P_10_raw[7]}}, P_10_raw} : 16'sd0;
    assign P_11_8b_ext = mode_is_8b ? {{8{P_11_raw[7]}}, P_11_raw} : 16'sd0;

    assign mid_sum_8b  = P_01_8b_ext + P_10_8b_ext;
    assign P_8b        = P_00_8b_ext + (mid_sum_8b << 4) + (P_11_8b_ext << 8);

    // 5. UNIFIED RESOURCE-SHARED ACCUMULATOR CORE
    logic signed [15:0] ACC_00_reg, ACC_01_reg, ACC_10_reg, ACC_11_reg;
    logic               valid_out_reg;

    // Shared Adder 0: Computes 32-bit update for ACC_00 / Row0 / Col0 / 8x8 Fused
    logic signed [31:0] base_acc0, p_term0, shared_acc0;

    always_comb begin
        case (mode_2b)
            2'b01: begin // 8x4 Row Mode (Row 0)
                base_acc0 = $signed({{8{ACC_01_reg[7]}}, ACC_01_reg[7:0], ACC_00_reg});
                p_term0   = $signed({{16{P_row0[15]}}, P_row0});
            end
            2'b10: begin // 4x8 Col Mode (Col 0)
                base_acc0 = $signed({{8{ACC_10_reg[7]}}, ACC_10_reg[7:0], ACC_00_reg});
                p_term0   = $signed({{16{P_col0[15]}}, P_col0});
            end
            2'b11: begin // 8x8 Fused Mode
                base_acc0 = $signed({ACC_11_reg, ACC_00_reg});
                p_term0   = $signed({{16{P_8b[15]}}, P_8b});
            end
            default: begin // 4x4 SIMD Mode (00)
                base_acc0 = $signed({16'sd0, ACC_00_reg});
                p_term0   = $signed({{24{P_00_raw[7]}}, P_00_raw});
            end
        endcase
    end

    assign shared_acc0 = clr_acc ? p_term0 : (base_acc0 + p_term0);

    // Shared Adder 1: Computes 24-bit update for Row 1 (8x4) & Col 1 (4x8)
    logic signed [23:0] base_acc1, p_term1, shared_acc1;

    always_comb begin
        case (mode_2b)
            2'b01: begin // 8x4 Row Mode (Row 1)
                base_acc1 = $signed({ACC_11_reg[7:0], ACC_10_reg});
                p_term1   = $signed({{8{P_row1[15]}}, P_row1});
            end
            2'b10: begin // 4x8 Col Mode (Col 1)
                base_acc1 = $signed({ACC_11_reg[7:0], ACC_01_reg});
                p_term1   = $signed({{8{P_col1[15]}}, P_col1});
            end
            default: begin // 4x4 SIMD or 8x8 Mode
                base_acc1 = 24'sd0;
                p_term1   = 24'sd0;
            end
        endcase
    end

    assign shared_acc1 = clr_acc ? p_term1 : (base_acc1 + p_term1);

    // Combinational Next-State Signals
    logic signed [15:0] next_acc_00, next_acc_01, next_acc_10, next_acc_11;

    always_comb begin
        case (mode_2b)
            2'b00: begin // Quad 4x4 SIMD Mode
                next_acc_00 = clr_acc ? {{8{P_00_raw[7]}}, P_00_raw} : (ACC_00_reg + {{8{P_00_raw[7]}}, P_00_raw});
                next_acc_01 = clr_acc ? {{8{P_01_raw[7]}}, P_01_raw} : (ACC_01_reg + {{8{P_01_raw[7]}}, P_01_raw});
                next_acc_10 = clr_acc ? {{8{P_10_raw[7]}}, P_10_raw} : (ACC_10_reg + {{8{P_10_raw[7]}}, P_10_raw});
                next_acc_11 = clr_acc ? {{8{P_11_raw[7]}}, P_11_raw} : (ACC_11_reg + {{8{P_11_raw[7]}}, P_11_raw});
            end
            2'b01: begin // Dual 8x4 Horizontal Fusion (Row 0 & Row 1)
                next_acc_00 = shared_acc0[15:0];
                next_acc_01 = {{8{shared_acc0[23]}}, shared_acc0[23:16]};
                next_acc_10 = shared_acc1[15:0];
                next_acc_11 = {{8{shared_acc1[23]}}, shared_acc1[23:16]};
            end
            2'b10: begin // Dual 4x8 Vertical Fusion (Col 0 & Col 1)
                next_acc_00 = shared_acc0[15:0];
                next_acc_10 = {{8{shared_acc0[23]}}, shared_acc0[23:16]};
                next_acc_01 = shared_acc1[15:0];
                next_acc_11 = {{8{shared_acc1[23]}}, shared_acc1[23:16]};
            end
            2'b11: begin // Unified 8x8 Mode
                next_acc_00 = shared_acc0[15:0];
                next_acc_11 = shared_acc0[31:16];
                next_acc_01 = clr_acc ? 16'sd0 : ACC_01_reg;
                next_acc_10 = clr_acc ? 16'sd0 : ACC_10_reg;
            end
        endcase
    end

    // Glitch-Free Registered Enables for Genus Integrated Clock Gating (ICG)
    wire en_acc_00 = valid_in;
    wire en_acc_01 = valid_in && ((mode_2b != 2'b11) || clr_acc);
    wire en_acc_10 = valid_in && ((mode_2b != 2'b11) || clr_acc);
    wire en_acc_11 = valid_in;

    // Sequential Register Bank Update with Glitch-Free Mode-Specific ICG Clock Enable Gates
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ACC_00_reg    <= 16'sd0;
            ACC_01_reg    <= 16'sd0;
            ACC_10_reg    <= 16'sd0;
            ACC_11_reg    <= 16'sd0;
            valid_out_reg <= 1'b0;
        end else begin
            if (valid_in)   valid_out_reg <= 1'b1;
            else            valid_out_reg <= 1'b0;

            if (en_acc_00)  ACC_00_reg <= next_acc_00;
            if (en_acc_01)  ACC_01_reg <= next_acc_01;
            if (en_acc_10)  ACC_10_reg <= next_acc_10;
            if (en_acc_11)  ACC_11_reg <= next_acc_11;
        end
    end

    // Output Port Assignments
    assign valid_out = valid_out_reg;
    assign acc_00    = ACC_00_reg;
    assign acc_01    = (mode_2b == 2'b00) ? ACC_01_reg : 16'sd0;
    assign acc_10    = (mode_2b == 2'b00) ? ACC_10_reg : 16'sd0;
    assign acc_11    = ACC_11_reg;

    assign acc_row0  = $signed({ACC_01_reg[7:0], ACC_00_reg});
    assign acc_row1  = $signed({ACC_11_reg[7:0], ACC_10_reg});
    assign acc_col0  = $signed({ACC_10_reg[7:0], ACC_00_reg});
    assign acc_col1  = $signed({ACC_11_reg[7:0], ACC_01_reg});
    assign acc_32b   = $signed({ACC_11_reg, ACC_00_reg});

endmodule
