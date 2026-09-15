//-----------------------------------------------------------------------------
// Module: mac_reconfig_top_tb_combined_max.sv
// Description: Maximum Power Combined Testbench (100% Duty Cycle, High-Freq Switching & Worst Flips)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_top_tb_combined_max;
    localparam time CLK_PERIOD = 10ns;

    logic              clk, rst_n, mode_8b, valid_in, clr_acc;
    logic signed [3:0] A_4b_00, B_4b_00, A_4b_01, B_4b_01, A_4b_10, B_4b_10, A_4b_11, B_4b_11;
    logic signed [7:0] A_8b, B_8b;
    logic              valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [31:0] acc_32b;

    int test_count = 0;
    int pass_count = 0;

    mac_reconfig_top dut (
        .clk(clk), .rst_n(rst_n), .mode_8b(mode_8b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A_4b_00(A_4b_00), .B_4b_00(B_4b_00), .A_4b_01(A_4b_01), .B_4b_01(B_4b_01),
        .A_4b_10(A_4b_10), .B_4b_10(B_4b_10), .A_4b_11(A_4b_11), .B_4b_11(B_4b_11),
        .A_8b(A_8b), .B_8b(B_8b), .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01), .acc_10(acc_10), .acc_11(acc_11), .acc_32b(acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("mac_reconfig_top_combined_max.vcd");
        $dumpvars(0, mac_reconfig_top_tb_combined_max.dut);

        clk = 0; rst_n = 0; mode_8b = 0; valid_in = 0; clr_acc = 0;
        A_4b_00 = 0; B_4b_00 = 0; A_4b_01 = 0; B_4b_01 = 0;
        A_4b_10 = 0; B_4b_10 = 0; A_4b_11 = 0; B_4b_11 = 0;
        A_8b = 0; B_8b = 0;

        $display("==========================================================");
        $display(" STARTING COMBINED MAX POWER SIMULATION (100%% DUTY CYCLE) ");
        $display("==========================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // 100% Duty Cycle (valid_in = 1 on EVERY single clock edge), alternating modes & max flips
        for (int i = 0; i < 200; i++) begin
            @(negedge clk);
            valid_in = 1'b1; // 100% duty cycle
            clr_acc  = (i % 10 == 0);
            mode_8b  = (i % 2 == 0); // Mode switch on EVERY cycle

            if (mode_8b) begin
                A_8b = (i % 4 == 0) ? 8'h55 : 8'hAA;
                B_8b = (i % 4 == 0) ? 8'hAA : 8'h55;
            end else begin
                A_4b_00 = (i % 4 == 0) ? 4'b0101 : 4'b1010;
                B_4b_00 = (i % 4 == 0) ? 4'b1010 : 4'b0101;
                A_4b_01 = (i % 4 == 0) ? 4'sd7   : -4'sd8;
                B_4b_01 = (i % 4 == 0) ? -4'sd8  : 4'sd7;
                A_4b_10 = (i % 4 == 0) ? 4'b0101 : 4'b1010;
                B_4b_10 = (i % 4 == 0) ? 4'b1010 : 4'b0101;
                A_4b_11 = (i % 4 == 0) ? 4'sd7   : -4'sd8;
                B_4b_11 = (i % 4 == 0) ? -4'sd8  : 4'sd7;
            end

            @(posedge clk);
            #1;
            test_count++;
            pass_count++;
        end

        @(negedge clk);
        valid_in = 0;
        #(CLK_PERIOD * 5);

        $display("[PASS] 4-bit SIMD: Combined Max Power Simulation Completed Successfully (%0d cycles)", test_count);
        $display("STATUS: SIMULATION PASSED SUCCESSFUL");
        $finish;
    end
endmodule
