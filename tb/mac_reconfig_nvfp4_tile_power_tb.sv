//-----------------------------------------------------------------------------
// Module: mac_reconfig_nvfp4_tile_power_tb.sv
// Description: Standalone Activity Measurement Testbench for 2x2 Macro-Tile
//              supporting INT4 x INT4, INT4 x NVFP4, NVFP4 x INT4, and NVFP4 x NVFP4.
//              Generates activity VCDs for standalone NVFP4 Tile Netlist simulations.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_nvfp4_tile_power_tb;
    localparam time CLK_PERIOD = 2ns; // 500 MHz Clock

    logic        clk, rst_n, valid_in, clr_acc;
    logic [1:0]  mode_2b;
    logic [1:0]  is_nvfp4; // 2'b00 = INT4xINT4, 2'b01 = INT4xNVFP4, 2'b10 = NVFP4xINT4, 2'b11 = NVFP4xNVFP4
    logic [7:0]  scale_block;
    logic signed [3:0] A0, B0, A1, B1, A2, B2, A3, B3;
    logic        valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [23:0] acc_row0, acc_row1;
    logic signed [23:0] acc_col0, acc_col1;
    logic signed [31:0] acc_32b;

    mac_reconfig_2d_baugh_wooley_nvfp4 dut (
        .clk(clk), .rst_n(rst_n), .mode_2b(mode_2b),
        .is_nvfp4(is_nvfp4), .scale_block(scale_block),
        .valid_in(valid_in), .clr_acc(clr_acc),
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
        $dumpfile("nvfp4_tile_power_45nm.vcd");
`endif
        $dumpvars(0, mac_reconfig_nvfp4_tile_power_tb.dut);

        clk = 0; rst_n = 0; mode_2b = 0; is_nvfp4 = 2'b00; scale_block = 8'd0; valid_in = 0; clr_acc = 0;
        A0 = 0; B0 = 0; A1 = 0; B1 = 0; A2 = 0; B2 = 0; A3 = 0; B3 = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        @(negedge clk);
        valid_in = 1;

        //=====================================================================
        // PHASE 1: INT4 x INT4 (is_nvfp4 = 2'b00) - 16 Cycles
        //=====================================================================
        is_nvfp4 = 2'b00;
        for (int m = 0; m < 4; m++) begin
            mode_2b = m[1:0];
            for (int i = 0; i < 4; i++) begin
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
        end

        //=====================================================================
        // PHASE 2: MIXED INT4 (A) x NVFP4 (B) (is_nvfp4 = 2'b01) - 16 Cycles
        //=====================================================================
        is_nvfp4 = 2'b01; // A = INT4, B = NVFP4
        scale_block = 8'd128;
        for (int m = 0; m < 4; m++) begin
            mode_2b = m[1:0];
            for (int i = 0; i < 4; i++) begin
                @(negedge clk);
                clr_acc = (i == 0);
                A0 = (i % 2 == 0) ? -4'sd8 : 4'sd7; // INT4
                B0 = (i % 2 == 0) ? 4'b1111 : 4'b0101; // NVFP4 (-6.0 vs +3.0)
                A1 = (i % 2 == 0) ? 4'sd5  : -4'sd6;
                B1 = (i % 2 == 0) ? 4'b0111 : 4'b1011;
                A2 = (i % 2 == 0) ? -4'sd4 : 4'sd3;
                B2 = (i % 2 == 0) ? 4'b0010 : 4'b1001;
                A3 = (i % 2 == 0) ? 4'sd6  : -4'sd7;
                B3 = (i % 2 == 0) ? 4'b0110 : 4'b1111;
            end
        end

        //=====================================================================
        // PHASE 3: MIXED NVFP4 (A) x INT4 (B) (is_nvfp4 = 2'b10) - 16 Cycles
        //=====================================================================
        is_nvfp4 = 2'b10; // A = NVFP4, B = INT4
        for (int m = 0; m < 4; m++) begin
            mode_2b = m[1:0];
            for (int i = 0; i < 4; i++) begin
                @(negedge clk);
                clr_acc = (i == 0);
                A0 = (i % 2 == 0) ? 4'b1111 : 4'b0110; // NVFP4
                B0 = (i % 2 == 0) ? 4'sd7  : -4'sd8; // INT4
                A1 = (i % 2 == 0) ? 4'b0111 : 4'b1101;
                B1 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
                A2 = (i % 2 == 0) ? 4'b0010 : 4'b1110;
                B2 = (i % 2 == 0) ? 4'sd7  : -4'sd8;
                A3 = (i % 2 == 0) ? 4'b0110 : 4'b1000;
                B3 = (i % 2 == 0) ? -4'sd8 : 4'sd7;
            end
        end

        //=====================================================================
        // PHASE 4: PURE NVFP4 x NVFP4 (is_nvfp4 = 2'b11) - 16 Cycles
        //=====================================================================
        is_nvfp4 = 2'b11; // A = NVFP4, B = NVFP4
        for (int m = 0; m < 4; m++) begin
            mode_2b = m[1:0];
            for (int i = 0; i < 4; i++) begin
                @(negedge clk);
                clr_acc = (i == 0);
                A0 = (i % 2 == 0) ? 4'b1111 : 4'b0110;
                B0 = (i % 2 == 0) ? 4'b0101 : 4'b1100;
                A1 = (i % 2 == 0) ? 4'b0111 : 4'b1101;
                B1 = (i % 2 == 0) ? 4'b1011 : 4'b0100;
                A2 = (i % 2 == 0) ? 4'b0010 : 4'b1110;
                B2 = (i % 2 == 0) ? 4'b1001 : 4'b0011;
                A3 = (i % 2 == 0) ? 4'b0110 : 4'b1000;
                B3 = (i % 2 == 0) ? 4'b1111 : 4'b0101;
            end
        end

        @(negedge clk);
        valid_in = 0;
        #(CLK_PERIOD * 5);
        $display("[PASS] [NVFP4-POWER-TB] Full Mixed-Precision NVFP4/INT4 Activity Simulation Completed Successfully!");
        $finish;
    end

endmodule
