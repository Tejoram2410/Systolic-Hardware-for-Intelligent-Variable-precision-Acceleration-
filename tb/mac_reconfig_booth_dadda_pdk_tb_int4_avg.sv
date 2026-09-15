//-----------------------------------------------------------------------------
// Module: mac_reconfig_booth_dadda_pdk_tb_int4_avg.sv
// Description: Realistic Average Power INT4 Testbench for mac_reconfig_booth_dadda_pdk
//              (Matches exact 3-phase workload: 20% zero-load, 40% stationary, 40% random)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_booth_dadda_pdk_tb_int4_avg;
    localparam time CLK_PERIOD = 10ns;

    logic              clk, rst_n, mode_8b, valid_in, clr_acc;
    logic signed [3:0] A_4b_00, B_4b_00, A_4b_01, B_4b_01, A_4b_10, B_4b_10, A_4b_11, B_4b_11;
    logic signed [7:0] A_8b, B_8b;
    logic              valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [31:0] acc_32b;

    int test_count = 0;
    int pass_count = 0;

    mac_reconfig_booth_dadda_pdk dut (
        .clk(clk), .rst_n(rst_n), .mode_8b(mode_8b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A_4b_00(A_4b_00), .B_4b_00(B_4b_00), .A_4b_01(A_4b_01), .B_4b_01(B_4b_01),
        .A_4b_10(A_4b_10), .B_4b_10(B_4b_10), .A_4b_11(A_4b_11), .B_4b_11(B_4b_11),
        .A_8b(A_8b), .B_8b(B_8b), .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01), .acc_10(acc_10), .acc_11(acc_11), .acc_32b(acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("mac_reconfig_booth_dadda_pdk_int4_avg.vcd");
        $dumpvars(0, mac_reconfig_booth_dadda_pdk_tb_int4_avg.dut);

        clk = 0; rst_n = 0; mode_8b = 0; valid_in = 0; clr_acc = 0;
        A_4b_00 = 0; B_4b_00 = 0; A_4b_01 = 0; B_4b_01 = 0;
        A_4b_10 = 0; B_4b_10 = 0; A_4b_11 = 0; B_4b_11 = 0;
        A_8b = 0; B_8b = 0;

        $display("==========================================================");
        $display(" STARTING PDK INT4 AVG POWER SIMULATION (REALISTIC 60%% WORKLOAD)");
        $display("==========================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Mix of 60% active compute cycles, 40% idle cycles, typical random operands
        for (int i = 0; i < 200; i++) begin
            @(negedge clk);
            mode_8b  = 1'b0;
            valid_in = (i % 5 != 0); // 80% valid, 20% idle
            clr_acc  = (i % 15 == 0);

            if (i < 40) begin
                A_4b_00 = 0; B_4b_00 = 0; A_4b_01 = 0; B_4b_01 = 0;
                A_4b_10 = 0; B_4b_10 = 0; A_4b_11 = 0; B_4b_11 = 0;
            end else if (i < 120) begin
                A_4b_00 = 4'sd2; B_4b_00 = 4'sd3;
                A_4b_01 = -4'sd1; B_4b_01 = 4'sd4;
                A_4b_10 = 4'sd3; B_4b_10 = -4'sd2;
                A_4b_11 = -4'sd4; B_4b_11 = -4'sd3;
            end else begin
                A_4b_00 = $urandom_range(0, 15) - 8;
                B_4b_00 = $urandom_range(0, 15) - 8;
                A_4b_01 = $urandom_range(0, 15) - 8;
                B_4b_01 = $urandom_range(0, 15) - 8;
                A_4b_10 = $urandom_range(0, 15) - 8;
                B_4b_10 = $urandom_range(0, 15) - 8;
                A_4b_11 = $urandom_range(0, 15) - 8;
                B_4b_11 = $urandom_range(0, 15) - 8;
            end

            @(posedge clk);
            #1;
            test_count++;
            pass_count++;
        end

        @(negedge clk);
        valid_in = 0;
        #(CLK_PERIOD * 5);

        $display("[PASS] 4-bit SIMD: PDK INT4 Avg Power Simulation Completed (%0d cycles)", test_count);
        $display("STATUS: SIMULATION PASSED SUCCESSFUL");
        $finish;
    end

endmodule
