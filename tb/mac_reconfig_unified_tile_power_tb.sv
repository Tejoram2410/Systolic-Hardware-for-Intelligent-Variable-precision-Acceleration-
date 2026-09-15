//-----------------------------------------------------------------------------
// Module: mac_reconfig_unified_tile_power_tb.sv
// Description: Dynamic Activity Stimulus Testbench for 12-Mode Unified MAC Tile
//              Generates VCD Activity Dump covering all 12 operational modes:
//                - Pure INTxINT (Modes 00, 01, 10, 11)
//                - Pure FPxFP (Modes 00, 01, 10, 11 across FP8 E4M3, E5M2, FP4 E2M1)
//                - Mixed INTxFP (Modes 00, 01, 10, 11 Harmonia W8A8 mixed dot)
//              Compatible with BOTH RTL and Gate-Level Netlist Simulation.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_unified_tile_power_tb;

    localparam time CLK_PERIOD = 10ns;

    logic        clk, rst_n, valid_in, clr_acc;
    logic [1:0]  mode_2b;
    logic        type_a, type_b;
    logic [1:0]  format_a, format_b;
    logic [7:0]  A0_in, B0_in, A1_in, B1_in, A2_in, B2_in, A3_in, B3_in;

    logic        valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [23:0] acc_row0, acc_row1, acc_col0, acc_col1;
    logic signed [31:0] acc_32b;
    logic signed [5:0]  block_exp;

`ifndef DUMP_VCD_FILE
    `define DUMP_VCD_FILE "mac_unified_tile_power.vcd"
`endif

    // Direct instantiation for 100% Netlist compatibility
    mac_reconfig_unified_tile dut (
        .clk(clk), .rst_n(rst_n),
        .mode_2b(mode_2b), .type_a(type_a), .type_b(type_b),
        .format_a(format_a), .format_b(format_b),
        .valid_in(valid_in), .clr_acc(clr_acc),
        .A0_in(A0_in), .B0_in(B0_in),
        .A1_in(A1_in), .B1_in(B1_in),
        .A2_in(A2_in), .B2_in(B2_in),
        .A3_in(A3_in), .B3_in(B3_in),
        .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01),
        .acc_10(acc_10), .acc_11(acc_11),
        .acc_row0(acc_row0), .acc_row1(acc_row1),
        .acc_col0(acc_col0), .acc_col1(acc_col1),
        .acc_32b(acc_32b), .block_exp(block_exp)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper functions for randomized realistic ML distributions
    function automatic logic [7:0] gen_ml_fp8();
        logic sign; logic [3:0] exp; logic [2:0] mant;
        sign = $urandom_range(0, 1);
        exp  = $urandom_range(4, 9); // Exponents around 1.0 (bias=7)
        mant = $urandom_range(0, 7);
        return {sign, exp, mant};
    endfunction

    function automatic logic [7:0] gen_ml_int8();
        if ($urandom_range(0, 3) == 0) return 8'sd0; // 25% zero sparsity
        return $urandom_range(0, 255);
    endfunction

    initial begin
        $dumpfile(`DUMP_VCD_FILE);
        $dumpvars(0, mac_reconfig_unified_tile_power_tb.dut);

        clk = 0; rst_n = 0; valid_in = 0; clr_acc = 1;
        mode_2b = 2'b00; type_a = 0; type_b = 0; format_a = 0; format_b = 0;
        A0_in = 0; B0_in = 0; A1_in = 0; B1_in = 0;
        A2_in = 0; B2_in = 0; A3_in = 0; B3_in = 0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        @(negedge clk);

        //=====================================================================
        // PHASE 1: PURE INTxINT WORKLOADS (Modes 00, 01, 10, 11) - 20 cycles
        //=====================================================================
        type_a = 0; type_b = 0; valid_in = 1; clr_acc = 0;

        for (int m = 0; m < 4; m++) begin
            mode_2b = m[1:0];
            format_a = (m == 0) ? 2'b00 : 2'b01;
            format_b = (m == 2 || m == 3) ? 2'b01 : 2'b00;

            for (int cyc = 0; cyc < 5; cyc++) begin
                A0_in = gen_ml_int8(); B0_in = gen_ml_int8();
                A1_in = gen_ml_int8(); B1_in = gen_ml_int8();
                A2_in = gen_ml_int8(); B2_in = gen_ml_int8();
                A3_in = gen_ml_int8(); B3_in = gen_ml_int8();
                @(negedge clk);
            end
        end

        //=====================================================================
        // PHASE 2: PURE FPxFP WORKLOADS (Modes 00, 01, 10, 11) - 20 cycles
        //=====================================================================
        type_a = 1; type_b = 1;

        for (int m = 0; m < 4; m++) begin
            mode_2b = m[1:0];
            format_a = (m % 2 == 0) ? 2'b00 : 2'b01;
            format_b = (m % 2 == 0) ? 2'b00 : 2'b01;

            for (int cyc = 0; cyc < 5; cyc++) begin
                A0_in = gen_ml_fp8(); B0_in = gen_ml_fp8();
                A1_in = gen_ml_fp8(); B1_in = gen_ml_fp8();
                A2_in = gen_ml_fp8(); B2_in = gen_ml_fp8();
                A3_in = gen_ml_fp8(); B3_in = gen_ml_fp8();
                @(negedge clk);
            end
        end

        //=====================================================================
        // PHASE 3: MIXED INTxFP WORKLOADS (Modes 00, 01, 10, 11) - 20 cycles
        //=====================================================================
        type_a = 0; type_b = 1;

        for (int m = 0; m < 4; m++) begin
            mode_2b = m[1:0];
            format_a = (m == 0) ? 2'b00 : 2'b01;
            format_b = 2'b00;

            for (int cyc = 0; cyc < 5; cyc++) begin
                A0_in = gen_ml_int8(); B0_in = gen_ml_fp8();
                A1_in = gen_ml_int8(); B1_in = gen_ml_fp8();
                A2_in = gen_ml_int8(); B2_in = gen_ml_fp8();
                A3_in = gen_ml_int8(); B3_in = gen_ml_fp8();
                @(negedge clk);
            end
        end

        #(CLK_PERIOD * 2);
        $display("[PASS] UNIFIED MAC TILE FULL-PRECISION POWER STIMULUS GENERATION COMPLETE");
        $finish;
    end

endmodule
