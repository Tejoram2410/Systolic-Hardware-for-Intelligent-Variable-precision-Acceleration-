//-----------------------------------------------------------------------------
// Module: pe_node.sv
// Description: Processing Element (PE) for Systolic Array architecture.
//              Wraps the 4-bit Radix-4 Dadda MAC unit and provides pipeline
//              registers for horizontal (A) and vertical (B) data propagation,
//              as well as control signal propagation.
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module pe_node (
    input  logic              clk,
    input  logic              rst_n,      // Active-low synchronous reset
    input  logic              in_valid,   // Input data valid
    input  logic              in_clr,     // Clear accumulator signal
    input  logic signed [3:0] in_a,       // 4-bit signed multiplicand (horizontal)
    input  logic signed [3:0] in_b,       // 4-bit signed multiplier (vertical)

    output logic              out_valid,  // Registered valid output (passed right)
    output logic              out_clr,    // Registered clr output (passed right)
    output logic signed [3:0] out_a,      // Registered multiplicand output (passed right)
    output logic signed [3:0] out_b,      // Registered multiplier output (passed down)

    output logic              valid_out,  // MAC output valid
    output logic signed [15:0] acc_out    // 16-bit MAC accumulator output
);

    // MAC Unit Instance
    mac_radix4_dadda mac_inst (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (in_valid),
        .clr_acc  (in_clr),
        .A        (in_a),
        .B        (in_b),
        .valid_out(valid_out),
        .ACC      (acc_out)
    );

    // Pipeline Data & Control Registers for Systolic Movement
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            out_a     <= 4'sd0;
            out_b     <= 4'sd0;
            out_valid <= 1'b0;
            out_clr   <= 1'b0;
        end else begin
            out_a     <= in_a;
            out_b     <= in_b;
            out_valid <= in_valid;
            out_clr   <= in_clr;
        end
    end

endmodule
