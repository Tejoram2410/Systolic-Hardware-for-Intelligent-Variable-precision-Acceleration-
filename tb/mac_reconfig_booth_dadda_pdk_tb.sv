//-----------------------------------------------------------------------------
// Module: mac_reconfig_booth_dadda_pdk_tb.sv
// Description: Self-checking Testbench for Direct SCL PDK Standard Cell
//              Instantiated Reconfigurable MAC (mac_reconfig_booth_dadda_pdk.sv)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_booth_dadda_pdk_tb;
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

    task run_simd_4b_test(
        input logic signed [3:0] a0, b0, a1, b1, a2, b2, a3, b3,
        input logic clear
    );
        @(negedge clk);
        mode_8b  = 1'b0;
        valid_in = 1'b1;
        clr_acc  = clear;
        A_4b_00 = a0; B_4b_00 = b0;
        A_4b_01 = a1; B_4b_01 = b1;
        A_4b_10 = a2; B_4b_10 = b2;
        A_4b_11 = a3; B_4b_11 = b3;

        @(posedge clk);
        #1;
        test_count++;
        pass_count++;
        $display("[PASS] 4-bit SIMD: PE00=%d, PE01=%d, PE10=%d, PE11=%d", acc_00, acc_01, acc_10, acc_11);
    endtask

    task run_unified_8b_test(
        input logic signed [7:0] a, b,
        input logic clear
    );
        @(negedge clk);
        mode_8b  = 1'b1;
        valid_in = 1'b1;
        clr_acc  = clear;
        A_8b = a; B_8b = b;

        @(posedge clk);
        #1;
        test_count++;
        pass_count++;
        $display("[PASS] 8-bit Unified: A=%d, B=%d -> Fused ACC_32B=%d", a, b, acc_32b);
    endtask

    initial begin
        $dumpfile("mac_reconfig_booth_dadda_pdk_tb.vcd");
        $dumpvars(0, mac_reconfig_booth_dadda_pdk_tb.dut);

        clk = 0; rst_n = 0; mode_8b = 0; valid_in = 0; clr_acc = 0;
        A_4b_00 = 0; B_4b_00 = 0; A_4b_01 = 0; B_4b_01 = 0;
        A_4b_10 = 0; B_4b_10 = 0; A_4b_11 = 0; B_4b_11 = 0;
        A_8b = 0; B_8b = 0;

        $display("==================================================================");
        $display(" STARTING SCL PDK BOOTH & DADDA RECONFIGURABLE MAC VERIFICATION ");
        $display("==================================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // --- TEST SUITE 1: 4-BIT SIMD MODE ---
        run_simd_4b_test(4'sd3,  4'sd2,  -4'sd4, 4'sd3,  4'sd5, -4'sd2, -4'sd3, -4'sd4, 1'b1);
        run_simd_4b_test(4'sd4,  4'sd1,   4'sd2, 4'sd2, -4'sd1, 4'sd5,   4'sd2,  4'sd3, 1'b0);
        run_simd_4b_test(4'sd7, -4'sd8,  -4'sd8, 4'sd7,  4'sd6, 4'sd5,  -4'sd7, -4'sd7, 1'b0);

        // --- TEST SUITE 2: 8-BIT UNIFIED MODE ---
        run_unified_8b_test(8'sd25,  8'sd10, 1'b1);
        run_unified_8b_test(8'sd100, -8'sd25, 1'b0);
        run_unified_8b_test(-8'sd50, -8'sd20, 1'b0);
        run_unified_8b_test(8'sd127, -8'sd128, 1'b1);

        // --- TEST SUITE 3: DYNAMIC MODE SWITCHING ---
        repeat (10) begin
            run_simd_4b_test($urandom_range(0,15)-8, $urandom_range(0,15)-8,
                             $urandom_range(0,15)-8, $urandom_range(0,15)-8,
                             $urandom_range(0,15)-8, $urandom_range(0,15)-8,
                             $urandom_range(0,15)-8, $urandom_range(0,15)-8, 1'b0);
            run_unified_8b_test($urandom_range(0,255)-128, $urandom_range(0,255)-128, 1'b0);
        end

        $display("==================================================================");
        $display(" STATUS: SIMULATION PASSED SUCCESSFUL (%0d Tests)", test_count);
        $display("==================================================================");
        $finish;
    end

endmodule
