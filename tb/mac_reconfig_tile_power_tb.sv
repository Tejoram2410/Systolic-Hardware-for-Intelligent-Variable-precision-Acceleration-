//-----------------------------------------------------------------------------
// Module: mac_reconfig_tile_power_tb.sv
// Description: Standalone Activity Measurement Testbench for 2x2 Macro-Tile
//              Power Sign-Off on SCL 180nm.
//              Generates activity VCDs for standalone Tile Netlist simulations.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_tile_power_tb;
    localparam time CLK_PERIOD = 2ns; // 500 MHz Clock (matched to 45nm synthesis target)

    logic        clk, rst_n, valid_in, clr_acc;
    logic [1:0]  mode_2b;
    logic signed [3:0] A0, B0, A1, B1, A2, B2, A3, B3;
    logic        valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [23:0] acc_row0, acc_row1;
    logic signed [23:0] acc_col0, acc_col1;
    logic signed [31:0] acc_32b;

`ifdef USE_BASELINE_DUT
    mac_reconfig_2d_baugh_wooley_baseline dut (
`else
    mac_reconfig_2d_baugh_wooley dut (
`endif
        .clk(clk), .rst_n(rst_n), .mode_2b(mode_2b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A0(A0), .B0(B0), .A1(A1), .B1(B1), .A2(A2), .B2(B2), .A3(A3), .B3(B3),
        .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01), .acc_10(acc_10), .acc_11(acc_11),
        .acc_row0(acc_row0), .acc_row1(acc_row1),
        .acc_col0(acc_col0), .acc_col1(acc_col1),
        .acc_32b(acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
`ifdef DUMP_VCD_FILE
        $dumpfile(`DUMP_VCD_FILE);
`else
        $dumpfile("tile_power.vcd");
`endif
        $dumpvars(0, mac_reconfig_tile_power_tb.dut);

        clk = 0; rst_n = 0; mode_2b = 0; valid_in = 0; clr_acc = 0;
        A0 = 0; B0 = 0; A1 = 0; B1 = 0; A2 = 0; B2 = 0; A3 = 0; B3 = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        @(negedge clk);
        valid_in = 1;

        // Phase 1: Mode 00 (4x4) - 10 Toggling Cycles
        mode_2b = 2'b00;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            clr_acc = (i == 0);
            A0 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            B0 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            A1 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            B1 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            A2 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            B2 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            A3 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            B3 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
        end

        // Phase 2: Mode 01 (8x4) - 10 Toggling Cycles
        mode_2b = 2'b01;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            clr_acc = (i == 0);
            A0 = (i % 2 == 0) ? 4'h0 : 4'hF;
            A1 = (i % 2 == 0) ? 4'h8 : 4'h7;
            B0 = (i % 2 == 0) ? 4'sd7 : -4'sd8;

            A2 = (i % 2 == 0) ? 4'hF : 4'h0;
            A3 = (i % 2 == 0) ? 4'h7 : 4'h8;
            B1 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
        end

        // Phase 3: Mode 10 (4x8) - 10 Toggling Cycles
        mode_2b = 2'b10;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            clr_acc = (i == 0);
            A0 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            B0 = (i % 2 == 0) ? 4'h0 : 4'hF;
            B2 = (i % 2 == 0) ? 4'h8 : 4'h7;

            A1 = (i % 2 == 0) ? 4'sd7 : -4'sd8;
            B1 = (i % 2 == 0) ? 4'hF : 4'h0;
            B3 = (i % 2 == 0) ? 4'h7 : 4'h8;
        end

        // Phase 4: Mode 11 (8x8) - 10 Toggling Cycles
        mode_2b = 2'b11;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            clr_acc = (i == 0);
            A0 = (i % 2 == 0) ? 4'h0 : 4'hF;
            A1 = (i % 2 == 0) ? 4'h8 : 4'h7;
            B0 = (i % 2 == 0) ? 4'h0 : 4'hF;
            B2 = (i % 2 == 0) ? 4'h8 : 4'h7;
        end

        // Phase 5: Dynamic Mode Interleaving - 16 Cycles
        for (int i = 0; i < 16; i++) begin
            @(negedge clk);
            mode_2b = i % 4;
            clr_acc = (i % 4 == 0);
            A0 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            B0 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            A1 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            B1 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            A2 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            B2 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            A3 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
            B3 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
        end

        @(negedge clk);
        valid_in = 0;
        #(CLK_PERIOD * 5);
        $display("[PASS] [TILE-POWER-TB] Standalone Tile Activity Simulation Completed Successfully!");
        $finish;
    end

endmodule
