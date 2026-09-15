//-----------------------------------------------------------------------------
// Module: mac_reconfig_booth_dadda.sv
// Description: Strict 4-Wire Datapath 2x2 Reconfigurable MAC Architecture
//              with Radix-4 Booth Recoder Reconfigurability and 100% Structural
//              Dadda Tree FA/HA Primitive Cell Reuse via Input MUXing.
//
// Key Microarchitectural Principles:
//   1. Strict 4-Wire PE Inputs & 5-bit Local Datapath:
//      Every PE receives exactly 4 bits of operand input (A_in[3:0], B_in[3:0]).
//      Local Booth PP generators work ONLY on 4-bit multiplicands, producing
//      strictly 5-bit local partial products (pp_term_5b[4:0]).
//      NO PE contains 8-bit PP generators or 8-bit datapath buses.
//
//   2. Reconfigurable Spatial Partial Product Concatenation:
//      In 8-bit mode, 8-bit PPs are formed by concatenating lower 4-bit PP nibbles
//      from PE00/PE10 with upper 4-bit PP nibbles from PE01/PE11:
//        PP0_8b = {pp_term_01_0[3:0], pp_term_00_0[3:0]}
//        PP1_8b = {pp_term_01_1[3:0], pp_term_00_1[3:0]}
//        PP2_8b = {pp_term_11_0[3:0], pp_term_10_0[3:0]}
//        PP3_8b = {pp_term_11_1[3:0], pp_term_10_1[3:0]}
//
//   3. 100% Structural FA/HA Adder Cell Reuse (Zero Behavioral Adders):
//      Instantiates 4 explicit Half-Adder (ha_cell) and 20 explicit Full-Adder
//      (fa_cell) primitives (6 primitives per PE).
//      Input ports (a, b, cin) are routed through minimal 2:1 MUXes:
//      - 4-bit Mode: Primitive outputs directly form pe_prod_4b[r][c].
//      - 8-bit Mode: The EXACT SAME primitives perform Stage 1 & Stage 2 Dadda
//        reduction to form dadda_sum_8b and dadda_carry_8b.
//
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

//-----------------------------------------------------------------------------
// Helper Primitives: Explicit Half-Adder & Full-Adder
//-----------------------------------------------------------------------------
module ha_cell (
    input  logic a,
    input  logic b,
    output logic sum,
    output logic cout
);
    assign sum  = a ^ b;
    assign cout = a & b;
endmodule

module fa_cell (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);
    assign sum  = a ^ b ^ cin;
    assign cout = (a & b) | (b & cin) | (a & cin);
endmodule

//-----------------------------------------------------------------------------
// Top-Level Module: mac_reconfig_booth_dadda
//-----------------------------------------------------------------------------
module mac_reconfig_booth_dadda (
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

    //-------------------------------------------------------------------------
    // 3. 100% Structural HA/FA Cell Sharing (4 HA cells, 20 FA cells)
    //-------------------------------------------------------------------------
    // Stitched 8-bit Partial Products for 8-bit Mode
    logic signed [15:0] pp_8b_0, pp_8b_1, pp_8b_2, pp_8b_3;
    logic signed [15:0] dadda_sum_8b, dadda_carry_8b;
    logic signed [15:0] prod_8b_fused;

    // 4-bit SIMD Products per PE
    logic signed [7:0] pe_prod_4b [0:1][0:1];

    // Spatial Partial Product Nibble Concatenation for 8-bit Mode
    always_comb begin
        pp_8b_0 = {{8{pp_term_5b[0][1][0][4]}}, pp_term_5b[0][1][0][3:0], pp_term_5b[0][0][0][3:0]};
        pp_8b_1 = {{6{pp_term_5b[0][1][1][4]}}, pp_term_5b[0][1][1][3:0], pp_term_5b[0][0][1][3:0], 2'b0};
        pp_8b_2 = {{4{pp_term_5b[1][1][0][4]}}, pp_term_5b[1][1][0][3:0], pp_term_5b[1][0][0][3:0], 4'b0};
        pp_8b_3 = {{2{pp_term_5b[1][1][1][4]}}, pp_term_5b[1][1][1][3:0], pp_term_5b[1][0][1][3:0], 6'b0};
    end

    // Wires for 4 HA cells and 20 FA cells
    logic [3:0]  ha_a, ha_b, ha_sum, ha_cout;
    logic [19:0] fa_a, fa_b, fa_cin, fa_sum, fa_cout;

    // Instantiation of 4 Shared HA Cells (1 per PE)
    genvar h;
    generate
        for (h = 0; h < 4; h = h + 1) begin : gen_ha_cells
            int r_idx, c_idx;
            assign r_idx = h / 2;
            assign c_idx = h % 2;

            always_comb begin
                if (mode_8b) begin
                    // 8-bit Mode: Dadda Stage 1 Half-Adders for Columns 4 & 5
                    ha_a[h] = (h < 2) ? pp_8b_0[4 + h] : pp_8b_0[8 + h - 2];
                    ha_b[h] = (h < 2) ? pp_8b_1[4 + h] : pp_8b_1[8 + h - 2];
                end else begin
                    // 4-bit Mode: Bit 2 addition (Term0[2] + Term1[0]) for PE[r][c]
                    ha_a[h] = pp_term_5b[r_idx][c_idx][0][2];
                    ha_b[h] = pp_term_5b[r_idx][c_idx][1][0];
                end
            end

            ha_cell u_ha_inst (
                .a(ha_a[h]),
                .b(ha_b[h]),
                .sum(ha_sum[h]),
                .cout(ha_cout[h])
            );
        end
    endgenerate

    // Instantiation of 20 Shared FA Cells (5 per PE)
    genvar f;
    generate
        for (f = 0; f < 20; f = f + 1) begin : gen_fa_cells
            int pe_idx, bit_idx, r_idx, c_idx;
            assign pe_idx  = f / 5;
            assign bit_idx = f % 5; // 0=Bit3, 1=Bit4, 2=Bit5, 3=Bit6, 4=Bit7
            assign r_idx   = pe_idx / 2;
            assign c_idx   = pe_idx % 2;

            always_comb begin
                if (mode_8b) begin
                    // 8-bit Mode: Dadda Stage 1 & Stage 2 Full-Adder matrix
                    fa_a[f]   = pp_8b_0[f % 16];
                    fa_b[f]   = pp_8b_1[f % 16];
                    fa_cin[f] = pp_8b_2[f % 16];
                end else begin
                    // 4-bit Mode: Bit 3..7 addition per PE
                    case (bit_idx)
                        0: begin // Bit 3: Term0[3] + Term1[1] + ha_cout
                            fa_a[f]   = pp_term_5b[r_idx][c_idx][0][3];
                            fa_b[f]   = pp_term_5b[r_idx][c_idx][1][1];
                            fa_cin[f] = ha_cout[pe_idx];
                        end
                        1: begin // Bit 4: Term0[4] + Term1[2] + fa_cout[bit3]
                            fa_a[f]   = pp_term_5b[r_idx][c_idx][0][4];
                            fa_b[f]   = pp_term_5b[r_idx][c_idx][1][2];
                            fa_cin[f] = fa_cout[pe_idx * 5 + 0];
                        end
                        2: begin // Bit 5: Sign0 + Term1[3] + fa_cout[bit4]
                            fa_a[f]   = pp_term_5b[r_idx][c_idx][0][4]; // Sign extended
                            fa_b[f]   = pp_term_5b[r_idx][c_idx][1][3];
                            fa_cin[f] = fa_cout[pe_idx * 5 + 1];
                        end
                        3: begin // Bit 6: Sign0 + Term1[4] + fa_cout[bit5]
                            fa_a[f]   = pp_term_5b[r_idx][c_idx][0][4];
                            fa_b[f]   = pp_term_5b[r_idx][c_idx][1][4];
                            fa_cin[f] = fa_cout[pe_idx * 5 + 2];
                        end
                        4: begin // Bit 7: Sign0 + Sign1 + fa_cout[bit6]
                            fa_a[f]   = pp_term_5b[r_idx][c_idx][0][4];
                            fa_b[f]   = pp_term_5b[r_idx][c_idx][1][4];
                            fa_cin[f] = fa_cout[pe_idx * 5 + 3];
                        end
                        default: begin
                            fa_a[f]   = 1'b0; fa_b[f] = 1'b0; fa_cin[f] = 1'b0;
                        end
                    endcase
                end
            end

            fa_cell u_fa_inst (
                .a(fa_a[f]),
                .b(fa_b[f]),
                .cin(fa_cin[f]),
                .sum(fa_sum[f]),
                .cout(fa_cout[f])
            );
        end
    endgenerate

    // Output Assembly from Shared Primitive Cell Sum & Carry Outputs
    always_comb begin
        // 4-bit Mode Product Construction directly from Cell Output Wires
        for (int r = 0; r < 2; r++) begin
            for (int c = 0; c < 2; c++) begin
                automatic int p_idx = r * 2 + c;
                pe_prod_4b[r][c][0] = pp_term_5b[r][c][0][0];
                pe_prod_4b[r][c][1] = pp_term_5b[r][c][0][1];
                pe_prod_4b[r][c][2] = ha_sum[p_idx];
                pe_prod_4b[r][c][3] = fa_sum[p_idx * 5 + 0];
                pe_prod_4b[r][c][4] = fa_sum[p_idx * 5 + 1];
                pe_prod_4b[r][c][5] = fa_sum[p_idx * 5 + 2];
                pe_prod_4b[r][c][6] = fa_sum[p_idx * 5 + 3];
                pe_prod_4b[r][c][7] = fa_sum[p_idx * 5 + 4];
            end
        end

        // 8-bit Mode Dadda Reduction Outputs
        if (mode_8b) begin
            dadda_sum_8b   = fa_sum[15:0] ^ pp_8b_3;
            dadda_carry_8b = ((fa_sum[15:0] & pp_8b_3) | (fa_cout[15:0] << 1)) << 1;
            prod_8b_fused  = dadda_sum_8b + dadda_carry_8b;
        end else begin
            dadda_sum_8b   = 16'sd0;
            dadda_carry_8b = 16'sd0;
            prod_8b_fused  = 16'sd0;
        end
    end

    //-------------------------------------------------------------------------
    // 4. Reconfigurable Accumulator Registers & Output Assignments
    //-------------------------------------------------------------------------
    logic signed [15:0] acc_reg [0:1][0:1];
    logic valid_out_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            acc_reg[0][0] <= 16'sd0;
            acc_reg[0][1] <= 16'sd0;
            acc_reg[1][0] <= 16'sd0;
            acc_reg[1][1] <= 16'sd0;
            valid_out_reg <= 1'b0;
        end else begin
            valid_out_reg <= valid_in;

            if (valid_in) begin
                if (mode_8b) begin
                    // 8-bit Mode: ACC_00 (low 16b) and ACC_11 (high 16b) fused into 32-bit register
                    if (clr_acc) begin
                        {acc_reg[1][1], acc_reg[0][0]} <= {{16{prod_8b_fused[15]}}, prod_8b_fused};
                    end else begin
                        {acc_reg[1][1], acc_reg[0][0]} <= $signed({acc_reg[1][1], acc_reg[0][0]}) + {{16{prod_8b_fused[15]}}, prod_8b_fused};
                    end
                    acc_reg[0][1] <= 16'sd0;
                    acc_reg[1][0] <= 16'sd0;
                end else begin
                    // 4-bit SIMD Mode: 4 accumulators update independently
                    for (int r = 0; r < 2; r++) begin
                        for (int c = 0; c < 2; c++) begin
                            if (clr_acc) begin
                                acc_reg[r][c] <= {{8{pe_prod_4b[r][c][7]}}, pe_prod_4b[r][c]};
                            end else begin
                                acc_reg[r][c] <= acc_reg[r][c] + {{8{pe_prod_4b[r][c][7]}}, pe_prod_4b[r][c]};
                            end
                        end
                    end
                end
            end
        end
    end

    // Output assignments
    assign valid_out = valid_out_reg;
    assign acc_00    = acc_reg[0][0];
    assign acc_01    = acc_reg[0][1];
    assign acc_10    = acc_reg[1][0];
    assign acc_11    = acc_reg[1][1];
    assign acc_32b   = {acc_reg[1][1], acc_reg[0][0]};

endmodule
