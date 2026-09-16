//-----------------------------------------------------------------------------
// Module: mac_reconfig_2d_baugh_wooley_nvfp4.sv
// Description: LOW-POWER OPTIMIZED 2D Reconfigurable 2x2 MAC Tile supporting INT4 & NVFP4
//              (Microscaling E2M1 Block Floating-Point) with Clean Multi-Format Dispatch.
// Precision Modes (mode_2b):
//   - 00: 4x4 SIMD (4 parallel MACs)
//   - 01: Dual 8x4 Horizontal Fusion (2 parallel 8x4 MACs)
//   - 10: Dual 4x8 Vertical Fusion (2 parallel 4x8 MACs)
//   - 11: Unified 8x8 Mode (1 full 8x8 MAC with 32-bit Fused Accumulator)
// Feature Control (is_nvfp4[1:0]):
//   - 2'b00: INT4 x INT4 Mode
//   - 2'b01: INT4 Activation (A) x NVFP4 Microscaling Weight (B)
//   - 2'b10: NVFP4 Microscaling Weight (A) x INT4 Activation (B)
//   - 2'b11: NVFP4 x NVFP4 Microscaling Mode
// Technology: 45nm NanGate / FreePDK45 CMOS PDK @ 500 MHz
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SCL_PDK_SIM
// Simulation Models for SCL 180nm PDK Standard Cells (for Vivado local simulation)
module nvfp4_ah01d0 (
    output logic S,
    output logic CO,
    input  logic A,
    input  logic B
);
    assign S  = A ^ B;
    assign CO = A & B;
endmodule

module nvfp4_adp1d0 (
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

module nvfp4_an02d1 (
    output logic Z,
    input  logic A,
    input  logic B
);
    assign Z = A & B;
endmodule

module nvfp4_nd02d1 (
    output logic Z,
    input  logic A,
    input  logic B
);
    assign Z = ~(A & B);
endmodule
`endif

//=============================================================================
// 4x4 Baugh-Wooley Multiplier Core for NVFP4 Tile
//=============================================================================
module nvfp4_baugh_wooley_4b_pe (
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

    // Direct CSA Reduction Tree
    assign prod[0] = p00;

    logic s1, c1;
    nvfp4_ah01d0 u_ha_col1 (.S(s1), .CO(c1), .A(p10), .B(p01));
    assign prod[1] = s1;

    logic s2_0, c2_0, s2_1, c2_1;
    nvfp4_adp1d0 u_fa_col2 (.S(s2_0), .CO(c2_0), .P(), .A(p20), .B(p11), .CI(p02));
    nvfp4_ah01d0 u_ha_col2 (.S(s2_1), .CO(c2_1), .A(s2_0), .B(c1));
    assign prod[2] = s2_1;

    logic s3_0, c3_0, s3_1, c3_1, s3_2, c3_2;
    nvfp4_adp1d0 u_fa_col3_0 (.S(s3_0), .CO(c3_0), .P(), .A(p30), .B(p21), .CI(p12));
    nvfp4_adp1d0 u_fa_col3_1 (.S(s3_1), .CO(c3_1), .P(), .A(s3_0), .B(p03), .CI(bias_bit3));
    nvfp4_adp1d0 u_fa_col3_2 (.S(s3_2), .CO(c3_2), .P(), .A(s3_1), .B(c2_0), .CI(c2_1));
    assign prod[3] = s3_2;

    logic s4_0, c4_0, s4_1, c4_1, s4_2, c4_2;
    nvfp4_adp1d0 u_fa_col4_0 (.S(s4_0), .CO(c4_0), .P(), .A(p31), .B(p22), .CI(p13));
    nvfp4_adp1d0 u_fa_col4_1 (.S(s4_1), .CO(c4_1), .P(), .A(s4_0), .B(bias_bit4), .CI(c3_0));
    nvfp4_adp1d0 u_fa_col4_2 (.S(s4_2), .CO(c4_2), .P(), .A(s4_1), .B(c3_1), .CI(c3_2));
    assign prod[4] = s4_2;

    logic s5_0, c5_0, s5_1, c5_1;
    nvfp4_adp1d0 u_fa_col5_0 (.S(s5_0), .CO(c5_0), .P(), .A(p32), .B(p23), .CI(c4_0));
    nvfp4_adp1d0 u_fa_col5_1 (.S(s5_1), .CO(c5_1), .P(), .A(s5_0), .B(c4_1), .CI(c4_2));
    assign prod[5] = s5_1;

    logic s6_0, c6_0;
    nvfp4_adp1d0 u_fa_col6_0 (.S(s6_0), .CO(c6_0), .P(), .A(p33), .B(c5_0), .CI(c5_1));
    assign prod[6] = s6_0;

    assign prod[7] = bias_bit7 ^ c6_0;

endmodule

//=============================================================================
// Low-Power NVFP4 E2M1 Pre-Computed 2s-Complement Remapper Module
// Directly maps 4-bit NVFP4 [Sign S | Exponent E | Mantissa M] to 4-bit Signed 2s-Complement
//=============================================================================
module nvfp4_e2m1_remapper (
    input  logic [3:0] nvfp4_in,
    output logic signed [3:0] rem_signed
);
    always_comb begin
        case (nvfp4_in)
            // Positive NVFP4 Values (Sign bit S = 0)
            4'b0000: rem_signed = 4'sd0;   // +0.0 -> 0
            4'b0001: rem_signed = 4'sd1;   // +0.5 -> +1
            4'b0010: rem_signed = 4'sd2;   // +1.0 -> +2
            4'b0011: rem_signed = 4'sd3;   // +1.5 -> +3
            4'b0100: rem_signed = 4'sd4;   // +2.0 -> +4
            4'b0101: rem_signed = 4'sd6;   // +3.0 -> +6
            4'b0110: rem_signed = 4'sd7;   // +4.0 -> +7
            4'b0111: rem_signed = 4'sd7;   // +6.0 -> +7

            // Negative NVFP4 Values (Sign bit S = 1) - Pre-computed 2s Complement
            4'b1000: rem_signed = 4'sd0;   // -0.0 -> 0
            4'b1001: rem_signed = -4'sd1;  // -0.5 -> -1 (4'b1111)
            4'b1010: rem_signed = -4'sd2;  // -1.0 -> -2 (4'b1110)
            4'b1011: rem_signed = -4'sd3;  // -1.5 -> -3 (4'b1101)
            4'b1100: rem_signed = -4'sd4;  // -2.0 -> -4 (4'b1100)
            4'b1101: rem_signed = -4'sd6;  // -3.0 -> -6 (4'b1010)
            4'b1110: rem_signed = -4'sd7;  // -4.0 -> -7 (4'b1001)
            4'b1111: rem_signed = -4'sd7;  // -6.0 -> -7 (4'b1001)
            default: rem_signed = 4'sd0;
        endcase
    end
endmodule

//=============================================================================
// Top-Level 2D Reconfigurable MAC Tile with Minimal Overhead NVFP4 & INT4 Support
//=============================================================================
module mac_reconfig_2d_baugh_wooley_nvfp4 (
    input  logic              clk,
    input  logic              rst_n,
    input  logic [1:0]        mode_2b,
    input  logic [1:0]        is_nvfp4,    // 2'b00 = INT4xINT4, 2'b01 = INT4_A x NVFP4_B, 2'b10 = NVFP4_A x INT4_B, 2'b11 = NVFP4xNVFP4
    input  logic [7:0]        scale_block, // Shared block scale exponent offset
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

    // Format Control Decoders
    wire is_nvfp4_a = is_nvfp4[1];
    wire is_nvfp4_b = is_nvfp4[0];

    // Remapper Instances
    logic signed [3:0] rem_a0, rem_b0, rem_a1, rem_b1;
    logic signed [3:0] rem_a2, rem_b2, rem_a3, rem_b3;

    nvfp4_e2m1_remapper u_rem_a0 (.nvfp4_in(A0), .rem_signed(rem_a0));
    nvfp4_e2m1_remapper u_rem_b0 (.nvfp4_in(B0), .rem_signed(rem_b0));
    nvfp4_e2m1_remapper u_rem_a1 (.nvfp4_in(A1), .rem_signed(rem_a1));
    nvfp4_e2m1_remapper u_rem_b1 (.nvfp4_in(B1), .rem_signed(rem_b1));
    nvfp4_e2m1_remapper u_rem_a2 (.nvfp4_in(A2), .rem_signed(rem_a2));
    nvfp4_e2m1_remapper u_rem_b2 (.nvfp4_in(B2), .rem_signed(rem_b2));
    nvfp4_e2m1_remapper u_rem_a3 (.nvfp4_in(A3), .rem_signed(rem_a3));
    nvfp4_e2m1_remapper u_rem_b3 (.nvfp4_in(B3), .rem_signed(rem_b3));

    // Dynamic Input Operand Selection & Valid-Gating (Minimal Single-Layer MUX)
    logic signed [3:0] a0_in, b0_in, a1_in, b1_in;
    logic signed [3:0] a2_in, b2_in, a3_in, b3_in;

    always_comb begin
        if (!valid_in) begin
            a0_in = 4'sd0; b0_in = 4'sd0;
            a1_in = 4'sd0; b1_in = 4'sd0;
            a2_in = 4'sd0; b2_in = 4'sd0;
            a3_in = 4'sd0; b3_in = 4'sd0;
        end else begin
            case (is_nvfp4)
                2'b00: begin // INT4 x INT4 Mode
                    a0_in = A0;     b0_in = B0;
                    a1_in = A1;     b1_in = B1;
                    a2_in = A2;     b2_in = B2;
                    a3_in = A3;     b3_in = B3;
                end
                2'b01: begin // INT4_A x NVFP4_B Mode
                    a0_in = A0;     b0_in = rem_b0;
                    a1_in = A1;     b1_in = rem_b1;
                    a2_in = A2;     b2_in = rem_b2;
                    a3_in = A3;     b3_in = rem_b3;
                end
                2'b10: begin // NVFP4_A x INT4_B Mode
                    a0_in = rem_a0; b0_in = B0;
                    a1_in = rem_a1; b1_in = B1;
                    a2_in = rem_a2; b2_in = B2;
                    a3_in = rem_a3; b3_in = B3;
                end
                2'b11: begin // NVFP4 x NVFP4 Mode
                    a0_in = rem_a0; b0_in = rem_b0;
                    a1_in = rem_a1; b1_in = rem_b1;
                    a2_in = rem_a2; b2_in = rem_b2;
                    a3_in = rem_a3; b3_in = rem_b3;
                end
            endcase
        end
    end

    //-------------------------------------------------------------------------
    // 2. Universal Sign Pre-Encoding Matrix
    //-------------------------------------------------------------------------
    logic sign_a_00, sign_b_00;
    logic sign_a_01, sign_b_01;
    logic sign_a_10, sign_b_10;
    logic sign_a_11, sign_b_11;

    assign sign_a_00 = ~mode_2b[0];
    assign sign_b_00 = ~mode_2b[1];
    assign sign_a_01 = 1'b1;
    assign sign_b_01 = ~mode_2b[1];
    assign sign_a_10 = ~mode_2b[0];
    assign sign_b_10 = 1'b1;
    assign sign_a_11 = 1'b1;
    assign sign_b_11 = 1'b1;

    //-------------------------------------------------------------------------
    // 3. Direct Native Baugh-Wooley Multiplier PEs
    //-------------------------------------------------------------------------
    logic signed [7:0] P_00_raw, P_01_raw, P_10_raw, P_11_raw;

    nvfp4_baugh_wooley_4b_pe u_pe00 (.a(a0_in), .b(b0_in), .sign_a(sign_a_00), .sign_b(sign_b_00), .prod(P_00_raw));
    nvfp4_baugh_wooley_4b_pe u_pe01 (.a(a1_in), .b(b1_in), .sign_a(sign_a_01), .sign_b(sign_b_01), .prod(P_01_raw));
    nvfp4_baugh_wooley_4b_pe u_pe10 (.a(a2_in), .b(b2_in), .sign_a(sign_a_10), .sign_b(sign_b_10), .prod(P_10_raw));
    nvfp4_baugh_wooley_4b_pe u_pe11 (.a(a3_in), .b(b3_in), .sign_a(sign_a_11), .sign_b(sign_b_11), .prod(P_11_raw));

    //-------------------------------------------------------------------------
    // 3b. Mode Decoding
    //-------------------------------------------------------------------------
    logic mode_is_4b, mode_is_8x4, mode_is_4x8, mode_is_8b;
    assign mode_is_4b  = (mode_2b == 2'b00);
    assign mode_is_8x4 = (mode_2b == 2'b01);
    assign mode_is_4x8 = (mode_2b == 2'b10);
    assign mode_is_8b  = (mode_2b == 2'b11);

    //-------------------------------------------------------------------------
    // 4. Shared Merge Units (mergeA, mergeB)
    //-------------------------------------------------------------------------
    logic [7:0] mergeA_hi_in, mergeB_lo_in;

    assign mergeA_hi_in = mode_is_4x8 ? P_10_raw : P_01_raw;
    assign mergeB_lo_in = mode_is_4x8 ? P_01_raw : P_10_raw;

    logic signed [15:0] mergeA_out;
    logic signed [15:0] mergeB_out;

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

    // Mode 11: Unified 8x8 Mode Partial Product Fusion Tree
    logic signed [15:0] P_00_8b_ext, P_01_8b_ext, P_10_8b_ext, P_11_8b_ext;
    logic signed [15:0] mid_sum_8b;
    logic signed [15:0] P_8b;

    assign P_00_8b_ext = mode_is_8b ? {8'b0, P_00_raw} : 16'sd0;
    assign P_01_8b_ext = mode_is_8b ? {{8{P_01_raw[7]}}, P_01_raw} : 16'sd0;
    assign P_10_8b_ext = mode_is_8b ? {{8{P_10_raw[7]}}, P_10_raw} : 16'sd0;
    assign P_11_8b_ext = mode_is_8b ? {{8{P_11_raw[7]}}, P_11_raw} : 16'sd0;

    assign mid_sum_8b  = P_01_8b_ext + P_10_8b_ext;
    assign P_8b        = P_00_8b_ext + (mid_sum_8b << 4) + (P_11_8b_ext << 8);

    //-------------------------------------------------------------------------
    // 5. Direct Low-Power Accumulator Core
    //-------------------------------------------------------------------------
    logic signed [15:0] ACC_00_reg, ACC_01_reg, ACC_10_reg, ACC_11_reg;
    logic               valid_out_reg;

    logic signed [23:0] curr_row0, next_row0;
    logic signed [23:0] curr_row1, next_row1;
    logic signed [23:0] curr_col0, next_col0;
    logic signed [23:0] curr_col1, next_col1;
    logic signed [31:0] curr_acc_8b, next_acc_8b;

    assign curr_row0    = $signed({ACC_01_reg[7:0], ACC_00_reg});
    assign next_row0    = clr_acc ? {{8{P_row0[15]}}, P_row0} : (curr_row0 + {{8{P_row0[15]}}, P_row0});

    assign curr_row1    = $signed({ACC_11_reg[7:0], ACC_10_reg});
    assign next_row1    = clr_acc ? {{8{P_row1[15]}}, P_row1} : (curr_row1 + {{8{P_row1[15]}}, P_row1});

    assign curr_col0    = $signed({ACC_10_reg[7:0], ACC_00_reg});
    assign next_col0    = clr_acc ? {{8{P_col0[15]}}, P_col0} : (curr_col0 + {{8{P_col0[15]}}, P_col0});

    assign curr_col1    = $signed({ACC_11_reg[7:0], ACC_01_reg});
    assign next_col1    = clr_acc ? {{8{P_col1[15]}}, P_col1} : (curr_col1 + {{8{P_col1[15]}}, P_col1});

    assign curr_acc_8b  = $signed({ACC_11_reg, ACC_00_reg});
    assign next_acc_8b  = clr_acc ? {{16{P_8b[15]}}, P_8b} : (curr_acc_8b + {{16{P_8b[15]}}, P_8b});

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ACC_00_reg    <= 16'sd0;
            ACC_01_reg    <= 16'sd0;
            ACC_10_reg    <= 16'sd0;
            ACC_11_reg    <= 16'sd0;
            valid_out_reg <= 1'b0;
        end else if (valid_in) begin
            valid_out_reg <= 1'b1;
            case (mode_2b)
                2'b00: begin // Quad 4x4 SIMD Mode
                    ACC_00_reg <= clr_acc ? {{8{P_00_raw[7]}}, P_00_raw} : (ACC_00_reg + {{8{P_00_raw[7]}}, P_00_raw});
                    ACC_01_reg <= clr_acc ? {{8{P_01_raw[7]}}, P_01_raw} : (ACC_01_reg + {{8{P_01_raw[7]}}, P_01_raw});
                    ACC_10_reg <= clr_acc ? {{8{P_10_raw[7]}}, P_10_raw} : (ACC_10_reg + {{8{P_10_raw[7]}}, P_10_raw});
                    ACC_11_reg <= clr_acc ? {{8{P_11_raw[7]}}, P_11_raw} : (ACC_11_reg + {{8{P_11_raw[7]}}, P_11_raw});
                end
                2'b01: begin // Dual 8x4 Horizontal Fusion
                    ACC_00_reg <= next_row0[15:0];
                    ACC_01_reg <= {{8{next_row0[23]}}, next_row0[23:16]};
                    ACC_10_reg <= next_row1[15:0];
                    ACC_11_reg <= {{8{next_row1[23]}}, next_row1[23:16]};
                end
                2'b10: begin // Dual 4x8 Vertical Fusion
                    ACC_00_reg <= next_col0[15:0];
                    ACC_10_reg <= {{8{next_col0[23]}}, next_col0[23:16]};
                    ACC_01_reg <= next_col1[15:0];
                    ACC_11_reg <= {{8{next_col1[23]}}, next_col1[23:16]};
                end
                2'b11: begin // Unified 8x8 Mode
                    ACC_00_reg <= next_acc_8b[15:0];
                    ACC_11_reg <= next_acc_8b[31:16];
                    if (clr_acc) begin
                        ACC_01_reg <= 16'sd0;
                        ACC_10_reg <= 16'sd0;
                    end
                end
            endcase
        end else begin
            valid_out_reg <= 1'b0;
        end
    end

    //-------------------------------------------------------------------------
    // 6. Output Port Assignments
    //-------------------------------------------------------------------------
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
