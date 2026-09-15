//-----------------------------------------------------------------------------
// Module: mac_reconfig_unified_tile.sv
// Description: Lean Single-Layer Unified INTxINT / FPxFP / INTxFP 2x2 Reconfigurable MAC Tile.
//              Optimized with 9-bit pre-sign aligners and shared baseline CSA fusion.
// Technology: SCL 180nm CMOS PDK
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SCL_PDK_SIM
module ah01d0 (output logic S, output logic CO, input logic A, input logic B);
    assign S  = A ^ B;
    assign CO = A & B;
endmodule

module adp1d0 (output logic S, output logic CO, output logic P, input logic A, input logic B, input logic CI);
    assign S  = A ^ B ^ CI;
    assign CO = (A & B) | (B & CI) | (A & CI);
    assign P  = A ^ B;
endmodule
`endif

//=============================================================================
// 4x4 Multiplier Core (Shared across all 12 modes)
//=============================================================================
module unified_baugh_wooley_4b_pe (
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

    assign p00 = a[0] & b[0];
    assign p10 = a[1] & b[0];
    assign p20 = a[2] & b[0];
    assign p30 = (a[3] & b[0]) ^ sign_a;

    assign p01 = a[0] & b[1];
    assign p11 = a[1] & b[1];
    assign p21 = a[2] & b[1];
    assign p31 = (a[3] & b[1]) ^ sign_a;

    assign p02 = a[0] & b[2];
    assign p12 = a[1] & b[2];
    assign p22 = a[2] & b[2];
    assign p32 = (a[3] & b[2]) ^ sign_a;

    assign p03 = (a[0] & b[3]) ^ sign_b;
    assign p13 = (a[1] & b[3]) ^ sign_b;
    assign p23 = (a[2] & b[3]) ^ sign_b;
    assign p33 = (a[3] & b[3]) ^ (sign_a ^ sign_b);

    logic bias_bit3, bias_bit4, bias_bit7;
    assign bias_bit3 = sign_a ^ sign_b;
    assign bias_bit4 = sign_a & sign_b;
    assign bias_bit7 = sign_a | sign_b;

    assign prod[0] = p00;

    logic s1, c1;
    ah01d0 u_ha1 (.S(s1), .CO(c1), .A(p10), .B(p01));
    assign prod[1] = s1;

    logic s2_0, c2_0, s2_1, c2_1;
    adp1d0 u_fa2 (.S(s2_0), .CO(c2_0), .P(), .A(p20), .B(p11), .CI(p02));
    ah01d0 u_ha2 (.S(s2_1), .CO(c2_1), .A(s2_0), .B(c1));
    assign prod[2] = s2_1;

    logic s3_0, c3_0, s3_1, c3_1, s3_2, c3_2;
    adp1d0 u_fa3_0 (.S(s3_0), .CO(c3_0), .P(), .A(p30), .B(p21), .CI(p12));
    adp1d0 u_fa3_1 (.S(s3_1), .CO(c3_1), .P(), .A(s3_0), .B(p03), .CI(bias_bit3));
    adp1d0 u_fa3_2 (.S(s3_2), .CO(c3_2), .P(), .A(s3_1), .B(c2_0), .CI(c2_1));
    assign prod[3] = s3_2;

    logic s4_0, c4_0, s4_1, c4_1, s4_2, c4_2;
    adp1d0 u_fa4_0 (.S(s4_0), .CO(c4_0), .P(), .A(p31), .B(p22), .CI(p13));
    adp1d0 u_fa4_1 (.S(s4_1), .CO(c4_1), .P(), .A(s4_0), .B(bias_bit4), .CI(c3_0));
    adp1d0 u_fa4_2 (.S(s4_2), .CO(c4_2), .P(), .A(s4_1), .B(c3_1), .CI(c3_2));
    assign prod[4] = s4_2;

    logic s5_0, c5_0, s5_1, c5_1;
    adp1d0 u_fa5_0 (.S(s5_0), .CO(c5_0), .P(), .A(p32), .B(p23), .CI(c4_0));
    adp1d0 u_fa5_1 (.S(s5_1), .CO(c5_1), .P(), .A(s5_0), .B(c4_1), .CI(c4_2));
    assign prod[5] = s5_1;

    logic s6_0, c6_0;
    adp1d0 u_fa6_0 (.S(s6_0), .CO(c6_0), .P(), .A(p33), .B(c5_0), .CI(c5_1));
    assign prod[6] = s6_0;

    assign prod[7] = bias_bit7 ^ c6_0;

endmodule

//=============================================================================
// Top-Level Lean Single-Layer 12-Mode Reconfigurable MAC Tile
//=============================================================================
module mac_reconfig_unified_tile (
    input  logic              clk,
    input  logic              rst_n,
    input  logic [1:0]        mode_2b,    // 00: Quad, 01: Row Fuse, 10: Col Fuse, 11: Unified
    input  logic              type_a,     // 0: INT, 1: FP
    input  logic              type_b,     // 0: INT, 1: FP
    input  logic [1:0]        format_a,   // If INT: 0=INT4, 1=INT8 | If FP: 0=E4M3, 1=E5M2, 2=E2M1
    input  logic [1:0]        format_b,   // If INT: 0=INT4, 1=INT8 | If FP: 0=E4M3, 1=E5M2, 2=E2M1
    input  logic              valid_in,
    input  logic              clr_acc,

    // Operand Inputs
    input  logic [7:0]        A0_in, B0_in,
    input  logic [7:0]        A1_in, B1_in,
    input  logic [7:0]        A2_in, B2_in,
    input  logic [7:0]        A3_in, B3_in,

    output logic              valid_out,
    output logic signed [15:0] acc_00,
    output logic signed [15:0] acc_01,
    output logic signed [15:0] acc_10,
    output logic signed [15:0] acc_11,
    output logic signed [23:0] acc_row0,
    output logic signed [23:0] acc_row1,
    output logic signed [23:0] acc_col0,
    output logic signed [23:0] acc_col1,
    output logic signed [31:0] acc_32b,
    output logic signed [5:0]  block_exp
);

    wire is_pure_int = (~type_a) & (~type_b);
    wire is_pure_fp  = type_a & type_b;
    wire is_mixed    = type_a ^ type_b;

    //=========================================================================
    // 1. Static Front-End Unpacking (Minimal MUX trees)
    //=========================================================================
    // FP Slicing
    wire [3:0] fp_mag_a0 = (format_a == 2'b00) ? {(A0_in[6:3] != 4'b0), A0_in[2:0]} :
                          ((format_a == 2'b01) ? {(A0_in[6:2] != 5'b0), A0_in[1:0], 1'b0} : {(A0_in[2:1] != 2'b0), A0_in[0], 2'b0});
    wire [3:0] fp_mag_a1 = (format_a == 2'b00) ? {(A1_in[6:3] != 4'b0), A1_in[2:0]} :
                          ((format_a == 2'b01) ? {(A1_in[6:2] != 5'b0), A1_in[1:0], 1'b0} : {(A1_in[2:1] != 2'b0), A1_in[0], 2'b0});
    wire [3:0] fp_mag_a2 = (format_a == 2'b00) ? {(A2_in[6:3] != 4'b0), A2_in[2:0]} :
                          ((format_a == 2'b01) ? {(A2_in[6:2] != 5'b0), A2_in[1:0], 1'b0} : {(A2_in[2:1] != 2'b0), A2_in[0], 2'b0});
    wire [3:0] fp_mag_a3 = (format_a == 2'b00) ? {(A3_in[6:3] != 4'b0), A3_in[2:0]} :
                          ((format_a == 2'b01) ? {(A3_in[6:2] != 5'b0), A3_in[1:0], 1'b0} : {(A3_in[2:1] != 2'b0), A3_in[0], 2'b0});

    wire [3:0] fp_mag_b0 = (format_b == 2'b00) ? {(B0_in[6:3] != 4'b0), B0_in[2:0]} :
                          ((format_b == 2'b01) ? {(B0_in[6:2] != 5'b0), B0_in[1:0], 1'b0} : {(B0_in[2:1] != 2'b0), B0_in[0], 2'b0});
    wire [3:0] fp_mag_b1 = (format_b == 2'b00) ? {(B1_in[6:3] != 4'b0), B1_in[2:0]} :
                          ((format_b == 2'b01) ? {(B1_in[6:2] != 5'b0), B1_in[1:0], 1'b0} : {(B1_in[2:1] != 2'b0), B1_in[0], 2'b0});
    wire [3:0] fp_mag_b2 = (format_b == 2'b00) ? {(B2_in[6:3] != 4'b0), B2_in[2:0]} :
                          ((format_b == 2'b01) ? {(B2_in[6:2] != 5'b0), B2_in[1:0], 1'b0} : {(B2_in[2:1] != 2'b0), B2_in[0], 2'b0});
    wire [3:0] fp_mag_b3 = (format_b == 2'b00) ? {(B3_in[6:3] != 4'b0), B3_in[2:0]} :
                          ((format_b == 2'b01) ? {(B3_in[6:2] != 5'b0), B3_in[1:0], 1'b0} : {(B3_in[2:1] != 2'b0), B3_in[0], 2'b0});

    wire [4:0] fp_exp_a0 = (format_a == 2'b00) ? {1'b0, A0_in[6:3]} : ((format_a == 2'b01) ? A0_in[6:2] : {3'b0, A0_in[2:1]});
    wire [4:0] fp_exp_a1 = (format_a == 2'b00) ? {1'b0, A1_in[6:3]} : ((format_a == 2'b01) ? A1_in[6:2] : {3'b0, A1_in[2:1]});
    wire [4:0] fp_exp_a2 = (format_a == 2'b00) ? {1'b0, A2_in[6:3]} : ((format_a == 2'b01) ? A2_in[6:2] : {3'b0, A2_in[2:1]});
    wire [4:0] fp_exp_a3 = (format_a == 2'b00) ? {1'b0, A3_in[6:3]} : ((format_a == 2'b01) ? A3_in[6:2] : {3'b0, A3_in[2:1]});

    wire [4:0] fp_exp_b0 = (format_b == 2'b00) ? {1'b0, B0_in[6:3]} : ((format_b == 2'b01) ? B0_in[6:2] : {3'b0, B0_in[2:1]});
    wire [4:0] fp_exp_b1 = (format_b == 2'b00) ? {1'b0, B1_in[6:3]} : ((format_b == 2'b01) ? B1_in[6:2] : {3'b0, B1_in[2:1]});
    wire [4:0] fp_exp_b2 = (format_b == 2'b00) ? {1'b0, B2_in[6:3]} : ((format_b == 2'b01) ? B2_in[6:2] : {3'b0, B2_in[2:1]});
    wire [4:0] fp_exp_b3 = (format_b == 2'b00) ? {1'b0, B3_in[6:3]} : ((format_b == 2'b01) ? B3_in[6:2] : {3'b0, B3_in[2:1]});

    wire fp_sign_a0 = (format_a == 2'b10) ? A0_in[3] : A0_in[7];
    wire fp_sign_a1 = (format_a == 2'b10) ? A1_in[3] : A1_in[7];
    wire fp_sign_a2 = (format_a == 2'b10) ? A2_in[3] : A2_in[7];
    wire fp_sign_a3 = (format_a == 2'b10) ? A3_in[3] : A3_in[7];

    wire fp_sign_b0 = (format_b == 2'b10) ? B0_in[3] : B0_in[7];
    wire fp_sign_b1 = (format_b == 2'b10) ? B1_in[3] : B1_in[7];
    wire fp_sign_b2 = (format_b == 2'b10) ? B2_in[3] : B2_in[7];
    wire fp_sign_b3 = (format_b == 2'b10) ? B3_in[3] : B3_in[7];

    // Mixed INT Sign-Magnitude Unpacking (Sharing absolute value adders)
    wire s_a0_i = format_a[0] ? A0_in[7] : A0_in[3];
    wire s_a1_i = format_a[0] ? A0_in[7] : A1_in[3];
    wire s_a2_i = format_a[0] ? A2_in[7] : A2_in[3];
    wire s_a3_i = format_a[0] ? A2_in[7] : A3_in[3];

    wire [7:0] abs_a0 = s_a0_i ? (~A0_in + 8'd1) : A0_in;
    wire [7:0] abs_a1 = (mode_2b == 2'b00 && s_a1_i) ? (~A1_in + 8'd1) : (mode_2b == 2'b00 ? A1_in : abs_a0);
    wire [7:0] abs_a2 = s_a2_i ? (~A2_in + 8'd1) : A2_in;
    wire [7:0] abs_a3 = (mode_2b == 2'b00 && s_a3_i) ? (~A3_in + 8'd1) : (mode_2b == 2'b00 ? A3_in : abs_a2);

    wire s_b0_i = format_b[0] ? B0_in[7] : B0_in[3];
    wire s_b1_i = format_b[0] ? B1_in[7] : B1_in[3];
    wire [7:0] abs_b0 = s_b0_i ? (~B0_in + 8'd1) : B0_in;
    wire [7:0] abs_b1 = s_b1_i ? (~B1_in + 8'd1) : B1_in;

    // Multiplier Inputs
    logic [3:0] pe_a0, pe_a1, pe_a2, pe_a3;
    logic [3:0] pe_b0, pe_b1, pe_b2, pe_b3;
    logic       sign_a_0, sign_a_1, sign_a_2, sign_a_3;
    logic       sign_b_0, sign_b_1, sign_b_2, sign_b_3;
    logic       prod_sign_0, prod_sign_1, prod_sign_2, prod_sign_3;

    always_comb begin
        if (is_pure_int) begin
            pe_a0 = valid_in ? A0_in[3:0] : 4'h0;
            pe_a1 = valid_in ? A1_in[3:0] : 4'h0;
            pe_a2 = valid_in ? A2_in[3:0] : 4'h0;
            pe_a3 = valid_in ? A3_in[3:0] : 4'h0;

            pe_b0 = valid_in ? B0_in[3:0] : 4'h0;
            pe_b1 = valid_in ? B1_in[3:0] : 4'h0;
            pe_b2 = valid_in ? B2_in[3:0] : 4'h0;
            pe_b3 = valid_in ? B3_in[3:0] : 4'h0;

            sign_a_0 = ~mode_2b[0]; sign_b_0 = ~mode_2b[1];
            sign_a_1 = 1'b1;        sign_b_1 = ~mode_2b[1];
            sign_a_2 = ~mode_2b[0]; sign_b_2 = 1'b1;
            sign_a_3 = 1'b1;        sign_b_3 = 1'b1;

            prod_sign_0 = 1'b0; prod_sign_1 = 1'b0; prod_sign_2 = 1'b0; prod_sign_3 = 1'b0;
        end else if (is_pure_fp) begin
            pe_a0 = valid_in ? fp_mag_a0 : 4'h0;
            pe_a1 = valid_in ? fp_mag_a1 : 4'h0;
            pe_a2 = valid_in ? fp_mag_a2 : 4'h0;
            pe_a3 = valid_in ? fp_mag_a3 : 4'h0;

            pe_b0 = valid_in ? fp_mag_b0 : 4'h0;
            pe_b1 = valid_in ? fp_mag_b1 : 4'h0;
            pe_b2 = valid_in ? fp_mag_b2 : 4'h0;
            pe_b3 = valid_in ? fp_mag_b3 : 4'h0;

            sign_a_0 = 1'b0; sign_b_0 = 1'b0;
            sign_a_1 = 1'b0; sign_b_1 = 1'b0;
            sign_a_2 = 1'b0; sign_b_2 = 1'b0;
            sign_a_3 = 1'b0; sign_b_3 = 1'b0;

            prod_sign_0 = fp_sign_a0 ^ fp_sign_b0;
            prod_sign_1 = fp_sign_a1 ^ fp_sign_b1;
            prod_sign_2 = fp_sign_a2 ^ fp_sign_b2;
            prod_sign_3 = fp_sign_a3 ^ fp_sign_b3;
        end else if (!type_a && type_b) begin // INT x FP
            sign_a_0 = 1'b0; sign_b_0 = 1'b0;
            sign_a_1 = 1'b0; sign_b_1 = 1'b0;
            sign_a_2 = 1'b0; sign_b_2 = 1'b0;
            sign_a_3 = 1'b0; sign_b_3 = 1'b0;

            if (mode_2b == 2'b00) begin
                pe_a0 = valid_in ? abs_a0[3:0] : 4'h0;
                pe_a1 = valid_in ? abs_a1[3:0] : 4'h0;
                pe_a2 = valid_in ? abs_a2[3:0] : 4'h0;
                pe_a3 = valid_in ? abs_a3[3:0] : 4'h0;

                pe_b0 = valid_in ? fp_mag_b0 : 4'h0;
                pe_b1 = valid_in ? fp_mag_b1 : 4'h0;
                pe_b2 = valid_in ? fp_mag_b2 : 4'h0;
                pe_b3 = valid_in ? fp_mag_b3 : 4'h0;

                prod_sign_0 = s_a0_i ^ fp_sign_b0;
                prod_sign_1 = s_a1_i ^ fp_sign_b1;
                prod_sign_2 = s_a2_i ^ fp_sign_b2;
                prod_sign_3 = s_a3_i ^ fp_sign_b3;
            end else begin
                pe_a0 = valid_in ? abs_a0[3:0] : 4'h0;
                pe_a1 = valid_in ? abs_a0[7:4] : 4'h0;
                pe_a2 = valid_in ? abs_a2[3:0] : 4'h0;
                pe_a3 = valid_in ? abs_a2[7:4] : 4'h0;

                pe_b0 = valid_in ? fp_mag_b0 : 4'h0;
                pe_b1 = valid_in ? fp_mag_b0 : 4'h0;
                pe_b2 = valid_in ? fp_mag_b2 : 4'h0;
                pe_b3 = valid_in ? fp_mag_b2 : 4'h0;

                prod_sign_0 = s_a0_i ^ fp_sign_b0;
                prod_sign_1 = s_a0_i ^ fp_sign_b0;
                prod_sign_2 = s_a2_i ^ fp_sign_b2;
                prod_sign_3 = s_a2_i ^ fp_sign_b2;
            end
        end else begin // FP x INT
            sign_a_0 = 1'b0; sign_b_0 = 1'b0;
            sign_a_1 = 1'b0; sign_b_1 = 1'b0;
            sign_a_2 = 1'b0; sign_b_2 = 1'b0;
            sign_a_3 = 1'b0; sign_b_3 = 1'b0;

            pe_a0 = valid_in ? fp_mag_a0 : 4'h0;
            pe_a1 = valid_in ? fp_mag_a1 : 4'h0;
            pe_a2 = valid_in ? fp_mag_a0 : 4'h0;
            pe_a3 = valid_in ? fp_mag_a1 : 4'h0;

            pe_b0 = valid_in ? abs_b0[3:0] : 4'h0;
            pe_b1 = valid_in ? abs_b1[3:0] : 4'h0;
            pe_b2 = valid_in ? abs_b0[7:4] : 4'h0;
            pe_b3 = valid_in ? abs_b1[7:4] : 4'h0;

            prod_sign_0 = fp_sign_a0 ^ s_b0_i;
            prod_sign_1 = fp_sign_a1 ^ s_b1_i;
            prod_sign_2 = fp_sign_a0 ^ s_b0_i;
            prod_sign_3 = fp_sign_a1 ^ s_b1_i;
        end
    end

    //=========================================================================
    // 2. Multiplier Physical Cores (Shared)
    //=========================================================================
    logic [7:0] P_00_raw, P_01_raw, P_10_raw, P_11_raw;

    unified_baugh_wooley_4b_pe u_pe00 (.a(pe_a0), .b(pe_b0), .sign_a(sign_a_0), .sign_b(sign_b_0), .prod(P_00_raw));
    unified_baugh_wooley_4b_pe u_pe01 (.a(pe_a1), .b(pe_b1), .sign_a(sign_a_1), .sign_b(sign_b_1), .prod(P_01_raw));
    unified_baugh_wooley_4b_pe u_pe10 (.a(pe_a2), .b(pe_b2), .sign_a(sign_a_2), .sign_b(sign_b_2), .prod(P_10_raw));
    unified_baugh_wooley_4b_pe u_pe11 (.a(pe_a3), .b(pe_b3), .sign_a(sign_a_3), .sign_b(sign_b_3), .prod(P_11_raw));

    //=========================================================================
    // 3. Compact 8-bit Pre-Sign Aligner & Shared Exponent Logic
    //=========================================================================
    wire [5:0] exp_p0 = {1'b0, fp_exp_a0} + {1'b0, fp_exp_b0};
    wire [5:0] exp_p1 = {1'b0, fp_exp_a1} + {1'b0, fp_exp_b1};
    wire [5:0] exp_p2 = {1'b0, fp_exp_a2} + {1'b0, fp_exp_b2};
    wire [5:0] exp_p3 = {1'b0, fp_exp_a3} + {1'b0, fp_exp_b3};

    wire [5:0] max_r0   = (exp_p0 >= exp_p1) ? exp_p0 : exp_p1;
    wire [5:0] max_r1   = (exp_p2 >= exp_p3) ? exp_p2 : exp_p3;
    wire [5:0] max_c0   = (exp_p0 >= exp_p2) ? exp_p0 : exp_p2;
    wire [5:0] max_c1   = (exp_p1 >= exp_p3) ? exp_p1 : exp_p3;
    wire [5:0] max_tile = (max_r0 >= max_r1) ? max_r0 : max_r1;

    logic [4:0] max_w;
    assign max_w = (fp_exp_b0 >= fp_exp_b2) ? fp_exp_b0 : fp_exp_b2;

    logic [2:0] s0, s1, s2, s3;
    always_comb begin
        if (is_pure_fp) begin
            case (mode_2b)
                2'b00: begin s0 = 3'd0; s1 = 3'd0; s2 = 3'd0; s3 = 3'd0; end
                2'b01: begin
                    s0 = (max_r0 - exp_p0 >= 6'd7) ? 3'd7 : (max_r0[2:0] - exp_p0[2:0]);
                    s1 = (max_r0 - exp_p1 >= 6'd7) ? 3'd7 : (max_r0[2:0] - exp_p1[2:0]);
                    s2 = (max_r1 - exp_p2 >= 6'd7) ? 3'd7 : (max_r1[2:0] - exp_p2[2:0]);
                    s3 = (max_r1 - exp_p3 >= 6'd7) ? 3'd7 : (max_r1[2:0] - exp_p3[2:0]);
                end
                2'b10: begin
                    s0 = (max_c0 - exp_p0 >= 6'd7) ? 3'd7 : (max_c0[2:0] - exp_p0[2:0]);
                    s2 = (max_c0 - exp_p2 >= 6'd7) ? 3'd7 : (max_c0[2:0] - exp_p2[2:0]);
                    s1 = (max_c1 - exp_p1 >= 6'd7) ? 3'd7 : (max_c1[2:0] - exp_p1[2:0]);
                    s3 = (max_c1 - exp_p3 >= 6'd7) ? 3'd7 : (max_c1[2:0] - exp_p3[2:0]);
                end
                2'b11: begin
                    s0 = (max_tile - exp_p0 >= 6'd7) ? 3'd7 : (max_tile[2:0] - exp_p0[2:0]);
                    s1 = (max_tile - exp_p1 >= 6'd7) ? 3'd7 : (max_tile[2:0] - exp_p1[2:0]);
                    s2 = (max_tile - exp_p2 >= 6'd7) ? 3'd7 : (max_tile[2:0] - exp_p2[2:0]);
                    s3 = (max_tile - exp_p3 >= 6'd7) ? 3'd7 : (max_tile[2:0] - exp_p3[2:0]);
                end
            endcase
        end else if (is_mixed && mode_2b == 2'b11) begin
            s0 = (max_w - fp_exp_b0 >= 5'd7) ? 3'd7 : (max_w[2:0] - fp_exp_b0[2:0]);
            s1 = s0;
            s2 = (max_w - fp_exp_b2 >= 5'd7) ? 3'd7 : (max_w[2:0] - fp_exp_b2[2:0]);
            s3 = s2;
        end else begin
            s0 = 3'd0; s1 = 3'd0; s2 = 3'd0; s3 = 3'd0;
        end
    end

    // Compact 8-bit Shifters
    wire [7:0] p0_sh = P_00_raw >> s0;
    wire [7:0] p1_sh = P_01_raw >> s1;
    wire [7:0] p2_sh = P_10_raw >> s2;
    wire [7:0] p3_sh = P_11_raw >> s3;

    // Compact 9-bit Signed Product Converters
    wire signed [8:0] s_prod_0 = prod_sign_0 ? (-{1'b0, p0_sh}) : {1'b0, p0_sh};
    wire signed [8:0] s_prod_1 = prod_sign_1 ? (-{1'b0, p1_sh}) : {1'b0, p1_sh};
    wire signed [8:0] s_prod_2 = prod_sign_2 ? (-{1'b0, p2_sh}) : {1'b0, p2_sh};
    wire signed [8:0] s_prod_3 = prod_sign_3 ? (-{1'b0, p3_sh}) : {1'b0, p3_sh};

    wire signed [8:0] s_raw_prod_0 = prod_sign_0 ? (-{1'b0, P_00_raw}) : {1'b0, P_00_raw};
    wire signed [8:0] s_raw_prod_1 = prod_sign_1 ? (-{1'b0, P_01_raw}) : {1'b0, P_01_raw};
    wire signed [8:0] s_raw_prod_2 = prod_sign_2 ? (-{1'b0, P_10_raw}) : {1'b0, P_10_raw};
    wire signed [8:0] s_raw_prod_3 = prod_sign_3 ? (-{1'b0, P_11_raw}) : {1'b0, P_11_raw};

    //=========================================================================
    // 4. Unified Spatial Terms
    //=========================================================================
    logic signed [15:0] term_0, term_1, term_2, term_3;

    always_comb begin
        if (is_pure_int) begin
            case (mode_2b)
                2'b00: begin
                    term_0 = $signed({{8{P_00_raw[7]}}, P_00_raw});
                    term_1 = $signed({{8{P_01_raw[7]}}, P_01_raw});
                    term_2 = $signed({{8{P_10_raw[7]}}, P_10_raw});
                    term_3 = $signed({{8{P_11_raw[7]}}, P_11_raw});
                end
                2'b01: begin
                    term_0 = $signed({{8{P_00_raw[7]}}, P_00_raw});
                    term_1 = $signed({{4{P_01_raw[7]}}, P_01_raw, 4'b0});
                    term_2 = $signed({{8{P_10_raw[7]}}, P_10_raw});
                    term_3 = $signed({{4{P_11_raw[7]}}, P_11_raw, 4'b0});
                end
                2'b10: begin
                    term_0 = $signed({{8{P_00_raw[7]}}, P_00_raw});
                    term_2 = $signed({{4{P_10_raw[7]}}, P_10_raw, 4'b0});
                    term_1 = $signed({{8{P_01_raw[7]}}, P_01_raw});
                    term_3 = $signed({{4{P_11_raw[7]}}, P_11_raw, 4'b0});
                end
                2'b11: begin
                    term_0 = $signed({8'b0, P_00_raw});
                    term_1 = $signed({{4{P_01_raw[7]}}, P_01_raw, 4'b0});
                    term_2 = $signed({{4{P_10_raw[7]}}, P_10_raw, 4'b0});
                    term_3 = $signed({P_11_raw, 8'b0});
                end
            endcase
        end else if (is_mixed) begin
            if (mode_2b == 2'b00) begin
                term_0 = $signed({{7{s_prod_0[8]}}, s_prod_0});
                term_1 = $signed({{7{s_prod_1[8]}}, s_prod_1});
                term_2 = $signed({{7{s_prod_2[8]}}, s_prod_2});
                term_3 = $signed({{7{s_prod_3[8]}}, s_prod_3});
            end else if (type_a) begin // FP x INT (Modes 01, 10, 11)
                term_0 = $signed({{7{s_raw_prod_0[8]}}, s_raw_prod_0});
                term_1 = $signed({{7{s_raw_prod_1[8]}}, s_raw_prod_1});
                term_2 = $signed({{3{s_raw_prod_2[8]}}, s_raw_prod_2, 4'h0});
                term_3 = $signed({{3{s_raw_prod_3[8]}}, s_raw_prod_3, 4'h0});
            end else begin // INT x FP (Modes 01, 10, 11)
                term_0 = $signed({{7{s_prod_0[8]}}, s_prod_0});
                term_1 = $signed({{3{s_prod_1[8]}}, s_prod_1, 4'h0});
                term_2 = $signed({{7{s_prod_2[8]}}, s_prod_2});
                term_3 = $signed({{3{s_prod_3[8]}}, s_prod_3, 4'h0});
            end
        end else begin // Pure FP (Modes 00, 01, 10, 11)
            term_0 = $signed({{7{s_prod_0[8]}}, s_prod_0});
            term_1 = $signed({{7{s_prod_1[8]}}, s_prod_1});
            term_2 = $signed({{7{s_prod_2[8]}}, s_prod_2});
            term_3 = $signed({{7{s_prod_3[8]}}, s_prod_3});
        end
    end

    // Spatial Partial Reductions
    wire signed [15:0] P_row0 = term_0 + term_1;
    wire signed [15:0] P_row1 = term_2 + term_3;
    wire signed [15:0] P_col0 = term_0 + term_2;
    wire signed [15:0] P_col1 = term_1 + term_3;
    wire signed [15:0] P_8b   = (term_0 + term_1) + (term_2 + term_3);

    //=========================================================================
    // 5. Shared 4-Slice 16-Bit Accumulator Bank
    //=========================================================================
    logic signed [15:0] ACC_00_reg, ACC_01_reg, ACC_10_reg, ACC_11_reg;
    logic signed [5:0]  block_exp_reg;
    logic               valid_out_reg;

    wire signed [15:0] acc_prev_0 = clr_acc ? 16'sd0 : ACC_00_reg;
    wire signed [15:0] acc_prev_1 = clr_acc ? 16'sd0 : ACC_01_reg;
    wire signed [15:0] acc_prev_2 = clr_acc ? 16'sd0 : ACC_10_reg;
    wire signed [15:0] acc_prev_3 = clr_acc ? 16'sd0 : ACC_11_reg;

    logic signed [15:0] nxt_reg_00, nxt_reg_01, nxt_reg_10, nxt_reg_11;
    wire signed [23:0] full_row0 = $signed({acc_prev_1[7:0], acc_prev_0}) + $signed({{8{P_row0[15]}}, P_row0});
    wire signed [23:0] full_row1 = $signed({acc_prev_3[7:0], acc_prev_2}) + $signed({{8{P_row1[15]}}, P_row1});
    wire signed [23:0] full_col0 = $signed({acc_prev_2[7:0], acc_prev_0}) + $signed({{8{P_col0[15]}}, P_col0});
    wire signed [23:0] full_col1 = $signed({acc_prev_3[7:0], acc_prev_1}) + $signed({{8{P_col1[15]}}, P_col1});
    wire signed [31:0] full_8b   = $signed({acc_prev_3,      acc_prev_0}) + $signed({{16{P_8b[15]}}, P_8b});

    always_comb begin
        case (mode_2b)
            2'b00: begin
                nxt_reg_00 = acc_prev_0 + term_0;
                nxt_reg_01 = acc_prev_1 + term_1;
                nxt_reg_10 = acc_prev_2 + term_2;
                nxt_reg_11 = acc_prev_3 + term_3;
            end
            2'b01: begin
                nxt_reg_00 = full_row0[15:0];
                nxt_reg_01 = $signed(full_row0[23:16]);
                nxt_reg_10 = full_row1[15:0];
                nxt_reg_11 = $signed(full_row1[23:16]);
            end
            2'b10: begin
                nxt_reg_00 = full_col0[15:0];
                nxt_reg_10 = $signed(full_col0[23:16]);
                nxt_reg_01 = full_col1[15:0];
                nxt_reg_11 = $signed(full_col1[23:16]);
            end
            2'b11: begin
                nxt_reg_00 = full_8b[15:0];
                nxt_reg_01 = ACC_01_reg;
                nxt_reg_10 = ACC_10_reg;
                nxt_reg_11 = full_8b[31:16];
            end
        endcase
    end

    // Exponent Output
    logic [4:0] bias_a_val, bias_b_val;
    assign bias_a_val = (format_a == 2'b00 ? 5'd7 : (format_a == 2'b01 ? 5'd15 : 5'd1));
    assign bias_b_val = (format_b == 2'b00 ? 5'd7 : (format_b == 2'b01 ? 5'd15 : 5'd1));

    logic signed [5:0] active_exp;
    always_comb begin
        if (is_pure_int) begin
            active_exp = 6'sd0;
        end else if (is_pure_fp) begin
            active_exp = $signed({1'b0, max_tile}) - $signed({1'b0, (bias_a_val + bias_b_val)});
        end else if (type_a) begin
            active_exp = $signed({1'b0, fp_exp_a0}) - $signed({1'b0, bias_a_val});
        end else begin
            active_exp = $signed({1'b0, (fp_exp_b2 > fp_exp_b0 && mode_2b == 2'b11) ? fp_exp_b2 : fp_exp_b0}) - $signed({1'b0, bias_b_val});
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ACC_00_reg    <= 16'sd0;
            ACC_01_reg    <= 16'sd0;
            ACC_10_reg    <= 16'sd0;
            ACC_11_reg    <= 16'sd0;
            block_exp_reg <= 6'sd0;
            valid_out_reg <= 1'b0;
        end else if (valid_in) begin
            valid_out_reg <= 1'b1;
            ACC_00_reg    <= nxt_reg_00;
            ACC_01_reg    <= nxt_reg_01;
            ACC_10_reg    <= nxt_reg_10;
            ACC_11_reg    <= nxt_reg_11;
            block_exp_reg <= active_exp;
        end else begin
            valid_out_reg <= 1'b0;
        end
    end

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
    assign block_exp = block_exp_reg;

endmodule
