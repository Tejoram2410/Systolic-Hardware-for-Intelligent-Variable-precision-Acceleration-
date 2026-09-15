//-----------------------------------------------------------------------------
// Module: mac_radix4_dadda.sv
// Description: 4-bit Signed Multiply-Accumulate (MAC) Unit utilizing:
//              1. Radix-4 Modified Booth Encoding (MBE) for Partial Product Generation
//              2. Dadda Tree Logic for Partial Product Compression
//              3. Pipeline Register & 16-bit Accumulator
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_radix4_dadda (
    input  logic              clk,
    input  logic              rst_n,      // Active-low synchronous reset
    input  logic              valid_in,   // Input data valid
    input  logic              clr_acc,    // Clear accumulator (start new sequence)
    input  logic signed [3:0] A,          // 4-bit Signed Multiplicand
    input  logic signed [3:0] B,          // 4-bit Signed Multiplier
    output logic              valid_out,  // Output data valid
    output logic signed [15:0] ACC        // 16-bit Accumulator Output
);

    //-------------------------------------------------------------------------
    // Step 1: Radix-4 Booth Encoding Signals
    //-------------------------------------------------------------------------
    // 4-bit B recoded into 2 Radix-4 groups with B[-1] = 0
    logic [2:0] booth_grp0;
    logic [2:0] booth_grp1;

    assign booth_grp0 = {B[1], B[0], 1'b0};
    assign booth_grp1 = {B[3], B[2], B[1]};

    // Helper functions for Booth Recoding
    function automatic logic [8:0] get_pp(
        input logic [2:0] grp,
        input logic signed [3:0] operand_a
    );
        logic signed [8:0] a_ext;
        logic signed [8:0] pp_val;

        a_ext = { {5{operand_a[3]}}, operand_a }; // Sign-extended to 9 bits

        case (grp)
            3'b000, 3'b111: pp_val = 9'sd0;           //  0
            3'b001, 3'b010: pp_val = a_ext;           // +1 * A
            3'b011:         pp_val = a_ext << 1;      // +2 * A
            3'b100:         pp_val = ~(a_ext << 1);   // -2 * A (Bitwise NOT, +1 added in reduction)
            3'b101, 3'b110: pp_val = ~a_ext;          // -1 * A (Bitwise NOT, +1 added in reduction)
            default:        pp_val = 9'sd0;
        endcase
        return pp_val;
    endfunction

    function automatic logic get_neg(input logic [2:0] grp);
        return (grp == 3'b100 || grp == 3'b101 || grp == 3'b110);
    endfunction

    // Raw Partial Products
    logic signed [8:0] pp0_raw;
    logic signed [8:0] pp1_raw;
    logic              neg0;
    logic              neg1;

    assign pp0_raw = get_pp(booth_grp0, A);
    assign pp1_raw = get_pp(booth_grp1, A);
    assign neg0    = get_neg(booth_grp0);
    assign neg1    = get_neg(booth_grp1);

    // Aligned Partial Products (8-bit product requires 8 bits)
    // PP0 shifted by 0, PP1 shifted by 2
    logic [7:0] pp0_aligned;
    logic [7:0] pp1_aligned;

    assign pp0_aligned = pp0_raw[7:0];
    assign pp1_aligned = {pp1_raw[5:0], 2'b00};

    //-------------------------------------------------------------------------
    // Step 2: Dadda Tree Logic Reduction
    //-------------------------------------------------------------------------
    // Full Adder Helper
    function automatic void fa(
        input  logic a, b, cin,
        output logic sum, cout
    );
        sum  = a ^ b ^ cin;
        cout = (a & b) | (b & cin) | (a & cin);
    endfunction

    // Half Adder Helper
    function automatic void ha(
        input  logic a, b,
        output logic sum, cout
    );
        sum  = a ^ b;
        cout = a & b;
    endfunction

    // Dadda Tree Reduction for 2 partial product rows + 2 negation constants
    // Bit 0: pp0[0] + neg0
    // Bit 2: pp0[2] + pp1[2] + neg1
    logic [7:0] dadda_sum;
    logic [7:0] dadda_carry;

    always_comb begin
        dadda_sum   = '0;
        dadda_carry = '0;

        // Bit 0
        ha(pp0_aligned[0], neg0, dadda_sum[0], dadda_carry[1]);

        // Bit 1
        dadda_sum[1] = pp0_aligned[1];

        // Bit 2
        fa(pp0_aligned[2], pp1_aligned[2], neg1, dadda_sum[2], dadda_carry[3]);

        // Bits 3..7
        for (int i = 3; i < 8; i++) begin
            ha(pp0_aligned[i], pp1_aligned[i], dadda_sum[i], dadda_carry[i+1 < 8 ? i+1 : 7]);
        end
    end

    // Final Vector Addition to obtain 8-bit product
    logic signed [7:0] product_mult;
    assign product_mult = dadda_sum + dadda_carry;

    //-------------------------------------------------------------------------
    // Step 3: Pipeline & Accumulation Stage
    //-------------------------------------------------------------------------
    logic signed [15:0] prod_ext;
    assign prod_ext = { {8{product_mult[7]}}, product_mult }; // Sign-extend product to 16 bits

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            ACC       <= '0;
            valid_out <= 1'b0;
        end else if (valid_in) begin
            if (clr_acc) begin
                ACC   <= prod_ext;
            end else begin
                ACC   <= ACC + prod_ext;
            end
            valid_out <= 1'b1;
        end else begin
            valid_out <= 1'b0;
        end
    end

endmodule
