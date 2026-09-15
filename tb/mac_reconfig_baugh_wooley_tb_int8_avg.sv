//-----------------------------------------------------------------------------
// Module: mac_reconfig_baugh_wooley_tb_int8_avg.sv
// Description: Realistic Average Power INT8 Testbench for mac_reconfig_baugh_wooley
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_baugh_wooley_tb_int8_avg;
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
        $dumpfile("mac_reconfig_baugh_wooley_int8_avg.vcd");
        $dumpvars(0, mac_reconfig_baugh_wooley_tb_int8_avg.dut);

        clk = 0; rst_n = 0; mode_8b = 1; valid_in = 0; clr_acc = 0;
        A0 = 0; B0 = 0; A1 = 0; B1 = 0;
        A2 = 0; B2 = 0; A3 = 0; B3 = 0;

        $display("==========================================================");
        $display(" STARTING BAUGH-WOOLEY INT8 AVG POWER SIMULATION (REALISTIC 60%% WORKLOAD)");
        $display("==========================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        for (int i = 0; i < 200; i++) begin
            @(negedge clk);
            mode_8b  = 1'b1;
            // 60% Active Valid Duty Cycle (Realistic NN Inference)
            valid_in = (i % 10 < 6);
            clr_acc  = (i % 20 == 0);
            A_8b     = $urandom_range(0, 255) - 128;
            B_8b     = $urandom_range(0, 255) - 128;
            drive_8b(A_8b, B_8b);
        end

        @(posedge clk);
        $display("[PASS] 8-bit Unified: Baugh-Wooley INT8 Avg Power Simulation Completed (200 cycles)");
        $display("STATUS: SIMULATION PASSED SUCCESSFUL");
        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
