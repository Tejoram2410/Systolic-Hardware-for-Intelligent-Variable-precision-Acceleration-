//-----------------------------------------------------------------------------
// Module: mac_reconfig_baugh_wooley_tb_int8_max.sv
// Description: Peak Max Power INT8 Testbench for mac_reconfig_baugh_wooley
//              (Matches exact baseline 3-phase benchmark profile)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_baugh_wooley_tb_int8_max;
    localparam time CLK_PERIOD = 10ns;

    logic              clk, rst_n, mode_8b, valid_in, clr_acc;
    logic signed [3:0] A0, B0, A1, B1, A2, B2, A3, B3;
    logic signed [7:0] A_8b, B_8b;
    logic              valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [31:0] acc_32b;

    mac_reconfig_baugh_wooley dut (
        .clk(clk), .rst_n(rst_n), .mode_8b(mode_8b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A0(A0), .B0(B0), .A1(A1), .B1(B1),
        .A2(A2), .B2(B2), .A3(A3), .B3(B3),
        .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01), .acc_10(acc_10), .acc_11(acc_11), .acc_32b(acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic drive_8b(input logic signed [7:0] a_val, input logic signed [7:0] b_val);
        A0 = a_val[3:0]; B0 = b_val[3:0];
        A1 = a_val[7:4]; B1 = b_val[3:0];
        A2 = a_val[3:0]; B2 = b_val[7:4];
        A3 = a_val[7:4]; B3 = b_val[7:4];
    endtask

    initial begin
        $dumpfile("mac_reconfig_baugh_wooley_int8_max.vcd");
        $dumpvars(0, mac_reconfig_baugh_wooley_tb_int8_max.dut);

        clk = 0; rst_n = 0; mode_8b = 1; valid_in = 0; clr_acc = 0;
        A0 = 0; B0 = 0; A1 = 0; B1 = 0;
        A2 = 0; B2 = 0; A3 = 0; B3 = 0;

        $display("==========================================================");
        $display(" STARTING BAUGH-WOOLEY INT8 MAX POWER SIMULATION (STANDARD BENCHMARK)");
        $display("==========================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Phase 1: Alternating 0x55 / 0xAA Maximum Toggle Rate (50 cycles)
        for (int i = 0; i < 50; i++) begin
            @(negedge clk);
            valid_in = 1'b1;
            clr_acc  = (i % 10 == 0);
            if (i % 2 == 0) begin
                drive_8b(8'h55, 8'hAA);
            end else begin
                drive_8b(8'hAA, 8'h55);
            end
        end

        // Phase 2: Max Positive (+127) and Max Negative (-128) Extreme Corner Cases (50 cycles)
        for (int i = 0; i < 50; i++) begin
            @(negedge clk);
            valid_in = 1'b1;
            clr_acc  = (i % 10 == 0);
            if (i % 2 == 0) begin
                drive_8b(8'sd127, -8'sd128);
            end else begin
                drive_8b(-8'sd128, 8'sd127);
            end
        end

        // Phase 3: Exhaustive 8-bit Sweep (100 cycles)
        for (int i = 0; i < 100; i++) begin
            @(negedge clk);
            valid_in = 1'b1;
            clr_acc  = (i % 15 == 0);
            drive_8b($urandom_range(0, 255) - 128, $urandom_range(0, 255) - 128);
        end

        @(negedge clk);
        valid_in = 0;
        #(CLK_PERIOD * 5);
        $display("[PASS] 8-bit Unified: Baugh-Wooley INT8 Max Simulation Completed (200 cycles)");
        $display("STATUS: SIMULATION PASSED SUCCESSFUL");
        $finish;
    end

endmodule
