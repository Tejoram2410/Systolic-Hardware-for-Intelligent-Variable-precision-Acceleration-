//-----------------------------------------------------------------------------
// Module: mac_reconfig_2d_baugh_wooley_comparison_tb.sv
// Description: Dual-DUT Bit-Exact Comparative Verification Testbench.
//              Instantiates Baseline Tile and Optimized Tile side-by-side.
//              Asserts 100% mathematical equivalence across all 4 modes.
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_2d_baugh_wooley_comparison_tb;
    localparam time CLK_PERIOD = 10ns;

    logic        clk, rst_n, valid_in, clr_acc;
    logic [1:0]  mode_2b;
    logic signed [3:0] A0, B0, A1, B1, A2, B2, A3, B3;

    // Baseline Outputs
    logic        base_valid_out;
    logic signed [15:0] base_acc_00, base_acc_01, base_acc_10, base_acc_11;
    logic signed [23:0] base_acc_row0, base_acc_row1;
    logic signed [23:0] base_acc_col0, base_acc_col1;
    logic signed [31:0] base_acc_32b;

    // Optimized Outputs
    logic        opt_valid_out;
    logic signed [15:0] opt_acc_00, opt_acc_01, opt_acc_10, opt_acc_11;
    logic signed [23:0] opt_acc_row0, opt_acc_row1;
    logic signed [23:0] opt_acc_col0, opt_acc_col1;
    logic signed [31:0] opt_acc_32b;

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    // 1. Baseline DUT
    mac_reconfig_2d_baugh_wooley_baseline dut_base (
        .clk(clk), .rst_n(rst_n), .mode_2b(mode_2b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A0(A0), .B0(B0), .A1(A1), .B1(B1), .A2(A2), .B2(B2), .A3(A3), .B3(B3),
        .valid_out(base_valid_out),
        .acc_00(base_acc_00), .acc_01(base_acc_01), .acc_10(base_acc_10), .acc_11(base_acc_11),
        .acc_row0(base_acc_row0), .acc_row1(base_acc_row1),
        .acc_col0(base_acc_col0), .acc_col1(base_acc_col1),
        .acc_32b(base_acc_32b)
    );

    // 2. Optimized DUT
    mac_reconfig_2d_baugh_wooley dut_opt (
        .clk(clk), .rst_n(rst_n), .mode_2b(mode_2b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A0(A0), .B0(B0), .A1(A1), .B1(B1), .A2(A2), .B2(B2), .A3(A3), .B3(B3),
        .valid_out(opt_valid_out),
        .acc_00(opt_acc_00), .acc_01(opt_acc_01), .acc_10(opt_acc_10), .acc_11(opt_acc_11),
        .acc_row0(opt_acc_row0), .acc_row1(opt_acc_row1),
        .acc_col0(opt_acc_col0), .acc_col1(opt_acc_col1),
        .acc_32b(opt_acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task automatic check_cycle(input string test_name);
        @(posedge clk);
        #1;
        test_count++;
        if (opt_acc_00 === base_acc_00 &&
            opt_acc_01 === base_acc_01 &&
            opt_acc_10 === base_acc_10 &&
            opt_acc_11 === base_acc_11 &&
            opt_acc_row0 === base_acc_row0 &&
            opt_acc_row1 === base_acc_row1 &&
            opt_acc_col0 === base_acc_col0 &&
            opt_acc_col1 === base_acc_col1 &&
            opt_acc_32b === base_acc_32b) begin
            pass_count++;
            $display("  [PASS] [DUAL-DUT MATCH] %s | Mode=%b Base_32b=%0d Opt_32b=%0d", test_name, mode_2b, base_acc_32b, opt_acc_32b);
        end else begin
            fail_count++;
            $display("  [FAIL] [MISMATCH DETECTED] %s | Mode=%b Base_32b=%0d Opt_32b=%0d", test_name, mode_2b, base_acc_32b, opt_acc_32b);
            $display("         Base: acc_00=%0d, acc_01=%0d, acc_10=%0d, acc_11=%0d", base_acc_00, base_acc_01, base_acc_10, base_acc_11);
            $display("         Opt : acc_00=%0d, acc_01=%0d, acc_10=%0d, acc_11=%0d", opt_acc_00, opt_acc_01, opt_acc_10, opt_acc_11);
            $display("         Base Row: row0=%0d, row1=%0d | Opt Row: row0=%0d, row1=%0d", base_acc_row0, base_acc_row1, opt_acc_row0, opt_acc_row1);
            $display("         Base Col: col0=%0d, col1=%0d | Opt Col: col0=%0d, col1=%0d", base_acc_col0, base_acc_col1, opt_acc_col0, opt_acc_col1);
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; mode_2b = 0; valid_in = 0; clr_acc = 0;
        A0 = 0; B0 = 0; A1 = 0; B1 = 0; A2 = 0; B2 = 0; A3 = 0; B3 = 0;

        $display("==========================================================================================");
        $display(" STARTING DUAL-DUT BIT-EXACT COMPARISON (BASELINE vs OPTIMIZED TILE)");
        $display("==========================================================================================");

        #(CLK_PERIOD * 3);
        rst_n = 1;

        // SECTION 1: Mode 00 (4x4 SIMD)
        mode_2b = 2'b00; valid_in = 1; clr_acc = 1;
        A0 = -4'sd8; B0 = -4'sd8; A1 = 4'sd7; B1 = 4'sd7; A2 = -4'sd8; B2 = 4'sd7; A3 = 4'sd3; B3 = -4'sd4;
        check_cycle("Mode 00 Peak Extremes (clr=1)");

        clr_acc = 0;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            A0 = $urandom_range(0, 15) - 8; B0 = $urandom_range(0, 15) - 8;
            A1 = $urandom_range(0, 15) - 8; B1 = $urandom_range(0, 15) - 8;
            A2 = $urandom_range(0, 15) - 8; B2 = $urandom_range(0, 15) - 8;
            A3 = $urandom_range(0, 15) - 8; B3 = $urandom_range(0, 15) - 8;
            check_cycle($sformatf("Mode 00 Random Accumulate Step %0d", i));
        end

        // SECTION 2: Mode 01 (8x4 Horizontal Fusion)
        mode_2b = 2'b01; clr_acc = 1;
        A0 = 4'h0; A1 = 4'h8; B0 = -4'sd8; // -128 * -8
        A2 = 4'hF; A3 = 4'h7; B1 = 4'sd7;  // +127 * +7
        check_cycle("Mode 01 Peak Extremes (clr=1)");

        clr_acc = 0;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            A0 = $urandom_range(0, 15); A1 = $urandom_range(0, 15); B0 = $urandom_range(0, 15) - 8;
            A2 = $urandom_range(0, 15); A3 = $urandom_range(0, 15); B1 = $urandom_range(0, 15) - 8;
            check_cycle($sformatf("Mode 01 Random Accumulate Step %0d", i));
        end

        // SECTION 3: Mode 10 (4x8 Vertical Fusion)
        mode_2b = 2'b10; clr_acc = 1;
        A0 = -4'sd8; B0 = 4'h0; B2 = 4'h8; // -8 * -128
        A1 = 4'sd7;  B1 = 4'hF; B3 = 4'h7; // +7 * +127
        check_cycle("Mode 10 Peak Extremes (clr=1)");

        clr_acc = 0;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            A0 = $urandom_range(0, 15) - 8; B0 = $urandom_range(0, 15); B2 = $urandom_range(0, 15);
            A1 = $urandom_range(0, 15) - 8; B1 = $urandom_range(0, 15); B3 = $urandom_range(0, 15);
            check_cycle($sformatf("Mode 10 Random Accumulate Step %0d", i));
        end

        // SECTION 4: Mode 11 (8x8 Unified Fusion)
        mode_2b = 2'b11; clr_acc = 1;
        A0 = 4'h0; A1 = 4'h8; B0 = 4'h0; B2 = 4'h8; // -128 * -128 = +16384
        check_cycle("Mode 11 Peak Extremes (clr=1)");

        clr_acc = 0;
        for (int i = 0; i < 10; i++) begin
            @(negedge clk);
            A0 = $urandom_range(0, 15); A1 = $urandom_range(0, 15);
            B0 = $urandom_range(0, 15); B2 = $urandom_range(0, 15);
            check_cycle($sformatf("Mode 11 Random Accumulate Step %0d", i));
        end

        // SECTION 5: Dynamic Mode Interleaving & Rapid Switching
        for (int i = 0; i < 16; i++) begin
            @(negedge clk);
            mode_2b = i % 4;
            clr_acc = (i % 4 == 0);
            A0 = $urandom_range(0, 15) - 8; B0 = $urandom_range(0, 15) - 8;
            A1 = $urandom_range(0, 15) - 8; B1 = $urandom_range(0, 15) - 8;
            A2 = $urandom_range(0, 15) - 8; B2 = $urandom_range(0, 15) - 8;
            A3 = $urandom_range(0, 15) - 8; B3 = $urandom_range(0, 15) - 8;
            check_cycle($sformatf("MidFlight-ModeSwitching-Step-%0d", i));
        end

        $display("==========================================================================================");
        $display(" DUAL-DUT COMPARISON SUMMARY: Total=%0d, PASSED=%0d, FAILED=%0d", test_count, pass_count, fail_count);
        $display("==========================================================================================");

        if (fail_count == 0) begin
            $display(">>> SUCCESS: OPTIMIZED TILE IS 100%% BIT-EXACT EQUIVALENT TO BASELINE TILE! <<<");
        end else begin
            $display(">>> FAILURE: MISMATCHES DETECTED! <<<");
        end

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
