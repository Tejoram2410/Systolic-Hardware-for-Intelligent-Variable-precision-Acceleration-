//-----------------------------------------------------------------------------
// Module: mac_reconfig_baugh_wooley
// Description: Ultra-Low-Power Reconfigurable 2x2 MAC Architecture using
//              MUX-Free Baugh-Wooley 4x4 Multipliers, Sign-Bit Pre-Encoding,
//              Fine-Grained Operand Isolation, and Spatial Hardwired Fusion.
// Precision Modes:
//   - 4-bit SIMD Mode (mode_8b = 0): 4 parallel 4-bit signed MACs (PE00..PE11)
//   - 8-bit Unified Mode (mode_8b = 1): One 8-bit signed MAC with 32-bit Fused Accumulator
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

//-----------------------------------------------------------------------------
// Standalone 4x4 Baugh-Wooley Multiplier Submodule (Zero MUXes in Datapath)
// Supports (SS: Signed*Signed, SU: Signed*Unsigned, US: Unsigned*Signed, UU: Unsigned*Unsigned)
//-----------------------------------------------------------------------------
module baugh_wooley_4b_pe (
    input  logic [3:0] a,
    input  logic [3:0] b,
    input  logic       sign_a,
    input  logic       sign_b,
    output logic [7:0] prod
);
    // 16 Partial Product Generation
    logic p00, p10, p01, p20, p11, p02;
    logic p30, p21, p12, p03, p31, p22, p13, p32, p23, p33;

    // Standard AND products
    assign p00 = a[0] & b[0];
    assign p10 = a[1] & b[0];
    assign p01 = a[0] & b[1];
    assign p20 = a[2] & b[0];
    assign p11 = a[1] & b[1];
    assign p02 = a[0] & b[2];
    assign p21 = a[2] & b[1];
    assign p12 = a[1] & b[2];
    assign p22 = a[2] & b[2];

    // Sign-dependent terms (NAND if signed, AND if unsigned)
    assign p30 = (a[3] & b[0]) ^ sign_a;
    assign p03 = (a[0] & b[3]) ^ sign_b;
    assign p31 = (a[3] & b[1]) ^ sign_a;
    assign p13 = (a[1] & b[3]) ^ sign_b;
    assign p32 = (a[3] & b[2]) ^ sign_a;
    assign p23 = (a[2] & b[3]) ^ sign_b;
    assign p33 = (a[3] & b[3]) ^ (sign_a ^ sign_b);

    // Bias constants
    // If sign_a & sign_b (SS): + 2^7 + 2^4
    // If sign_a ^ sign_b (SU or US): + 2^7 + 2^3
    // If !sign_a & !sign_b (UU): 0
    logic bias_bit3, bias_bit4, bias_bit7;
    assign bias_bit3 = sign_a ^ sign_b;
    assign bias_bit4 = sign_a & sign_b;
    assign bias_bit7 = sign_a | sign_b;

    // Reduction Tree using direct standard cells
    // Column 0:
    assign prod[0] = p00;

    // Column 1:
    logic s1, c1;
    ah01d0 u_ha_col1 (.S(s1), .CO(c1), .A(p10), .B(p01));
    assign prod[1] = s1;

    // Column 2:
    logic s2_0, c2_0, s2_1, c2_1;
    adp1d0 u_fa_col2 (.S(s2_0), .CO(c2_0), .P(), .A(p20), .B(p11), .CI(p02));
    ah01d0 u_ha_col2 (.S(s2_1), .CO(c2_1), .A(s2_0), .B(c1));
    assign prod[2] = s2_1;

    // Column 3: (p30 + p21 + p12 + p03 + bias_bit3 + carries)
    logic s3_0, c3_0, s3_1, c3_1, s3_2, c3_2;
    adp1d0 u_fa_col3_0 (.S(s3_0), .CO(c3_0), .P(), .A(p30), .B(p21), .CI(p12));
    adp1d0 u_fa_col3_1 (.S(s3_1), .CO(c3_1), .P(), .A(s3_0), .B(p03), .CI(bias_bit3));
    adp1d0 u_fa_col3_2 (.S(s3_2), .CO(c3_2), .P(), .A(s3_1), .B(c2_0), .CI(c2_1));
    assign prod[3] = s3_2;

    // Column 4: (p31 + p22 + p13 + bias_bit4 + carries)
    logic s4_0, c4_0, s4_1, c4_1, s4_2, c4_2;
    adp1d0 u_fa_col4_0 (.S(s4_0), .CO(c4_0), .P(), .A(p31), .B(p22), .CI(p13));
    adp1d0 u_fa_col4_1 (.S(s4_1), .CO(c4_1), .P(), .A(s4_0), .B(bias_bit4), .CI(c3_0));
    adp1d0 u_fa_col4_2 (.S(s4_2), .CO(c4_2), .P(), .A(s4_1), .B(c3_1), .CI(c3_2));
    assign prod[4] = s4_2;

    // Column 5: (p32 + p23 + carries)
    logic s5_0, c5_0, s5_1, c5_1;
    adp1d0 u_fa_col5_0 (.S(s5_0), .CO(c5_0), .P(), .A(p32), .B(p23), .CI(c4_0));
    adp1d0 u_fa_col5_1 (.S(s5_1), .CO(c5_1), .P(), .A(s5_0), .B(c4_1), .CI(c4_2));
    assign prod[5] = s5_1;

    // Column 6: (p33 + carries)
    logic s6_0, c6_0;
    adp1d0 u_fa_col6_0 (.S(s6_0), .CO(c6_0), .P(), .A(p33), .B(c5_0), .CI(c5_1));
    assign prod[6] = s6_0;

    // Column 7: (bias_bit7 + carries)
    assign prod[7] = bias_bit7 ^ c6_0;

endmodule

//-----------------------------------------------------------------------------
// Top-Level Reconfigurable MAC Module
//-----------------------------------------------------------------------------
module mac_reconfig_baugh_wooley (
    input  logic              clk,
    input  logic              rst_n,        // Active-low synchronous reset
    input  logic              mode_8b,      // Mode: 0 = Quad 4-bit SIMD, 1 = Unified 8-bit
    input  logic              valid_in,     // Input data valid
    input  logic              clr_acc,      // Clear accumulator control

    // Consolidated Reused 4-bit Operand Ports (Zero Internal MUXes)
    // Mode 0: PE00=(A0,B0), PE01=(A1,B1), PE10=(A2,B2), PE11=(A3,B3)
    // Mode 1: PE00=(A_lo,B_lo), PE01=(A_hi,B_lo), PE10=(A_lo,B_hi), PE11=(A_hi,B_hi)
    input  logic signed [3:0] A0, B0,
    input  logic signed [3:0] A1, B1,
    input  logic signed [3:0] A2, B2,
    input  logic signed [3:0] A3, B3,

    // Outputs
    output logic              valid_out,
    output logic signed [15:0] acc_00,      // PE00 accumulator (or lower 16b of 32b in 8-bit mode)
    output logic signed [15:0] acc_01,      // PE01 accumulator (0 in 8-bit mode)
    output logic signed [15:0] acc_10,      // PE10 accumulator (0 in 8-bit mode)
    output logic signed [15:0] acc_11,      // PE11 accumulator (or upper 16b of 32b in 8-bit mode)
    output logic signed [31:0] acc_32b      // Unified 32-bit Fused Accumulator
);

    //-------------------------------------------------------------------------
    // 1. Sign-Bit Pre-Encoding Logic
    //    In 4-bit mode: all 4 are Signed*Signed (sign_a=1, sign_b=1)
    //    In 8-bit mode: PE00=UU(0,0), PE01=SU(1,0), PE10=US(0,1), PE11=SS(1,1)
    //-------------------------------------------------------------------------
    logic sign_a_pe00, sign_b_pe00;
    logic sign_a_pe01, sign_b_pe01;
    logic sign_a_pe10, sign_b_pe10;
    logic sign_a_pe11, sign_b_pe11;

    assign sign_a_pe00 = ~mode_8b;
    assign sign_b_pe00 = ~mode_8b;

    assign sign_a_pe01 = 1'b1;
    assign sign_b_pe01 = ~mode_8b;

    assign sign_a_pe10 = ~mode_8b;
    assign sign_b_pe10 = 1'b1;

    assign sign_a_pe11 = 1'b1;
    assign sign_b_pe11 = 1'b1;

    //-------------------------------------------------------------------------
    // 2. Dynamic Input Operand Isolation (Gating to 0 during invalid cycles)
    //    Explicit bitwise AND guarantees AND2 synthesis instead of muxes
    //-------------------------------------------------------------------------
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

    //-------------------------------------------------------------------------
    // 3. Four Dedicated MUX-Free Baugh-Wooley PE Multiplier Blocks
    //-------------------------------------------------------------------------
    logic [7:0] P_00_u, P_01_u, P_10_u, P_11_u;

    baugh_wooley_4b_pe u_pe00 (.a(a0_iso), .b(b0_iso), .sign_a(sign_a_pe00), .sign_b(sign_b_pe00), .prod(P_00_u));
    baugh_wooley_4b_pe u_pe01 (.a(a1_iso), .b(b1_iso), .sign_a(sign_a_pe01), .sign_b(sign_b_pe01), .prod(P_01_u));
    baugh_wooley_4b_pe u_pe10 (.a(a2_iso), .b(b2_iso), .sign_a(sign_a_pe10), .sign_b(sign_b_pe10), .prod(P_10_u));
    baugh_wooley_4b_pe u_pe11 (.a(a3_iso), .b(b3_iso), .sign_a(sign_a_pe11), .sign_b(sign_b_pe11), .prod(P_11_u));

    logic signed [7:0] P_00, P_01, P_10, P_11;
    assign P_00 = P_00_u;
    assign P_01 = P_01_u;
    assign P_10 = P_10_u;
    assign P_11 = P_11_u;

    //-------------------------------------------------------------------------
    // 3b. Dynamic Operand Isolation for 8-bit Fusion
    //-------------------------------------------------------------------------
    logic [7:0] p00_fused_in;
    logic signed [7:0] p01_fused_in, p10_fused_in, p11_fused_in;

    assign p00_fused_in = {8{mode_8b}} & P_00_u;
    assign p01_fused_in = {8{mode_8b}} & P_01;
    assign p10_fused_in = {8{mode_8b}} & P_10;
    assign p11_fused_in = {8{mode_8b}} & P_11;

    //-------------------------------------------------------------------------
    // 4. Spatial Column-Wise Fusion Tree using SCL Standard Cells (Zero CPA Chaining)
    //    Product_8b[15:0] = P_00 (unsigned) + (P_01 + P_10)*16 + P_11*256
    //-------------------------------------------------------------------------
    logic signed [15:0] prod_8b;

    logic s01, s10;
    assign s01 = p01_fused_in[7];
    assign s10 = p10_fused_in[7];

    // Columns 0--3: Only p00_fused_in[0..3] (0 adders, direct wire)
    assign prod_8b[0] = p00_fused_in[0];
    assign prod_8b[1] = p00_fused_in[1];
    assign prod_8b[2] = p00_fused_in[2];
    assign prod_8b[3] = p00_fused_in[3];

    // Column 4: p00[4], p01[0], p10[0]
    logic c4;
    adp1d0 u_fa_fused_col4 (
        .S(prod_8b[4]), .CO(c4), .P(),
        .A(p00_fused_in[4]), .B(p01_fused_in[0]), .CI(p10_fused_in[0])
    );

    // Column 5: p00[5], p01[1], p10[1], c4
    logic s5_0, c5_0, c5_1;
    adp1d0 u_fa_fused_col5_0 (
        .S(s5_0), .CO(c5_0), .P(),
        .A(p00_fused_in[5]), .B(p01_fused_in[1]), .CI(p10_fused_in[1])
    );
    ah01d0 u_ha_fused_col5_1 (
        .S(prod_8b[5]), .CO(c5_1),
        .A(s5_0), .B(c4)
    );

    // Column 6: p00[6], p01[2], p10[2], c5_0, c5_1
    logic s6_0, c6_0, c6_1;
    adp1d0 u_fa_fused_col6_0 (
        .S(s6_0), .CO(c6_0), .P(),
        .A(p00_fused_in[6]), .B(p01_fused_in[2]), .CI(p10_fused_in[2])
    );
    adp1d0 u_fa_fused_col6_1 (
        .S(prod_8b[6]), .CO(c6_1), .P(),
        .A(s6_0), .B(c5_0), .CI(c5_1)
    );

    // Column 7: p00[7], p01[3], p10[3], c6_0, c6_1
    logic s7_0, c7_0, c7_1;
    adp1d0 u_fa_fused_col7_0 (
        .S(s7_0), .CO(c7_0), .P(),
        .A(p00_fused_in[7]), .B(p01_fused_in[3]), .CI(p10_fused_in[3])
    );
    adp1d0 u_fa_fused_col7_1 (
        .S(prod_8b[7]), .CO(c7_1), .P(),
        .A(s7_0), .B(c6_0), .CI(c6_1)
    );

    // Column 8: p01[4], p10[4], p11[0], c7_0, c7_1
    logic s8_0, c8_0, c8_1;
    adp1d0 u_fa_fused_col8_0 (
        .S(s8_0), .CO(c8_0), .P(),
        .A(p01_fused_in[4]), .B(p10_fused_in[4]), .CI(p11_fused_in[0])
    );
    adp1d0 u_fa_fused_col8_1 (
        .S(prod_8b[8]), .CO(c8_1), .P(),
        .A(s8_0), .B(c7_0), .CI(c7_1)
    );

    // Column 9: p01[5], p10[5], p11[1], c8_0, c8_1
    logic s9_0, c9_0, c9_1;
    adp1d0 u_fa_fused_col9_0 (
        .S(s9_0), .CO(c9_0), .P(),
        .A(p01_fused_in[5]), .B(p10_fused_in[5]), .CI(p11_fused_in[1])
    );
    adp1d0 u_fa_fused_col9_1 (
        .S(prod_8b[9]), .CO(c9_1), .P(),
        .A(s9_0), .B(c8_0), .CI(c8_1)
    );

    // Column 10: p01[6], p10[6], p11[2], c9_0, c9_1
    logic s10_0, c10_0, c10_1;
    adp1d0 u_fa_fused_col10_0 (
        .S(s10_0), .CO(c10_0), .P(),
        .A(p01_fused_in[6]), .B(p10_fused_in[6]), .CI(p11_fused_in[2])
    );
    adp1d0 u_fa_fused_col10_1 (
        .S(prod_8b[10]), .CO(c10_1), .P(),
        .A(s10_0), .B(c9_0), .CI(c9_1)
    );

    // Column 11: ~s01, ~s10, p11[3], c10_0, c10_1 (Stage 3b Sign-Bit Compression)
    logic s11_0, c11_0, c11_1;
    adp1d0 u_fa_fused_col11_0 (
        .S(s11_0), .CO(c11_0), .P(),
        .A(~s01), .B(~s10), .CI(p11_fused_in[3])
    );
    adp1d0 u_fa_fused_col11_1 (
        .S(prod_8b[11]), .CO(c11_1), .P(),
        .A(s11_0), .B(c10_0), .CI(c10_1)
    );

    // Column 12: 1'b1 (constant), p11[4], c11_0, c11_1
    logic s12_0, c12_0, c12_1;
    adp1d0 u_fa_fused_col12_0 (
        .S(s12_0), .CO(c12_0), .P(),
        .A(p11_fused_in[4]), .B(c11_0), .CI(c11_1)
    );
    ah01d0 u_ha_fused_col12_1 (
        .S(prod_8b[12]), .CO(c12_1),
        .A(s12_0), .B(1'b1)
    );

    // Column 13: 1'b1 (constant), p11[5], c12_0, c12_1
    logic s13_0, c13_0, c13_1;
    adp1d0 u_fa_fused_col13_0 (
        .S(s13_0), .CO(c13_0), .P(),
        .A(p11_fused_in[5]), .B(c12_0), .CI(c12_1)
    );
    ah01d0 u_ha_fused_col13_1 (
        .S(prod_8b[13]), .CO(c13_1),
        .A(s13_0), .B(1'b1)
    );

    // Column 14: 1'b1 (constant), p11[6], c13_0, c13_1
    logic s14_0, c14_0, c14_1;
    adp1d0 u_fa_fused_col14_0 (
        .S(s14_0), .CO(c14_0), .P(),
        .A(p11_fused_in[6]), .B(c13_0), .CI(c13_1)
    );
    ah01d0 u_ha_fused_col14_1 (
        .S(prod_8b[14]), .CO(c14_1),
        .A(s14_0), .B(1'b1)
    );

    // Column 15: 1'b1 (constant), p11[7], c14_0, c14_1
    logic s15_0, c15_0, c15_1;
    adp1d0 u_fa_fused_col15_0 (
        .S(s15_0), .CO(c15_0), .P(),
        .A(p11_fused_in[7]), .B(c14_0), .CI(c14_1)
    );
    ah01d0 u_ha_fused_col15_1 (
        .S(prod_8b[15]), .CO(c15_1),
        .A(s15_0), .B(1'b1)
    );

    //-------------------------------------------------------------------------
    // 5. Reconfigurable Accumulators (4 x 16-bit or Fused 32-bit)
    //-------------------------------------------------------------------------
    logic signed [15:0] ACC_00_reg;
    logic signed [15:0] ACC_01_reg;
    logic signed [15:0] ACC_10_reg;
    logic signed [15:0] ACC_11_reg;
    logic valid_out_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ACC_00_reg    <= 16'sd0;
            ACC_01_reg    <= 16'sd0;
            ACC_10_reg    <= 16'sd0;
            ACC_11_reg    <= 16'sd0;
            valid_out_reg <= 1'b0;
        end else if (valid_in) begin
            valid_out_reg <= 1'b1;
            if (!mode_8b) begin
                // Mode 0: Quad 4-bit SIMD Mode
                if (clr_acc) begin
                    ACC_00_reg <= {{8{P_00[7]}}, P_00};
                    ACC_01_reg <= {{8{P_01[7]}}, P_01};
                    ACC_10_reg <= {{8{P_10[7]}}, P_10};
                    ACC_11_reg <= {{8{P_11[7]}}, P_11};
                end else begin
                    ACC_00_reg <= ACC_00_reg + {{8{P_00[7]}}, P_00};
                    ACC_01_reg <= ACC_01_reg + {{8{P_01[7]}}, P_01};
                    ACC_10_reg <= ACC_10_reg + {{8{P_10[7]}}, P_10};
                    ACC_11_reg <= ACC_11_reg + {{8{P_11[7]}}, P_11};
                end
            end else begin
                // Mode 1: Unified 8-bit Mode (Fused 32-bit Accumulator {ACC_11, ACC_00})
                logic signed [31:0] fused_acc_curr;
                logic signed [31:0] fused_acc_next;
                logic signed [31:0] prod_8b_ext32;

                fused_acc_curr = { ACC_11_reg, ACC_00_reg };
                prod_8b_ext32  = { {16{prod_8b[15]}}, prod_8b };

                if (clr_acc) begin
                    fused_acc_next = prod_8b_ext32;
                end else begin
                    fused_acc_next = fused_acc_curr + prod_8b_ext32;
                end

                ACC_00_reg <= fused_acc_next[15:0];
                ACC_11_reg <= fused_acc_next[31:16];
                ACC_01_reg <= 16'sd0; // Zero-held for dynamic power elimination
                ACC_10_reg <= 16'sd0; // Zero-held for dynamic power elimination
            end
        end else begin
            valid_out_reg <= 1'b0;
        end
    end

    // Output Port Assignments
    assign valid_out = valid_out_reg;
    assign acc_00    = ACC_00_reg;
    assign acc_01    = ACC_01_reg;
    assign acc_10    = ACC_10_reg;
    assign acc_11    = ACC_11_reg;
    assign acc_32b   = { ACC_11_reg, ACC_00_reg };

endmodule

