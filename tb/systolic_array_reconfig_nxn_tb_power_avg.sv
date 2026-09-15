//-----------------------------------------------------------------------------
// Module: systolic_array_reconfig_nxn_tb_power_avg.sv
// Description: Typical ML Workload Activity Measurement Testbench for Scalable
//              N x N Reconfigurable Systolic Array (N=16, 256 Physical PEs).
//              Compatible with BOTH RTL and Gate-Level Netlist Simulation.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module systolic_array_reconfig_nxn_tb_power_avg;
    localparam time CLK_PERIOD = 10ns;
    localparam int N = 16;
    localparam int NUM_TILES_ROW = N / 2; // 8
    localparam int NUM_TILES_COL = N / 2; // 8

    logic                                  clk, rst_n, valid_in, clr_acc;
    logic [1:0]                            mode_2b;
    logic signed [N*4-1 : 0]               A_in;
    logic signed [N*4-1 : 0]               B_in;
    logic                                  valid_out;

    logic signed [N*N*16-1 : 0]            acc_4x4;
    logic signed [N*(N/2)*24-1 : 0]        acc_8x4;
    logic signed [(N/2)*N*24-1 : 0]        acc_4x8;
    logic signed [(N/2)*(N/2)*32-1 : 0]    acc_8x8;
    logic signed [7:0]                     a_val_8b, b_val_8b;

`ifndef DUMP_VCD_FILE
    `define DUMP_VCD_FILE "systolic_opt_power_avg.vcd"
`endif

    // Direct instantiation without parameter block (100% Netlist & RTL compatible)
`ifdef USE_BASELINE_DUT
    systolic_array_reconfig_nxn_baseline dut (
`else
    systolic_array_reconfig_nxn dut (
`endif
        .clk(clk), .rst_n(rst_n), .mode_2b(mode_2b),
        .valid_in(valid_in), .clr_acc(clr_acc),
        .A_in(A_in), .B_in(B_in),
        .valid_out(valid_out),
        .acc_4x4(acc_4x4),
        .acc_8x4(acc_8x4),
        .acc_4x8(acc_4x8),
        .acc_8x8(acc_8x8)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper functions for ML distributions
    function automatic logic signed [3:0] gen_ml_int4_act();
        return $urandom_range(0, 7);
    endfunction

    function automatic logic signed [3:0] gen_ml_int4_wgt();
        if ($urandom_range(0, 3) == 0) return 4'sd0;
        return $urandom_range(0, 7) - 4;
    endfunction

    function automatic logic signed [7:0] gen_ml_int8_act();
        return $urandom_range(0, 127);
    endfunction

    function automatic logic signed [7:0] gen_ml_int8_wgt();
        if ($urandom_range(0, 3) == 0) return 8'sd0;
        return $urandom_range(0, 127) - 64;
    endfunction

    initial begin
        $dumpfile(`DUMP_VCD_FILE);
        $dumpvars(0, systolic_array_reconfig_nxn_tb_power_avg.dut);

        clk = 0; rst_n = 0; mode_2b = 0; valid_in = 0; clr_acc = 0;
        A_in = '0; B_in = '0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        @(negedge clk);

        // ====================================================================
        // PHASE 1: Mode 00 (4x4 SIMD) - 15 Typical INT4 ML Operations
        // ====================================================================
        mode_2b  = 2'b00;
        valid_in = 1'b1;

        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int i = 0; i < N; i++) begin
                A_in[i*4 +: 4] = gen_ml_int4_act();
                B_in[i*4 +: 4] = gen_ml_int4_wgt();
            end
        end

        // ====================================================================
        // PHASE 2: Mode 01 (8x4 Horizontal) - 15 Typical W4A8 ML Operations
        // ====================================================================
        mode_2b = 2'b01;
        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int i = 0; i < N/2; i++) begin
                a_val_8b = gen_ml_int8_act();
                A_in[(2*i)*4     +: 4] = a_val_8b[3:0];
                A_in[(2*i + 1)*4 +: 4] = a_val_8b[7:4];

                B_in[(2*i)*4     +: 4] = gen_ml_int4_wgt();
                B_in[(2*i + 1)*4 +: 4] = gen_ml_int4_wgt();
            end
        end

        // ====================================================================
        // PHASE 3: Mode 10 (4x8 Vertical) - 15 Typical W8A4 ML Operations
        // ====================================================================
        mode_2b = 2'b10;
        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int j = 0; j < N/2; j++) begin
                A_in[(2*j)*4     +: 4] = gen_ml_int4_act();
                A_in[(2*j + 1)*4 +: 4] = gen_ml_int4_act();

                b_val_8b = gen_ml_int8_wgt();
                B_in[(2*j)*4     +: 4] = b_val_8b[3:0];
                B_in[(2*j + 1)*4 +: 4] = b_val_8b[7:4];
            end
        end

        // ====================================================================
        // PHASE 4: Mode 11 (8x8 Unified) - 15 Typical INT8 ML Operations
        // ====================================================================
        mode_2b = 2'b11;
        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int i = 0; i < N/2; i++) begin
                a_val_8b = gen_ml_int8_act();
                b_val_8b = gen_ml_int8_wgt();
                A_in[(2*i)*4     +: 4] = a_val_8b[3:0];
                A_in[(2*i + 1)*4 +: 4] = a_val_8b[7:4];
                B_in[(2*i)*4     +: 4] = b_val_8b[3:0];
                B_in[(2*i + 1)*4 +: 4] = b_val_8b[7:4];
            end
        end

        // ====================================================================
        // PHASE 5: Dynamic Mode Interleaving - 16 Typical Multi-Layer Operations
        // ====================================================================
        for (int op = 0; op < 16; op++) begin
            @(negedge clk);
            mode_2b = op % 4;
            clr_acc = (op % 4 == 0);
            for (int i = 0; i < N; i++) begin
                A_in[i*4 +: 4] = gen_ml_int4_act();
                B_in[i*4 +: 4] = gen_ml_int4_wgt();
            end
        end

        @(negedge clk);
        valid_in = 1'b0;
        #(CLK_PERIOD * 5);
        $display("[PASS] [POWER-AVG-TB] Typical ML Workload Activity Stimulus successfully generated for all 4 modes on N=16 (256 PEs)!");
        $display(">>> AVERAGE ML WORKLOAD ACTIVITY SIMULATION COMPLETED: VCD DUMP WRITTEN OUT. <<<");
        $finish;
    end

endmodule
