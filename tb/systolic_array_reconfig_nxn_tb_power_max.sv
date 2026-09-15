//-----------------------------------------------------------------------------
// Module: systolic_array_reconfig_nxn_tb_power_max.sv
// Description: Peak Stress Activity Measurement Testbench for Scalable
//              N x N Reconfigurable Systolic Array (N=16, 256 Physical PEs).
//              Compatible with BOTH RTL and Gate-Level Netlist Simulation.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module systolic_array_reconfig_nxn_tb_power_max;
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
    `define DUMP_VCD_FILE "systolic_opt_power_max.vcd"
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

    initial begin
        $dumpfile(`DUMP_VCD_FILE);
        $dumpvars(0, systolic_array_reconfig_nxn_tb_power_max.dut);

        clk = 0; rst_n = 0; mode_2b = 0; valid_in = 0; clr_acc = 0;
        A_in = '0; B_in = '0;

        #(CLK_PERIOD * 3);
        rst_n = 1;
        @(negedge clk);

        // ====================================================================
        // PHASE 1: Mode 00 (4x4 SIMD) - 15 Aggressive Peak Operations on 256 PEs
        // ====================================================================
        mode_2b  = 2'b00;
        valid_in = 1'b1;
        clr_acc  = 1'b1;

        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int i = 0; i < N; i++) begin
                A_in[i*4 +: 4] = (op % 2 == 0) ? -4'sd8 : 4'sd7;
                B_in[i*4 +: 4] = (op % 2 == 0) ? 4'sd7  : -4'sd8;
            end
        end

        // ====================================================================
        // PHASE 2: Mode 01 (8x4 Horizontal) - 15 Aggressive Peak Operations
        // ====================================================================
        mode_2b = 2'b01;
        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int i = 0; i < N/2; i++) begin
                a_val_8b = (op % 2 == 0) ? -8'sd128 : 8'sd127;
                A_in[(2*i)*4     +: 4] = a_val_8b[3:0];
                A_in[(2*i + 1)*4 +: 4] = a_val_8b[7:4];

                B_in[(2*i)*4     +: 4] = (op % 2 == 0) ? 4'sd7 : -4'sd8;
                B_in[(2*i + 1)*4 +: 4] = (op % 2 == 0) ? -4'sd8 : 4'sd7;
            end
        end

        // ====================================================================
        // PHASE 3: Mode 10 (4x8 Vertical) - 15 Aggressive Peak Operations
        // ====================================================================
        mode_2b = 2'b10;
        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int j = 0; j < N/2; j++) begin
                A_in[(2*j)*4     +: 4] = (op % 2 == 0) ? -4'sd8 : 4'sd7;
                A_in[(2*j + 1)*4 +: 4] = (op % 2 == 0) ? 4'sd7 : -4'sd8;

                b_val_8b = (op % 2 == 0) ? 8'sd127 : -8'sd128;
                B_in[(2*j)*4     +: 4] = b_val_8b[3:0];
                B_in[(2*j + 1)*4 +: 4] = b_val_8b[7:4];
            end
        end

        // ====================================================================
        // PHASE 4: Mode 11 (8x8 Unified) - 15 Aggressive Peak Operations
        // ====================================================================
        mode_2b = 2'b11;
        for (int op = 0; op < 15; op++) begin
            @(negedge clk);
            clr_acc = (op == 0);
            for (int i = 0; i < N/2; i++) begin
                a_val_8b = (op % 2 == 0) ? -8'sd128 : 8'sd127;
                b_val_8b = (op % 2 == 0) ? 8'sd127  : -8'sd128;
                A_in[(2*i)*4     +: 4] = a_val_8b[3:0];
                A_in[(2*i + 1)*4 +: 4] = a_val_8b[7:4];
                B_in[(2*i)*4     +: 4] = b_val_8b[3:0];
                B_in[(2*i + 1)*4 +: 4] = b_val_8b[7:4];
            end
        end

        // ====================================================================
        // PHASE 5: Dynamic Mode Interleaving - 16 Aggressive Operations
        // ====================================================================
        for (int op = 0; op < 16; op++) begin
            @(negedge clk);
            mode_2b = op % 4;
            clr_acc = (op % 4 == 0);
            for (int i = 0; i < N; i++) begin
                A_in[i*4 +: 4] = (op % 2 == 0) ? -4'sd8 : 4'sd7;
                B_in[i*4 +: 4] = (op % 2 == 0) ? 4'sd7  : -4'sd8;
            end
        end

        @(negedge clk);
        valid_in = 1'b0;
        #(CLK_PERIOD * 5);
        $display("[PASS] [POWER-MAX-TB] Peak Activity Stimulus successfully generated for all 4 modes on N=16 (256 PEs)!");
        $display(">>> PEAK ACTIVITY SIMULATION COMPLETED: VCD DUMP WRITTEN OUT. <<<");
        $finish;
    end

endmodule
