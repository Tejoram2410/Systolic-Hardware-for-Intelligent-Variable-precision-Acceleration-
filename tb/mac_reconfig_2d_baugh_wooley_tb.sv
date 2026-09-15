//-----------------------------------------------------------------------------
// Module: mac_reconfig_2d_baugh_wooley_tb.sv
// Description: Comprehensive Self-Checking Testbench for mac_reconfig_2d_baugh_wooley
//              Verifies all 4 modes:
//                - Mode 00: Quad 4x4 Signed SIMD (4 parallel MACs)
//                - Mode 01: Dual 8x4 Horizontal Signed Fusion (2 parallel MACs)
//                - Mode 10: Dual 4x8 Vertical Signed Fusion (2 parallel MACs)
//                - Mode 11: Unified 8x8 Signed Fusion (1 fused 32-bit MAC)
//                - Phase 5: Dynamic Cycle-by-Cycle Interleaved Mode Switching
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_2d_baugh_wooley_tb;
    localparam time CLK_PERIOD = 10ns;

    logic              clk, rst_n, valid_in, clr_acc;
    logic [1:0]        mode_2b;
    logic signed [3:0] A0, B0, A1, B1, A2, B2, A3, B3;
    logic              valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [23:0] acc_row0, acc_row1;
    logic signed [23:0] acc_col0, acc_col1;
    logic signed [31:0] acc_32b;

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // Reference Models
    longint ref_acc_00 = 0, ref_acc_01 = 0, ref_acc_10 = 0, ref_acc_11 = 0;
    longint ref_acc_row0 = 0, ref_acc_row1 = 0;
    longint ref_acc_col0 = 0, ref_acc_col1 = 0;
    longint ref_acc_32b = 0;

    mac_reconfig_2d_baugh_wooley dut (
        .clk(clk), .rst_n(rst_n), .mode_2b(mode_2b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A0(A0), .B0(B0), .A1(A1), .B1(B1),
        .A2(A2), .B2(B2), .A3(A3), .B3(B3),
        .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01), .acc_10(acc_10), .acc_11(acc_11),
        .acc_row0(acc_row0), .acc_row1(acc_row1),
        .acc_col0(acc_col0), .acc_col1(acc_col1),
        .acc_32b(acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    //-------------------------------------------------------------------------
    // Task: Check Mode 00 (Quad 4x4 SIMD)
    //-------------------------------------------------------------------------
    task automatic check_4x4(
        input logic signed [3:0] a0, b0, a1, b1, a2, b2, a3, b3,
        input logic do_clr,
        input string test_name
    );
        longint p0, p1, p2, p3;
        p0 = $signed(a0) * $signed(b0);
        p1 = $signed(a1) * $signed(b1);
        p2 = $signed(a2) * $signed(b2);
        p3 = $signed(a3) * $signed(b3);

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
        mode_2b  = 2'b00;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A0 = a0; B0 = b0;
        A1 = a1; B1 = b1;
        A2 = a2; B2 = b2;
        A3 = a3; B3 = b3;

        @(posedge clk);
        #1;
        test_count++;
        if (acc_00 === ref_acc_00[15:0] && acc_01 === ref_acc_01[15:0] &&
            acc_10 === ref_acc_10[15:0] && acc_11 === ref_acc_11[15:0]) begin
            pass_count++;
            $display("[PASS] Mode 00 (Quad 4x4): %s | ACCs=[%0d, %0d, %0d, %0d]", test_name, acc_00, acc_01, acc_10, acc_11);
        end else begin
            fail_count++;
            $display("[FAIL] Mode 00 (Quad 4x4): %s | Got {%0d, %0d, %0d, %0d} Exp {%0d, %0d, %0d, %0d}",
                     test_name, acc_00, acc_01, acc_10, acc_11,
                     ref_acc_00[15:0], ref_acc_01[15:0], ref_acc_10[15:0], ref_acc_11[15:0]);
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    //-------------------------------------------------------------------------
    // Task: Check Mode 01 (Dual 8x4 Horizontal Fusion)
    // Row 0: A0_8b * B0_4b  | Row 1: A1_8b * B1_4b
    //-------------------------------------------------------------------------
    task automatic check_8x4(
        input logic signed [7:0] a0_8b,
        input logic signed [3:0] b0_4b,
        input logic signed [7:0] a1_8b,
        input logic signed [3:0] b1_4b,
        input logic do_clr,
        input string test_name
    );
        longint p_r0, p_r1;
        p_r0 = $signed(a0_8b) * $signed(b0_4b);
        p_r1 = $signed(a1_8b) * $signed(b1_4b);

        if (do_clr) begin
            ref_acc_row0 = p_r0;
            ref_acc_row1 = p_r1;
        end else begin
            ref_acc_row0 += p_r0;
            ref_acc_row1 += p_r1;
        end

        @(negedge clk);
        mode_2b  = 2'b01;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        // Swizzling: PE00=(A0_lo, B0), PE01=(A0_hi, B0), PE10=(A1_lo, B1), PE11=(A1_hi, B1)
        A0 = a0_8b[3:0]; B0 = b0_4b;
        A1 = a0_8b[7:4]; B1 = b0_4b;
        A2 = a1_8b[3:0]; B2 = b1_4b;
        A3 = a1_8b[7:4]; B3 = b1_4b;

        @(posedge clk);
        #1;
        test_count++;
        if (acc_row0 === ref_acc_row0[23:0] && acc_row1 === ref_acc_row1[23:0]) begin
            pass_count++;
            $display("[PASS] Mode 01 (Dual 8x4): %s | Row0=%0d, Row1=%0d", test_name, acc_row0, acc_row1);
        end else begin
            fail_count++;
            $display("[FAIL] Mode 01 (Dual 8x4): %s | Got {%0d, %0d} Exp {%0d, %0d}",
                     test_name, acc_row0, acc_row1, ref_acc_row0[23:0], ref_acc_row1[23:0]);
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    //-------------------------------------------------------------------------
    // Task: Check Mode 10 (Dual 4x8 Vertical Fusion)
    // Col 0: A0_4b * B0_8b  | Col 1: A1_4b * B1_8b
    //-------------------------------------------------------------------------
    task automatic check_4x8(
        input logic signed [3:0] a0_4b,
        input logic signed [7:0] b0_8b,
        input logic signed [3:0] a1_4b,
        input logic signed [7:0] b1_8b,
        input logic do_clr,
        input string test_name
    );
        longint p_c0, p_c1;
        p_c0 = $signed(a0_4b) * $signed(b0_8b);
        p_c1 = $signed(a1_4b) * $signed(b1_8b);

        if (do_clr) begin
            ref_acc_col0 = p_c0;
            ref_acc_col1 = p_c1;
        end else begin
            ref_acc_col0 += p_c0;
            ref_acc_col1 += p_c1;
        end

        @(negedge clk);
        mode_2b  = 2'b10;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        // Swizzling: PE00=(A0, B0_lo), PE10=(A0, B0_hi), PE01=(A1, B1_lo), PE11=(A1, B1_hi)
        A0 = a0_4b; B0 = b0_8b[3:0];
        A2 = a0_4b; B2 = b0_8b[7:4];
        A1 = a1_4b; B1 = b1_8b[3:0];
        A3 = a1_4b; B3 = b1_8b[7:4];

        @(posedge clk);
        #1;
        test_count++;
        if (acc_col0 === ref_acc_col0[23:0] && acc_col1 === ref_acc_col1[23:0]) begin
            pass_count++;
            $display("[PASS] Mode 10 (Dual 4x8): %s | Col0=%0d, Col1=%0d", test_name, acc_col0, acc_col1);
        end else begin
            fail_count++;
            $display("[FAIL] Mode 10 (Dual 4x8): %s | Got {%0d, %0d} Exp {%0d, %0d}",
                     test_name, acc_col0, acc_col1, ref_acc_col0[23:0], ref_acc_col1[23:0]);
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    //-------------------------------------------------------------------------
    // Task: Check Mode 11 (Unified 8x8 Fusion)
    // A_8b * B_8b
    //-------------------------------------------------------------------------
    task automatic check_8x8(
        input logic signed [7:0] a8,
        input logic signed [7:0] b8,
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
        mode_2b  = 2'b11;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        // Swizzling: PE00=(A_lo,B_lo), PE01=(A_hi,B_lo), PE10=(A_lo,B_hi), PE11=(A_hi,B_hi)
        A0 = a8[3:0]; B0 = b8[3:0];
        A1 = a8[7:4]; B1 = b8[3:0];
        A2 = a8[3:0]; B2 = b8[7:4];
        A3 = a8[7:4]; B3 = b8[7:4];

        @(posedge clk);
        #1;
        test_count++;
        if (acc_32b === ref_acc_32b[31:0]) begin
            pass_count++;
            $display("[PASS] Mode 11 (Unified 8x8): %s | A=%4d, B=%4d -> ACC_32B=%10d", test_name, a8, b8, acc_32b);
        end else begin
            fail_count++;
            $display("[FAIL] Mode 11 (Unified 8x8): %s | A=%0d, B=%0d -> Got ACC_32B=%0d, Exp=%0d",
                     test_name, a8, b8, acc_32b, ref_acc_32b[31:0]);
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    //-------------------------------------------------------------------------
    // Main Verification Process
    //-------------------------------------------------------------------------
    initial begin
        $dumpfile("mac_reconfig_2d_baugh_wooley_tb.vcd");
        $dumpvars(0, mac_reconfig_2d_baugh_wooley_tb.dut);

        clk = 0; rst_n = 0; mode_2b = 0; valid_in = 0; clr_acc = 0;
        A0 = 0; B0 = 0; A1 = 0; B1 = 0;
        A2 = 0; B2 = 0; A3 = 0; B3 = 0;

        $display("==========================================================================");
        $display(" STARTING 2D ARBITRARY RECONFIGURABLE MAC VERIFICATION (MODES 00, 01, 10, 11)");
        $display("==========================================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        //---------------------------------------------------------------------
        // Phase 1: Mode 00 (Quad 4x4 Signed SIMD)
        //---------------------------------------------------------------------
        $display("\n--- PHASE 1: Mode 00 (Quad 4x4 Signed SIMD) ---");
        check_4x4(4'sd2, 4'sd3, -4'sd3, 4'sd4, 4'sd5, -4'sd2, -4'sd4, -4'sd3, 1, "4x4-Init");
        check_4x4(4'sd2, 4'sd2, 4'sd1, 4'sd4, -4'sd5, 4'sd1, 4'sd3, 4'sd2, 0, "4x4-Accum-1");
        check_4x4(-4'sd8, 4'sd7, -4'sd8, 4'sd7, 4'sd7, 4'sd5, 4'sd7, 4'sd7, 0, "4x4-Accum-2");

        for (int i = 0; i < 10; i++) begin
            check_4x4($urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                      $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                      $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                      $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                      (i % 4 == 0), $sformatf("4x4-Rand-%0d", i));
        end

        //---------------------------------------------------------------------
        // Phase 2: Mode 01 (Dual 8x4 Horizontal Fusion)
        //---------------------------------------------------------------------
        $display("\n--- PHASE 2: Mode 01 (Dual 8x4 Horizontal Fusion) ---");
        check_8x4(8'sd50, 4'sd3, -8'sd85, -4'sd5, 1, "8x4-Init");
        check_8x4(8'sd120, -4'sd7, -8'sd128, 4'sd7, 0, "8x4-Accum-1");
        check_8x4(-8'sd100, 4'sd5, 8'sd64, -4'sd8, 0, "8x4-Accum-2");

        for (int i = 0; i < 10; i++) begin
            check_8x4($urandom_range(0, 255) - 128, $urandom_range(0, 15) - 8,
                      $urandom_range(0, 255) - 128, $urandom_range(0, 15) - 8,
                      (i % 4 == 0), $sformatf("8x4-Rand-%0d", i));
        end

        //---------------------------------------------------------------------
        // Phase 3: Mode 10 (Dual 4x8 Vertical Fusion)
        //---------------------------------------------------------------------
        $display("\n--- PHASE 3: Mode 10 (Dual 4x8 Vertical Fusion) ---");
        check_4x8(4'sd3, 8'sd50, -4'sd5, -8'sd85, 1, "4x8-Init");
        check_4x8(-4'sd7, 8'sd120, 4'sd7, -8'sd128, 0, "4x8-Accum-1");
        check_4x8(4'sd5, -8'sd100, -4'sd8, 8'sd64, 0, "4x8-Accum-2");

        for (int i = 0; i < 10; i++) begin
            check_4x8($urandom_range(0, 15) - 8, $urandom_range(0, 255) - 128,
                      $urandom_range(0, 15) - 8, $urandom_range(0, 255) - 128,
                      (i % 4 == 0), $sformatf("4x8-Rand-%0d", i));
        end

        //---------------------------------------------------------------------
        // Phase 4: Mode 11 (Unified 8x8 Fusion)
        //---------------------------------------------------------------------
        $display("\n--- PHASE 4: Mode 11 (Unified 8x8 Fusion) ---");
        check_8x8(8'sd25, 8'sd10, 1, "8x8-Init");
        check_8x8(8'sd100, -8'sd25, 0, "8x8-Accum-1");
        check_8x8(-8'sd50, -8'sd20, 0, "8x8-Accum-2");
        check_8x8(8'sd127, -8'sd128, 0, "8x8-Accum-3");

        for (int i = 0; i < 10; i++) begin
            check_8x8($urandom_range(0, 255) - 128, $urandom_range(0, 255) - 128,
                      (i % 4 == 0), $sformatf("8x8-Rand-%0d", i));
        end

        //---------------------------------------------------------------------
        // Phase 5: Dynamic Cycle-by-Cycle Interleaved Mode Switching
        //---------------------------------------------------------------------
        $display("\n--- PHASE 5: Dynamic Interleaved Mode Switching (00 <-> 01 <-> 10 <-> 11) ---");
        for (int i = 0; i < 16; i++) begin
            case (i % 4)
                0: check_4x4($urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                             $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                             $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                             $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                             1, $sformatf("Dynamic-4x4-%0d", i));
                1: check_8x4($urandom_range(0, 255) - 128, $urandom_range(0, 15) - 8,
                             $urandom_range(0, 255) - 128, $urandom_range(0, 15) - 8,
                             1, $sformatf("Dynamic-8x4-%0d", i));
                2: check_4x8($urandom_range(0, 15) - 8, $urandom_range(0, 255) - 128,
                             $urandom_range(0, 15) - 8, $urandom_range(0, 255) - 128,
                             1, $sformatf("Dynamic-4x8-%0d", i));
                3: check_8x8($urandom_range(0, 255) - 128, $urandom_range(0, 255) - 128,
                             1, $sformatf("Dynamic-8x8-%0d", i));
            endcase
        end

        $display("\n==========================================================================");
        $display(" 2D RECONFIG MAC VERIFICATION SUMMARY: Tests=%0d, PASSED=%0d, FAILED=%0d", test_count, pass_count, fail_count);
        $display("==========================================================================");

        if (fail_count == 0) begin
            $display(">>> ALL TESTS PASSED SUCCESSFULLY! 100%% EXACT NUMERICAL MATCH ACROSS ALL 4 MODES <<<");
        end else begin
            $display(">>> SOME TESTS FAILED! CHECK OUTPUT ABOVE <<<");
        end

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
