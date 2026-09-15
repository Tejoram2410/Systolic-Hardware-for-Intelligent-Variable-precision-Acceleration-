//-----------------------------------------------------------------------------
// Module: systolic_array_reconfig_nxn.sv
// Description: OPTIMIZED Ultra-Low-Power Scalable N x N 2D Reconfigurable Systolic Array
//              (Configured with N = 16: 256 Physical 4b PEs, 64 Optimized Macro-Tiles).
//              Features:
//                1. Collapsed Invariant Steering Logic (Direct Wires & 2:1 MUXes).
//                2. Synchronous Mode-Gating on Inactive Mid-Pipeline Skew Registers (512 FFs).
//                3. Streamlined Direct Forwarding Pipeline Bypass.
//                4. Seamless Integration with Golden 3.907 mW 2D MAC Tile.
// Technology: SCL 180nm CMOS PDK (tsl18fs120_scl_ss.lib)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module systolic_array_reconfig_nxn #(
    parameter int N = 16 // Must be an even integer >= 2
)(
    input  logic                                  clk,
    input  logic                                  rst_n,
    input  logic [1:0]                            mode_2b,
    input  logic                                  valid_in,
    input  logic                                  clr_acc,
    input  logic signed [N*4-1 : 0]               A_in,
    input  logic signed [N*4-1 : 0]               B_in,
    output logic                                  valid_out,
    output logic signed [N*N*16-1 : 0]            acc_4x4,
    output logic signed [N*(N/2)*24-1 : 0]        acc_8x4,
    output logic signed [(N/2)*N*24-1 : 0]        acc_4x8,
    output logic signed [(N/2)*(N/2)*32-1 : 0]    acc_8x8
);

    localparam int NUM_TILES_ROW = N / 2; // 8
    localparam int NUM_TILES_COL = N / 2; // 8

    // Internal 2D array mappings for tile interconnections
    logic signed [3:0] horiz_fwd [0:NUM_TILES_ROW-1][0:NUM_TILES_COL][0:1];
    logic signed [3:0] vert_fwd  [0:NUM_TILES_ROW][0:NUM_TILES_COL-1][0:1];

    // Boundary Input Multiplexing (unpacking 1D packed buses to 2D tiles)
    generate
        for (genvar r = 0; r < NUM_TILES_ROW; r++) begin : gen_input_a
            assign horiz_fwd[r][0][0] = A_in[(2*r)*4     +: 4];
            assign horiz_fwd[r][0][1] = A_in[(2*r + 1)*4 +: 4];
        end

        for (genvar c = 0; c < NUM_TILES_COL; c++) begin : gen_input_b
            assign vert_fwd[0][c][0] = B_in[(2*c)*4     +: 4];
            assign vert_fwd[0][c][1] = B_in[(2*c + 1)*4 +: 4];
        end
    endgenerate

    // 2D Array of 2x2 Reconfigurable Tiles (Optimized Interconnect)
    generate
        for (genvar r = 0; r < NUM_TILES_ROW; r++) begin : gen_tile_rows
            for (genvar c = 0; c < NUM_TILES_COL; c++) begin : gen_tile_cols

                // Local PE inputs
                logic signed [3:0] pe_a0, pe_a1, pe_a2, pe_a3;
                logic signed [3:0] pe_b0, pe_b1, pe_b2, pe_b3;

                // Intra-tile streaming registers
                logic signed [3:0] reg_a_mid_0, reg_a_mid_1;
                logic signed [3:0] reg_b_mid_0, reg_b_mid_1;

                // Inter-tile boundary forwarding registers
                logic signed [3:0] reg_a_fwd_0, reg_a_fwd_1;
                logic signed [3:0] reg_b_fwd_0, reg_b_fwd_1;

                logic bypass_a;
                logic bypass_b;
                assign bypass_a = mode_2b[0];
                assign bypass_b = mode_2b[1];

                // 1. Collapsed Invariant Steering Logic (Replacing 4:1 MUXes with 0-gate wires and 2:1 MUXes)
                assign pe_a0 = horiz_fwd[r][c][0];
                assign pe_a1 = mode_2b[0] ? horiz_fwd[r][c][1] : reg_a_mid_0;
                assign pe_a2 = (mode_2b == 2'b00) ? horiz_fwd[r][c][1] : horiz_fwd[r][c][0];
                assign pe_a3 = mode_2b[0] ? horiz_fwd[r][c][1] : (mode_2b[1] ? reg_a_mid_0 : reg_a_mid_1);

                assign pe_b0 = vert_fwd[r][c][0];
                assign pe_b1 = (mode_2b == 2'b00) ? vert_fwd[r][c][1] : vert_fwd[r][c][0];
                assign pe_b2 = mode_2b[1] ? vert_fwd[r][c][1] : reg_b_mid_0;
                assign pe_b3 = mode_2b[1] ? vert_fwd[r][c][1] : (mode_2b[0] ? reg_b_mid_0 : reg_b_mid_1);

                // 2. Synchronous Mode-Gated Tile Pipeline Registers (Gating 512 Inactive Mid-Registers in Modes 01/10/11)
                always_ff @(posedge clk or negedge rst_n) begin
                    if (!rst_n) begin
                        reg_a_mid_0 <= 4'sd0;
                        reg_a_mid_1 <= 4'sd0;
                        reg_a_fwd_0 <= 4'sd0;
                        reg_a_fwd_1 <= 4'sd0;

                        reg_b_mid_0 <= 4'sd0;
                        reg_b_mid_1 <= 4'sd0;
                        reg_b_fwd_0 <= 4'sd0;
                        reg_b_fwd_1 <= 4'sd0;
                    end else begin
                        reg_a_mid_0 <= pe_a0;
                        reg_b_mid_0 <= pe_b0;

                        // Clock-gate unused diagonal skew registers in fused modes
                        if (mode_2b == 2'b00) begin
                            reg_a_mid_1 <= pe_a2;
                            reg_b_mid_1 <= pe_b1;
                        end

                        // Direct streamlined forwarding bypass
                        reg_a_fwd_0 <= bypass_a ? horiz_fwd[r][c][0] : pe_a1;
                        reg_a_fwd_1 <= bypass_a ? horiz_fwd[r][c][1] : pe_a3;

                        reg_b_fwd_0 <= bypass_b ? vert_fwd[r][c][0] : pe_b2;
                        reg_b_fwd_1 <= bypass_b ? vert_fwd[r][c][1] : pe_b3;
                    end
                end

                // Forwarding connections to neighbors
                assign horiz_fwd[r][c+1][0] = reg_a_fwd_0;
                assign horiz_fwd[r][c+1][1] = reg_a_fwd_1;

                assign vert_fwd[r+1][c][0] = reg_b_fwd_0;
                assign vert_fwd[r+1][c][1] = reg_b_fwd_1;

                // Instantiate 2D Reconfigurable Tile (Golden 3.907 mW Module)
                logic signed [15:0] tile_acc_4x4 [0:3];
                logic signed [23:0] tile_acc_8x4_0, tile_acc_8x4_1;
                logic signed [23:0] tile_acc_4x8_0, tile_acc_4x8_1;
                logic signed [31:0] tile_acc_8x8;

                mac_reconfig_2d_baugh_wooley u_reconfig_tile (
                    .clk(clk), .rst_n(rst_n), .mode_2b(mode_2b),
                    .valid_in(valid_in), .clr_acc(clr_acc),
                    .A0(pe_a0), .A1(pe_a1), .A2(pe_a2), .A3(pe_a3),
                    .B0(pe_b0), .B1(pe_b1), .B2(pe_b2), .B3(pe_b3),
                    .valid_out(),
                    .acc_00(tile_acc_4x4[0]),
                    .acc_01(tile_acc_4x4[1]),
                    .acc_10(tile_acc_4x4[2]),
                    .acc_11(tile_acc_4x4[3]),
                    .acc_row0(tile_acc_8x4_0),
                    .acc_row1(tile_acc_8x4_1),
                    .acc_col0(tile_acc_4x8_0),
                    .acc_col1(tile_acc_4x8_1),
                    .acc_32b(tile_acc_8x8)
                );

                // Map Tile Outputs into Top-Level 1D Packed Buses
                // 1. Mode 00 (4x4): 4 PEs per tile mapped to grid (2r, 2c)
                assign acc_4x4[( (2*r + 0)*N + (2*c + 0) )*16 +: 16] = tile_acc_4x4[0];
                assign acc_4x4[( (2*r + 0)*N + (2*c + 1) )*16 +: 16] = tile_acc_4x4[1];
                assign acc_4x4[( (2*r + 1)*N + (2*c + 0) )*16 +: 16] = tile_acc_4x4[2];
                assign acc_4x4[( (2*r + 1)*N + (2*c + 1) )*16 +: 16] = tile_acc_4x4[3];

                // 2. Mode 01 (8x4): Row0 and Row1 mapped to [N, N/2]
                assign acc_8x4[( (2*r + 0)*NUM_TILES_COL + c )*24 +: 24] = tile_acc_8x4_0;
                assign acc_8x4[( (2*r + 1)*NUM_TILES_COL + c )*24 +: 24] = tile_acc_8x4_1;

                // 3. Mode 10 (4x8): Col0 and Col1 mapped to [N/2, N]
                assign acc_4x8[( r*N + (2*c + 0) )*24 +: 24] = tile_acc_4x8_0;
                assign acc_4x8[( r*N + (2*c + 1) )*24 +: 24] = tile_acc_4x8_1;

                // 4. Mode 11 (8x8): Fused tile mapped to [N/2, N/2]
                assign acc_8x8[( r*NUM_TILES_COL + c )*32 +: 32] = tile_acc_8x8;

            end
        end
    endgenerate

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) valid_out <= 1'b0;
        else        valid_out <= valid_in;
    end

endmodule
