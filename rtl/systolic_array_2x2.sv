//-----------------------------------------------------------------------------
// Module: systolic_array_2x2.sv
// Description: 2x2 Systolic Array utilizing INT4 Radix-4 Dadda MAC units.
// Architecture:
//               b_in_col0               b_in_col1
//                   |                       |
//                   v                       v
//  a_in_row0 ---> PE[0][0] ----(out_a)----> PE[0][1] ---> out_a_row0
//                   |                       |
//                 (out_b)                 (out_b)
//                   |                       |
//                   v                       v
//  a_in_row1 ---> PE[1][0] ----(out_a)----> PE[1][1] ---> out_a_row1
//                   |                       |
//                 (out_b)                 (out_b)
//                   |                       |
//                   v                       v
//              out_b_col0              out_b_col1
//
// Data movement:
//   - Horizontal (A): Inputs stream left-to-right through PE rows.
//   - Vertical   (B): Inputs stream top-to-bottom through PE columns.
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module systolic_array_2x2 (
    input  logic              clk,
    input  logic              rst_n,          // Active-low synchronous reset

    // Row A Inputs (driven at left boundary)
    input  logic              valid_in_row0,
    input  logic              clr_acc_row0,
    input  logic signed [3:0] a_in_row0,

    input  logic              valid_in_row1,
    input  logic              clr_acc_row1,
    input  logic signed [3:0] a_in_row1,

    // Column B Inputs (driven at top boundary)
    input  logic signed [3:0] b_in_col0,
    input  logic signed [3:0] b_in_col1,

    // Matrix Accumulator Outputs (16-bit signed each)
    output logic signed [15:0] acc_00,
    output logic signed [15:0] acc_01,
    output logic signed [15:0] acc_10,
    output logic signed [15:0] acc_11,

    // Output Valid Indicators
    output logic              valid_out_00,
    output logic              valid_out_01,
    output logic              valid_out_10,
    output logic              valid_out_11,

    // Boundary Data Movement Outputs (for verification of systolic shift)
    output logic signed [3:0] out_a_row0,     // A data exiting PE(0,1)
    output logic signed [3:0] out_a_row1,     // A data exiting PE(1,1)
    output logic signed [3:0] out_b_col0,     // B data exiting PE(1,0)
    output logic signed [3:0] out_b_col1      // B data exiting PE(1,1)
);

    // Inter-PE Interconnect Wires
    // Row 0 Wires
    logic              pe00_out_valid;
    logic              pe00_out_clr;
    logic signed [3:0] pe00_out_a;
    logic signed [3:0] pe00_out_b;

    logic              pe01_out_valid;
    logic              pe01_out_clr;
    logic signed [3:0] pe01_out_a;
    logic signed [3:0] pe01_out_b;

    // Row 1 Wires
    logic              pe10_out_valid;
    logic              pe10_out_clr;
    logic signed [3:0] pe10_out_a;
    logic signed [3:0] pe10_out_b;

    logic              pe11_out_valid;
    logic              pe11_out_clr;
    logic signed [3:0] pe11_out_a;
    logic signed [3:0] pe11_out_b;

    //-------------------------------------------------------------------------
    // PE(0,0) - Top-Left Node
    //-------------------------------------------------------------------------
    pe_node pe_00 (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (valid_in_row0),
        .in_clr    (clr_acc_row0),
        .in_a      (a_in_row0),
        .in_b      (b_in_col0),
        .out_valid (pe00_out_valid),
        .out_clr   (pe00_out_clr),
        .out_a     (pe00_out_a),
        .out_b     (pe00_out_b),
        .valid_out (valid_out_00),
        .acc_out   (acc_00)
    );

    //-------------------------------------------------------------------------
    // PE(0,1) - Top-Right Node
    //-------------------------------------------------------------------------
    pe_node pe_01 (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (pe00_out_valid),
        .in_clr    (pe00_out_clr),
        .in_a      (pe00_out_a),
        .in_b      (b_in_col1),
        .out_valid (pe01_out_valid),
        .out_clr   (pe01_out_clr),
        .out_a     (pe01_out_a),
        .out_b     (pe01_out_b),
        .valid_out (valid_out_01),
        .acc_out   (acc_01)
    );

    //-------------------------------------------------------------------------
    // PE(1,0) - Bottom-Left Node
    //-------------------------------------------------------------------------
    pe_node pe_10 (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (valid_in_row1),
        .in_clr    (clr_acc_row1),
        .in_a      (a_in_row1),
        .in_b      (pe00_out_b),
        .out_valid (pe10_out_valid),
        .out_clr   (pe10_out_clr),
        .out_a     (pe10_out_a),
        .out_b     (pe10_out_b),
        .valid_out (valid_out_10),
        .acc_out   (acc_10)
    );

    //-------------------------------------------------------------------------
    // PE(1,1) - Bottom-Right Node
    //-------------------------------------------------------------------------
    pe_node pe_11 (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (pe10_out_valid),
        .in_clr    (pe10_out_clr),
        .in_a      (pe10_out_a),
        .in_b      (pe01_out_b),
        .out_valid (pe11_out_valid),
        .out_clr   (pe11_out_clr),
        .out_a     (pe11_out_a),
        .out_b     (pe11_out_b),
        .valid_out (valid_out_11),
        .acc_out   (acc_11)
    );

    // Assign Boundary Outputs
    assign out_a_row0 = pe01_out_a;
    assign out_a_row1 = pe11_out_a;
    assign out_b_col0 = pe10_out_b;
    assign out_b_col1 = pe11_out_b;

endmodule
