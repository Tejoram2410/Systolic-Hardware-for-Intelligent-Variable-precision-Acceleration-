//-----------------------------------------------------------------------------
// Module: mac_reconfig_baugh_wooley_tb.sv
// Description: Self-Checking Testbench for mac_reconfig_baugh_wooley
//              with Single-Port Pin-Reused Interface (A0..A3, B0..B3)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_baugh_wooley_tb;
    localparam time CLK_PERIOD = 10ns;

    logic              clk, rst_n, mode_8b, valid_in, clr_acc;
    logic signed [3:0] A0, B0, A1, B1, A2, B2, A3, B3;
    logic              valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [31:0] acc_32b;

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    longint ref_acc_00 = 0;
    longint ref_acc_01 = 0;
    longint ref_acc_10 = 0;
    longint ref_acc_11 = 0;
    longint ref_acc_32b = 0;

    mac_reconfig_baugh_wooley dut (
        .clk(clk), .rst_n(rst_n), .mode_8b(mode_8b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A0(A0), .B0(B0), .A1(A1), .B1(B1),
        .A2(A2), .B2(B2), .A3(A3), .B3(B3),
        .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01), .acc_10(acc_10), .acc_11(acc_11), .acc_32b(acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic check_4b(
        input logic signed [3:0] a00, b00, a01, b01, a10, b10, a11, b11,
        input logic do_clr,
        input string test_name
    );
        longint p0, p1, p2, p3;
        p0 = $signed(a00) * $signed(b00);
        p1 = $signed(a01) * $signed(b01);
        p2 = $signed(a10) * $signed(b10);
        p3 = $signed(a11) * $signed(b11);

        if (do_clr) begin
            ref_acc_00 = p0;
            ref_acc_01 = p1;
            ref_acc_10 = p2;
            ref_acc_11 = p3;
        end else begin
            ref_acc_00 += p0;
            ref_acc_01 += p1;
            ref_acc_10 += p2;
            ref_acc_11 += p3;
        end

        @(negedge clk);
        mode_8b  = 1'b0;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A0 = a00; B0 = b00;
        A1 = a01; B1 = b01;
        A2 = a10; B2 = b10;
        A3 = a11; B3 = b11;

        @(posedge clk);
        #1;
        test_count++;
        if (acc_00 === ref_acc_00[15:0] && acc_01 === ref_acc_01[15:0] &&
            acc_10 === ref_acc_10[15:0] && acc_11 === ref_acc_11[15:0]) begin
            pass_count++;
            $display("[PASS] 4-bit SIMD: %s | ACCs=[%0d, %0d, %0d, %0d]", test_name, acc_00, acc_01, acc_10, acc_11);
        end else begin
            fail_count++;
            $display("[FAIL] 4-bit SIMD: %s | Got {%0d, %0d, %0d, %0d} Exp {%0d, %0d, %0d, %0d}",
                     test_name, acc_00, acc_01, acc_10, acc_11,
                     ref_acc_00[15:0], ref_acc_01[15:0], ref_acc_10[15:0], ref_acc_11[15:0]);
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    task automatic check_8b(
        input logic signed [7:0] a8, b8,
        input logic do_clr,
        input string test_name
    );
        longint prod;
        prod = $signed(a8) * $signed(b8);

        if (do_clr) begin
            ref_acc_32b = prod;
        end else begin
            ref_acc_32b += prod;
        end

        @(negedge clk);
        mode_8b  = 1'b1;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        // External bit-slice routing to 4-bit PE pins
        A0 = a8[3:0]; B0 = b8[3:0];
        A1 = a8[7:4]; B1 = b8[3:0];
        A2 = a8[3:0]; B2 = b8[7:4];
        A3 = a8[7:4]; B3 = b8[7:4];

        @(posedge clk);
        #1;
        test_count++;
        if (acc_32b === ref_acc_32b[31:0]) begin
            pass_count++;
            $display("[PASS] 8-bit Unified: %s | A=%4d, B=%4d -> ACC_32B=%10d", test_name, a8, b8, acc_32b);
        end else begin
            fail_count++;
            $display("[FAIL] 8-bit Unified: %s | A=%0d, B=%0d -> Got ACC_32B=%0d, Exp=%0d",
                     test_name, a8, b8, acc_32b, ref_acc_32b[31:0]);
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    initial begin
        $dumpfile("mac_reconfig_baugh_wooley_tb.vcd");
        $dumpvars(0, mac_reconfig_baugh_wooley_tb.dut);

        clk = 0; rst_n = 0; mode_8b = 0; valid_in = 0; clr_acc = 0;
        A0 = 0; B0 = 0; A1 = 0; B1 = 0;
        A2 = 0; B2 = 0; A3 = 0; B3 = 0;

        $display("==========================================================");
        $display(" STARTING BAUGH-WOOLEY RECONFIG MAC VERIFICATION");
        $display("==========================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // Phase 1: 4-bit SIMD Execution
        check_4b(4'sd2, 4'sd3, -4'sd3, 4'sd4, 4'sd5, -4'sd2, -4'sd4, -4'sd3, 1, "4b-Init");
        check_4b(4'sd2, 4'sd2, 4'sd1, 4'sd4, -4'sd5, 4'sd1, 4'sd3, 4'sd2, 0, "4b-Accum-1");
        check_4b(-4'sd8, 4'sd7, -4'sd8, 4'sd7, 4'sd7, 4'sd5, 4'sd7, 4'sd7, 0, "4b-Accum-2");

        for (int i = 0; i < 15; i++) begin
            check_4b($urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                     $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                     $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                     $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                     (i % 5 == 0), $sformatf("4b-Rand-%0d", i));
        end

        // Phase 2: 8-bit Unified Mode Execution
        check_8b(8'sd25, 8'sd10, 1, "8b-Init");
        check_8b(8'sd100, -8'sd25, 0, "8b-Accum-1");
        check_8b(-8'sd50, -8'sd20, 0, "8b-Accum-2");
        check_8b(8'sd127, -8'sd128, 0, "8b-Accum-3");

        for (int i = 0; i < 15; i++) begin
            check_8b($urandom_range(0, 255) - 128, $urandom_range(0, 255) - 128,
                     (i % 5 == 0), $sformatf("8b-Rand-%0d", i));
        end

        // Phase 3: Dynamic Interleaved Switching (Mode 0 <-> Mode 1 every cycle)
        for (int i = 0; i < 12; i++) begin
            if (i % 2 == 0) begin
                check_4b($urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                         $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                         $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                         $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                         1, $sformatf("Interleave-4b-%0d", i));
            end else begin
                check_8b($urandom_range(0, 255) - 128, $urandom_range(0, 255) - 128,
                         1, $sformatf("Interleave-8b-%0d", i));
            end
        end

        $display("==========================================================");
        $display(" VERIFICATION SUMMARY: Tests=%0d, PASSED=%0d, FAILED=%0d", test_count, pass_count, fail_count);
        $display("==========================================================");

        if (fail_count == 0) begin
            $display(">>> ALL TESTS PASSED SUCCESSFULLY! 100%% EXACT NUMERICAL MATCH <<<");
        end else begin
            $display(">>> SOME TESTS FAILED! CHECK OUTPUT ABOVE <<<");
        end

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
