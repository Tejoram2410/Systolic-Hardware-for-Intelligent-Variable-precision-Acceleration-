//-----------------------------------------------------------------------------
// Module: mac_reconfig_booth_dadda_pdk.sv
// Description: Standalone Reconfigurable 2x2 MAC Architecture using Direct
//              SCL 180nm PDK Standard Cell Primitives (adp1d0, ah01d0, mx02d1)
//              with MUX Pruning Optimization.
// Precision Modes:
//   - 4-bit SIMD Mode (mode_8b = 0): 4 parallel 4-bit MACs (PE00..PE11)
//   - 8-bit Unified Mode (mode_8b = 1): One 8-bit MAC with 32-bit Fused Accumulator
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

`ifndef SCL_PDK_SIM
// Behavioral Simulation Models for SCL 180nm PDK Standard Cells (for Vivado local sim)
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

module mx02d1 (
    output logic Z,
    input  logic I0,
    input  logic I1,
    input  logic S
);
    assign Z = S ? I1 : I0;
endmodule
`endif

module mac_reconfig_booth_dadda_pdk (
    input  logic              clk,
    input  logic              rst_n,        // Active-low synchronous reset
    input  logic              mode_8b,      // Mode: 0 = Quad 4-bit SIMD, 1 = Unified 8-bit
    input  logic              valid_in,     // Input data valid
    input  logic              clr_acc,      // Clear accumulator control

    // Strict 4-bit Input Interface per PE Lane
    input  logic signed [3:0] A_4b_00,
    input  logic signed [3:0] B_4b_00,
    input  logic signed [3:0] A_4b_01,
    input  logic signed [3:0] B_4b_01,
    input  logic signed [3:0] A_4b_10,
    input  logic signed [3:0] B_4b_10,
    input  logic signed [3:0] A_4b_11,
    input  logic signed [3:0] B_4b_11,

    // 8-bit Unified Operands (Mapped strictly onto the 4-bit PE input buses)
    input  logic signed [7:0] A_8b,
    input  logic signed [7:0] B_8b,

    // Outputs
    output logic              valid_out,
    output logic signed [15:0] acc_00,       // PE00 accumulator (or lower 16b of 32b in 8-bit mode)
    output logic signed [15:0] acc_01,       // PE01 accumulator (0 in 8-bit mode)
    output logic signed [15:0] acc_10,       // PE10 accumulator (0 in 8-bit mode)
    output logic signed [15:0] acc_11,       // PE11 accumulator (or upper 16b of 32b in 8-bit mode)
    output logic signed [31:0] acc_32b       // Unified 32-bit Fused Accumulator
);

    //-------------------------------------------------------------------------
    // 1. Strict 4-Wire PE Input Bus MUXing
    //-------------------------------------------------------------------------
    logic signed [3:0] pe_a [0:1][0:1];
    logic signed [3:0] pe_b [0:1][0:1];

    always_comb begin
        if (mode_8b) begin
            // 8-bit Mode: Split A[7:0] and B[7:0] into 4-bit nibbles across 2x2 PEs
            pe_a[0][0] = A_8b[3:0]; pe_b[0][0] = B_8b[3:0]; // PE00 (A_low * B_low)
            pe_a[0][1] = A_8b[7:4]; pe_b[0][1] = B_8b[3:0]; // PE01 (A_high * B_low)
            pe_a[1][0] = A_8b[3:0]; pe_b[1][0] = B_8b[7:4]; // PE10 (A_low * B_high)
            pe_a[1][1] = A_8b[7:4]; pe_b[1][1] = B_8b[7:4]; // PE11 (A_high * B_high)
        end else begin
            // 4-bit SIMD Mode: Direct strict 4-bit inputs per PE
            pe_a[0][0] = A_4b_00; pe_b[0][0] = B_4b_00;
            pe_a[0][1] = A_4b_01; pe_b[0][1] = B_4b_01;
            pe_a[1][0] = A_4b_10; pe_b[1][0] = B_4b_10;
            pe_a[1][1] = A_4b_11; pe_b[1][1] = B_4b_11;
        end
    end

    //-------------------------------------------------------------------------
    // 2. Strict 5-bit Local Radix-4 Booth PP Generators per PE
    //-------------------------------------------------------------------------
    function automatic logic signed [4:0] get_booth_pp_5b (
        input logic [2:0] booth_window,
        input logic signed [3:0] multiplicand_4b
    );
        logic signed [4:0] m_ext;
        m_ext = {multiplicand_4b[3], multiplicand_4b};
        case (booth_window)
            3'b000, 3'b111: get_booth_pp_5b = 5'sd0;
            3'b001, 3'b010: get_booth_pp_5b = m_ext;
            3'b011:        get_booth_pp_5b = m_ext <<< 1;
            3'b100:        get_booth_pp_5b = -(m_ext <<< 1);
            3'b101, 3'b110: get_booth_pp_5b = -m_ext;
            default:       get_booth_pp_5b = 5'sd0;
        endcase
    endfunction

    // Booth Windows and Local 5-bit Partial Product Terms
    logic [2:0] booth_grp [0:1][0:1][0:1]; // [r][c][grp_idx]
    logic signed [4:0] pp_term_5b [0:1][0:1][0:1]; // Local 5-bit partial product terms

    always_comb begin
        for (int r = 0; r < 2; r++) begin
            for (int c = 0; c < 2; c++) begin
                booth_grp[r][c][0] = {pe_b[r][c][1], pe_b[r][c][0], 1'b0};
                
                if (mode_8b && c == 1) begin
                    booth_grp[r][c][1] = {pe_b[r][c][3], pe_b[r][c][2], pe_b[r][0][3]};
                end else begin
                    booth_grp[r][c][1] = {pe_b[r][c][3], pe_b[r][c][2], pe_b[r][c][1]};
                end

                pp_term_5b[r][c][0] = get_booth_pp_5b(booth_grp[r][c][0], pe_a[r][c]);
                pp_term_5b[r][c][1] = get_booth_pp_5b(booth_grp[r][c][1], pe_a[r][c]);
            end
        end
    end

    // Form Fused 8-bit Partial Products for 8-bit Mode
    logic signed [15:0] pp_8b_0, pp_8b_1, pp_8b_2, pp_8b_3;
    always_comb begin
        pp_8b_0 = {{8{pp_term_5b[0][1][0][4]}}, pp_term_5b[0][1][0][3:0], pp_term_5b[0][0][0][3:0]};
        pp_8b_1 = {{6{pp_term_5b[0][1][1][4]}}, pp_term_5b[0][1][1][3:0], pp_term_5b[0][0][1][3:0], 2'b0};
        pp_8b_2 = {{4{pp_term_5b[1][1][0][4]}}, pp_term_5b[1][1][0][3:0], pp_term_5b[1][0][0][3:0], 4'b0};
        pp_8b_3 = {{2{pp_term_5b[1][1][1][4]}}, pp_term_5b[1][1][1][3:0], pp_term_5b[1][0][1][3:0], 6'b0};
    end

    // Direct Instantiation of 4 SCL PDK Half Adders (ah01d0) with Pruned Inputs
    logic [3:0] ha_a, ha_b, ha_s, ha_co;

    // HA 0 (PE00):
    mx02d1 u_mux_ha0_a (.Z(ha_a[0]), .I0(pp_term_5b[0][0][0][2]), .I1(pp_8b_0[4]), .S(mode_8b));
    mx02d1 u_mux_ha0_b (.Z(ha_b[0]), .I0(pp_term_5b[0][0][1][0]), .I1(pp_8b_1[4]), .S(mode_8b));
    ah01d0 u_ha0 (.S(ha_s[0]), .CO(ha_co[0]), .A(ha_a[0]), .B(ha_b[0]));

    // HA 1 (PE01):
    mx02d1 u_mux_ha1_a (.Z(ha_a[1]), .I0(pp_term_5b[0][1][0][2]), .I1(pp_8b_0[5]), .S(mode_8b));
    mx02d1 u_mux_ha1_b (.Z(ha_b[1]), .I0(pp_term_5b[0][1][1][0]), .I1(pp_8b_1[5]), .S(mode_8b));
    ah01d0 u_ha1 (.S(ha_s[1]), .CO(ha_co[1]), .A(ha_a[1]), .B(ha_b[1]));

    // HA 2 (PE10):
    mx02d1 u_mux_ha2_a (.Z(ha_a[2]), .I0(pp_term_5b[1][0][0][2]), .I1(pp_8b_0[8]), .S(mode_8b));
    mx02d1 u_mux_ha2_b (.Z(ha_b[2]), .I0(pp_term_5b[1][0][1][0]), .I1(pp_8b_1[8]), .S(mode_8b));
    ah01d0 u_ha2 (.S(ha_s[2]), .CO(ha_co[2]), .A(ha_a[2]), .B(ha_b[2]));

    // HA 3 (PE11):
    mx02d1 u_mux_ha3_a (.Z(ha_a[3]), .I0(pp_term_5b[1][1][0][2]), .I1(pp_8b_0[9]), .S(mode_8b));
    mx02d1 u_mux_ha3_b (.Z(ha_b[3]), .I0(pp_term_5b[1][1][1][0]), .I1(pp_8b_1[9]), .S(mode_8b));
    ah01d0 u_ha3 (.S(ha_s[3]), .CO(ha_co[3]), .A(ha_a[3]), .B(ha_b[3]));

    // Direct Instantiation of 20 SCL PDK Full Adders (adp1d0) with Pruned Inputs
    logic [19:0] fa_a, fa_b, fa_ci, fa_s, fa_co;

    genvar f;
    generate
        for (f = 0; f < 20; f = f + 1) begin : gen_pdk_fa
            int pe_idx, bit_idx, r_idx, c_idx;
            assign pe_idx  = f / 5;
            assign bit_idx = f % 5;
            assign r_idx   = pe_idx / 2;
            assign c_idx   = pe_idx % 2;

            logic fa_a_4b, fa_b_4b, fa_ci_4b;
            always_comb begin
                case (bit_idx)
                    0: begin
                        fa_a_4b  = pp_term_5b[r_idx][c_idx][0][3];
                        fa_b_4b  = pp_term_5b[r_idx][c_idx][1][1];
                        fa_ci_4b = ha_co[pe_idx];
                    end
                    1: begin
                        fa_a_4b  = pp_term_5b[r_idx][c_idx][0][4];
                        fa_b_4b  = pp_term_5b[r_idx][c_idx][1][2];
                        fa_ci_4b = fa_co[pe_idx * 5 + 0];
                    end
                    2: begin
                        fa_a_4b  = pp_term_5b[r_idx][c_idx][0][4];
                        fa_b_4b  = pp_term_5b[r_idx][c_idx][1][3];
                        fa_ci_4b = fa_co[pe_idx * 5 + 1];
                    end
                    3: begin
                        fa_a_4b  = pp_term_5b[r_idx][c_idx][0][4];
                        fa_b_4b  = pp_term_5b[r_idx][c_idx][1][4];
                        fa_ci_4b = fa_co[pe_idx * 5 + 2];
                    end
                    4: begin
                        fa_a_4b  = pp_term_5b[r_idx][c_idx][0][4];
                        fa_b_4b  = pp_term_5b[r_idx][c_idx][1][4];
                        fa_ci_4b = fa_co[pe_idx * 5 + 3];
                    end
                    default: begin
                        fa_a_4b  = 1'b0; fa_b_4b = 1'b0; fa_ci_4b = 1'b0;
                    end
                endcase
            end

            mx02d1 u_mux_fa_a  (.Z(fa_a[f]),  .I0(fa_a_4b),  .I1(pp_8b_0[f % 16]), .S(mode_8b));
            mx02d1 u_mux_fa_b  (.Z(fa_b[f]),  .I0(fa_b_4b),  .I1(pp_8b_1[f % 16]), .S(mode_8b));
            mx02d1 u_mux_fa_ci (.Z(fa_ci[f]), .I0(fa_ci_4b), .I1(pp_8b_2[f % 16]), .S(mode_8b));

            adp1d0 u_fa (.S(fa_s[f]), .CO(fa_co[f]), .P(), .A(fa_a[f]), .B(fa_b[f]), .CI(fa_ci[f]));
        end
    endgenerate

    // 4-bit Products per PE
    logic signed [7:0] pe_prod_4b [0:1][0:1];
    always_comb begin
        for (int r = 0; r < 2; r++) begin
            for (int c = 0; c < 2; c++) begin
                int idx;
                idx = (r * 2 + c);
                pe_prod_4b[r][c] = {
                    fa_co[idx * 5 + 4],
                    fa_s[idx * 5 + 4],
                    fa_s[idx * 5 + 3],
                    fa_s[idx * 5 + 2],
                    fa_s[idx * 5 + 1],
                    fa_s[idx * 5 + 0],
                    ha_s[idx],
                    pp_term_5b[r][c][0][1:0]
                };
            end
        end
    end

    // 8-bit Fused CPA Final Stage
    logic signed [15:0] prod_8b_cpa;
    assign prod_8b_cpa = {fa_s[15:0]} + {fa_co[14:0], 1'b0} + pp_8b_3;

    // Sequential Accumulators (4 x 16-bit or 1 x 32-bit)
    logic signed [15:0] ACC_00_reg, ACC_01_reg, ACC_10_reg, ACC_11_reg;
    logic signed [31:0] fused_acc_curr, fused_acc_next;
    logic               valid_out_reg;

    assign fused_acc_curr = { ACC_11_reg, ACC_00_reg };

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
                ACC_00_reg <= clr_acc ? {{8{pe_prod_4b[0][0][7]}}, pe_prod_4b[0][0]} : (ACC_00_reg + {{8{pe_prod_4b[0][0][7]}}, pe_prod_4b[0][0]});
                ACC_01_reg <= clr_acc ? {{8{pe_prod_4b[0][1][7]}}, pe_prod_4b[0][1]} : (ACC_01_reg + {{8{pe_prod_4b[0][1][7]}}, pe_prod_4b[0][1]});
                ACC_10_reg <= clr_acc ? {{8{pe_prod_4b[1][0][7]}}, pe_prod_4b[1][0]} : (ACC_10_reg + {{8{pe_prod_4b[1][0][7]}}, pe_prod_4b[1][0]});
                ACC_11_reg <= clr_acc ? {{8{pe_prod_4b[1][1][7]}}, pe_prod_4b[1][1]} : (ACC_11_reg + {{8{pe_prod_4b[1][1][7]}}, pe_prod_4b[1][1]});
            end else begin
                if (clr_acc) begin
                    fused_acc_next = {{16{prod_8b_cpa[15]}}, prod_8b_cpa};
                end else begin
                    fused_acc_next = fused_acc_curr + {{16{prod_8b_cpa[15]}}, prod_8b_cpa};
                end
                ACC_00_reg <= fused_acc_next[15:0];
                ACC_11_reg <= fused_acc_next[31:16];
                ACC_01_reg <= 16'sd0;
                ACC_10_reg <= 16'sd0;
            end
        end else begin
            valid_out_reg <= 1'b0;
        end
    end

    assign valid_out = valid_out_reg;
    assign acc_00    = ACC_00_reg;
    assign acc_01    = ACC_01_reg;
    assign acc_10    = ACC_10_reg;
    assign acc_11    = ACC_11_reg;
    assign acc_32b   = { ACC_11_reg, ACC_00_reg };

endmodule
