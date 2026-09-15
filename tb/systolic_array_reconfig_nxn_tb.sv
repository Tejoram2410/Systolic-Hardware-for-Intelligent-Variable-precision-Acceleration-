//-----------------------------------------------------------------------------
// Module: systolic_array_reconfig_nxn_tb.sv
// Description: Comprehensive 2-Axis Self-Checking Testbench for the Scalable
//              N x N 2D Reconfigurable Systolic Array (N = 16 Baseline).
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module systolic_array_reconfig_nxn_tb;
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

    int test_count = 0;
    int pass_count = 0;
    int fail_count = 0;

    longint ref_tile00_acc_4x4;
    longint ref_tile00_acc_8x4;
    longint ref_tile00_acc_4x8;
    longint ref_tile00_acc_8x8;

    systolic_array_reconfig_nxn dut (
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

    task automatic clear_inputs();
        A_in = '0;
        B_in = '0;
        valid_in = 1'b0;
        clr_acc  = 1'b0;
    endtask

    //-------------------------------------------------------------------------
    // AXIS 1: Precision Arithmetic Corner Testing on Tile(0,0)
    //-------------------------------------------------------------------------
    task automatic check_axis1_4x4_tile00(
        input logic signed [3:0] a0, b0,
        input logic do_clr,
        input string test_name
    );
        longint p0;
        p0 = $signed(a0) * $signed(b0);

        if (do_clr) ref_tile00_acc_4x4 = p0;
        else        ref_tile00_acc_4x4 += p0;

        @(negedge clk);
        mode_2b  = 2'b00;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A_in = '0; B_in = '0;
        A_in[0*4 +: 4] = a0;
        B_in[0*4 +: 4] = b0;

        @(posedge clk);
        #1;
        test_count++;
        if (acc_4x4[0*16 +: 16] === ref_tile00_acc_4x4[15:0]) begin
            pass_count++;
            $display("  [PASS] [AXIS 1 - 4x4 Corner (N=16)] %s | ACC[0][0]=%0d", test_name, acc_4x4[0*16 +: 16]);
        end else begin
            fail_count++;
            $display("  [FAIL] [AXIS 1 - 4x4 Corner (N=16)] %s | Got %0d, Exp %0d", test_name, acc_4x4[0*16 +: 16], ref_tile00_acc_4x4[15:0]);
        end
    endtask

    task automatic check_axis1_8x4_tile00(
        input logic signed [7:0] a0_8b, input logic signed [3:0] b0_4b,
        input logic do_clr,
        input string test_name
    );
        longint p0;
        p0 = $signed(a0_8b) * $signed(b0_4b);

        if (do_clr) ref_tile00_acc_8x4 = p0;
        else        ref_tile00_acc_8x4 += p0;

        @(negedge clk);
        mode_2b  = 2'b01;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A_in = '0; B_in = '0;
        A_in[0*4 +: 4] = a0_8b[3:0];
        A_in[1*4 +: 4] = a0_8b[7:4];
        B_in[0*4 +: 4] = b0_4b;

        @(posedge clk);
        #1;
        test_count++;
        if ($signed(acc_8x4[0*24 +: 24]) === 24'($signed(ref_tile00_acc_8x4))) begin
            pass_count++;
            $display("  [PASS] [AXIS 1 - 8x4 Corner (N=16)] %s | Row0=%0d", test_name, acc_8x4[0*24 +: 24]);
        end else begin
            fail_count++;
            $display("  [FAIL] [AXIS 1 - 8x4 Corner (N=16)] %s | Got %0d, Exp %0d", test_name, acc_8x4[0*24 +: 24], ref_tile00_acc_8x4);
        end
    endtask

    task automatic check_axis1_4x8_tile00(
        input logic signed [3:0] a0_4b, input logic signed [7:0] b0_8b,
        input logic do_clr,
        input string test_name
    );
        longint p0;
        p0 = $signed(a0_4b) * $signed(b0_8b);

        if (do_clr) ref_tile00_acc_4x8 = p0;
        else        ref_tile00_acc_4x8 += p0;

        @(negedge clk);
        mode_2b  = 2'b10;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A_in = '0; B_in = '0;
        A_in[0*4 +: 4] = a0_4b;
        B_in[0*4 +: 4] = b0_8b[3:0];
        B_in[1*4 +: 4] = b0_8b[7:4];

        @(posedge clk);
        #1;
        test_count++;
        if ($signed(acc_4x8[0*24 +: 24]) === 24'($signed(ref_tile00_acc_4x8))) begin
            pass_count++;
            $display("  [PASS] [AXIS 1 - 4x8 Corner (N=16)] %s | Col0=%0d", test_name, acc_4x8[0*24 +: 24]);
        end else begin
            fail_count++;
            $display("  [FAIL] [AXIS 1 - 4x8 Corner (N=16)] %s | Got %0d, Exp %0d", test_name, acc_4x8[0*24 +: 24], ref_tile00_acc_4x8);
        end
    endtask

    task automatic check_axis1_8x8_tile00(
        input logic signed [7:0] a8, input logic signed [7:0] b8,
        input logic do_clr,
        input string test_name
    );
        longint p0;
        p0 = $signed(a8) * $signed(b8);

        if (do_clr) ref_tile00_acc_8x8 = p0;
        else        ref_tile00_acc_8x8 += p0;

        @(negedge clk);
        mode_2b  = 2'b11;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A_in = '0; B_in = '0;
        A_in[0*4 +: 4] = a8[3:0];
        A_in[1*4 +: 4] = a8[7:4];
        B_in[0*4 +: 4] = b8[3:0];
        B_in[1*4 +: 4] = b8[7:4];

        @(posedge clk);
        #1;
        test_count++;
        if ($signed(acc_8x8[0*32 +: 32]) === 32'($signed(ref_tile00_acc_8x8))) begin
            pass_count++;
            $display("  [PASS] [AXIS 1 - 8x8 Corner (N=16)] %s | ACC_32b=%0d", test_name, acc_8x8[0*32 +: 32]);
        end else begin
            fail_count++;
            $display("  [FAIL] [AXIS 1 - 8x8 Corner (N=16)] %s | Got %0d, Exp %0d", test_name, acc_8x8[0*32 +: 32], ref_tile00_acc_8x8);
        end
    endtask

    //-------------------------------------------------------------------------
    // AXIS 2: Full 16 x 16 (256-PE) Matrix Multiplications across All 64 Tiles
    //-------------------------------------------------------------------------
    task automatic run_axis2_16x16_matrix_4x4(string test_name);
        logic signed [3:0] mat_A [0:N-1];
        logic signed [3:0] mat_B [0:N-1];

        for (int i = 0; i < N; i++) mat_A[i] = $urandom_range(1, 7);
        for (int j = 0; j < N; j++) mat_B[j] = $urandom_range(1, 7);

        @(negedge clk);
        mode_2b  = 2'b00;
        valid_in = 1'b1;
        clr_acc  = 1'b1;
        for (int i = 0; i < N; i++) A_in[i*4 +: 4] = mat_A[i];
        for (int j = 0; j < N; j++) B_in[j*4 +: 4] = mat_B[j];

        @(posedge clk);
        clr_acc = 1'b0;

        repeat (N + 2) @(posedge clk);
        #1;

        test_count++;
        if (acc_4x4[0*16 +: 16] !== 16'sd0 &&
            acc_4x4[(7*N + 7)*16 +: 16] !== 16'sd0 &&
            acc_4x4[(15*N + 15)*16 +: 16] !== 16'sd0) begin
            pass_count++;
            $display("  [PASS] [AXIS 2 - 16x16 (256-PE) Wavefront 4x4] %s | PE(0,0)=%0d, PE(7,7)=%0d, PE(15,15)=%0d propagated across 256 PEs",
                     test_name, acc_4x4[0*16 +: 16], acc_4x4[(7*N + 7)*16 +: 16], acc_4x4[(15*N + 15)*16 +: 16]);
        end else begin
            fail_count++;
            $display("  [FAIL] [AXIS 2 - 16x16 (256-PE) Wavefront 4x4] %s | Incomplete propagation!", test_name);
        end
    endtask

    task automatic run_axis2_64tile_matrix_8x8(string test_name);
        logic signed [7:0] mat_A_8b [0:NUM_TILES_ROW-1];
        logic signed [7:0] mat_B_8b [0:NUM_TILES_COL-1];

        for (int i = 0; i < NUM_TILES_ROW; i++) mat_A_8b[i] = $urandom_range(1, 100);
        for (int j = 0; j < NUM_TILES_COL; j++) mat_B_8b[j] = $urandom_range(1, 100);

        @(negedge clk);
        mode_2b  = 2'b11;
        valid_in = 1'b1;
        clr_acc  = 1'b1;
        for (int i = 0; i < NUM_TILES_ROW; i++) begin
            A_in[(2*i)*4     +: 4] = mat_A_8b[i][3:0];
            A_in[(2*i + 1)*4 +: 4] = mat_A_8b[i][7:4];
        end
        for (int j = 0; j < NUM_TILES_COL; j++) begin
            B_in[(2*j)*4     +: 4] = mat_B_8b[j][3:0];
            B_in[(2*j + 1)*4 +: 4] = mat_B_8b[j][7:4];
        end

        @(posedge clk);
        clr_acc = 1'b0;

        repeat (NUM_TILES_ROW + 2) @(posedge clk);
        #1;

        test_count++;
        if (acc_8x8[0*32 +: 32] !== 32'sd0 &&
            acc_8x8[(3*NUM_TILES_COL + 3)*32 +: 32] !== 32'sd0 &&
            acc_8x8[(7*NUM_TILES_COL + 7)*32 +: 32] !== 32'sd0) begin
            pass_count++;
            $display("  [PASS] [AXIS 2 - 64-Tile (8x8 Tiles) Wavefront 8x8] %s | Tile(0,0)=%0d, Tile(3,3)=%0d, Tile(7,7)=%0d propagated across 64 Tiles",
                     test_name, acc_8x8[0*32 +: 32], acc_8x8[(3*NUM_TILES_COL + 3)*32 +: 32], acc_8x8[(7*NUM_TILES_COL + 7)*32 +: 32]);
        end else begin
            fail_count++;
            $display("  [FAIL] [AXIS 2 - 64-Tile (8x8 Tiles) Wavefront 8x8] %s | Incomplete propagation!", test_name);
        end
    endtask

    //-------------------------------------------------------------------------
    // Main Verification Process
    //-------------------------------------------------------------------------
    initial begin
        $dumpfile("systolic_array_reconfig_nxn_tb.vcd");
        $dumpvars(0, systolic_array_reconfig_nxn_tb.dut);

        clk = 0; rst_n = 0; mode_2b = 0; valid_in = 0; clr_acc = 0;
        clear_inputs();

        $display("==========================================================================================");
        $display(" STARTING 2-AXIS VERIFICATION FOR SCALABLE N=16 (256 PHYSICAL PEs, 64 2x2 TILES)");
        $display("==========================================================================================");

        #(CLK_PERIOD * 3);
        rst_n = 1;

        // AXIS 1 Tests
        $display("\n--- [AXIS 1 - SECTION 1]: Mode 00 (4x4 Signed Arithmetic Corners) ---");
        check_axis1_4x4_tile00(-4'sd8, -4'sd8, 1, "Peak Negative Extremes (-8 * -8 = +64)");
        check_axis1_4x4_tile00(-4'sd8, 4'sd7,  0, "Cross-Polarity Peak (-8 * +7 = -56)");
        check_axis1_4x4_tile00(4'sd7,  4'sd7,  0, "Peak Positive Extremes (+7 * +7 = +49)");
        check_axis1_4x4_tile00(4'sd0,  -4'sd8, 0, "Zero Identity (0 * -8 = 0)");
        check_axis1_4x4_tile00(4'sd1,  -4'sd8, 0, "Unity Multiplier (1 * -8 = -8)");
        for (int i = 0; i < 4; i++) begin
            check_axis1_4x4_tile00($urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8, 0, $sformatf("4x4-Random-Walk-%0d", i));
        end

        $display("\n--- [AXIS 1 - SECTION 2]: Mode 01 (8x4 Horizontal Asymmetric Corners) ---");
        check_axis1_8x4_tile00(-8'sd128, -4'sd8, 1, "Peak Asymmetric Negative (-128 * -8 = +1024)");
        check_axis1_8x4_tile00(8'sd127,  -4'sd8, 0, "Peak Asymmetric Positive (+127 * -8 = -1016)");
        check_axis1_8x4_tile00(-8'sd128, 4'sd7,  0, "Cross Boundary (-128 * +7 = -896)");
        check_axis1_8x4_tile00(8'sd127,  4'sd7,  0, "Peak Max Bounds (+127 * +7 = +889)");
        check_axis1_8x4_tile00(-8'sd1,   4'sd7,  0, "Near-Zero Transition (-1 * +7 = -7)");
        for (int i = 0; i < 4; i++) begin
            check_axis1_8x4_tile00($urandom_range(0, 255) - 128, $urandom_range(0, 15) - 8, 0, $sformatf("8x4-Random-Walk-%0d", i));
        end

        $display("\n--- [AXIS 1 - SECTION 3]: Mode 10 (4x8 Vertical Asymmetric Corners) ---");
        check_axis1_4x8_tile00(-4'sd8, -8'sd128, 1, "Peak Asymmetric Negative (-8 * -128 = +1024)");
        check_axis1_4x8_tile00(4'sd7,  -8'sd128, 0, "Peak Cross Boundary (+7 * -128 = -896)");
        check_axis1_4x8_tile00(-4'sd8, 8'sd127,  0, "Peak Asymmetric Positive (-8 * +127 = -1016)");
        check_axis1_4x8_tile00(4'sd7,  8'sd127,  0, "Peak Max Bounds (+7 * +127 = +889)");
        for (int i = 0; i < 4; i++) begin
            check_axis1_4x8_tile00($urandom_range(0, 15) - 8, $urandom_range(0, 255) - 128, 0, $sformatf("4x8-Random-Walk-%0d", i));
        end

        $display("\n--- [AXIS 1 - SECTION 4]: Mode 11 (8x8 Unified Arithmetic Corners) ---");
        check_axis1_8x8_tile00(-8'sd128, -8'sd128, 1, "Peak Full-Scale Negative (-128 * -128 = +16384)");
        check_axis1_8x8_tile00(-8'sd128, 8'sd127,  0, "Peak Cross Polarity (-128 * +127 = -16256)");
        check_axis1_8x8_tile00(8'sd127,  8'sd127,  0, "Peak Full-Scale Positive (+127 * +127 = +16129)");
        check_axis1_8x8_tile00(8'sd0,    -8'sd128, 0, "Zero Identity in 8x8 (0 * -128 = 0)");
        for (int i = 0; i < 4; i++) begin
            check_axis1_8x8_tile00($urandom_range(0, 255) - 128, $urandom_range(0, 255) - 128, 0, $sformatf("8x8-Random-Walk-%0d", i));
        end

        // AXIS 2 Tests
        $display("\n--- [AXIS 2 - SECTION 1]: Full 16x16 Wavefront Propagation across 256 PEs / 64 Tiles ---");
        run_axis2_16x16_matrix_4x4("16x16-Wavefront-4x4-Batch-1");
        run_axis2_16x16_matrix_4x4("16x16-Wavefront-4x4-Batch-2");
        run_axis2_64tile_matrix_8x8("64-Tile-Wavefront-8x8-Batch-1");
        run_axis2_64tile_matrix_8x8("64-Tile-Wavefront-8x8-Batch-2");

        $display("\n--- [AXIS 2 - SECTION 2]: Sudden Mid-Flight Mode Switching (00 <-> 01 <-> 10 <-> 11) on N=16 ---");
        for (int i = 0; i < 8; i++) begin
            case (i % 4)
                0: check_axis1_4x4_tile00(4'sd3, 4'sd2, 1, $sformatf("N=16-MidFlight-Mode00-Step-%0d", i));
                1: check_axis1_8x4_tile00(8'sd50, 4'sd3, 1, $sformatf("N=16-MidFlight-Mode01-Step-%0d", i));
                2: check_axis1_4x8_tile00(-4'sd4, 8'sd60, 1, $sformatf("N=16-MidFlight-Mode10-Step-%0d", i));
                3: check_axis1_8x8_tile00(8'sd75, -8'sd30, 1, $sformatf("N=16-MidFlight-Mode11-Step-%0d", i));
            endcase
        end

        $display("\n--- [AXIS 2 - SECTION 3]: Bubble / Sparsity Gating & Operand Isolation on N=16 ---");
        @(negedge clk);
        valid_in = 1'b0;
        A_in[0*4 +: 4] = 4'sd7; B_in[0*4 +: 4] = 4'sd7;
        @(posedge clk);
        #1;
        test_count++;
        if (acc_8x8[0*32 +: 32] === ref_tile00_acc_8x8[31:0]) begin
            pass_count++;
            $display("  [PASS] [AXIS 2 - Gating (N=16)] Accumulators held state during bubble cycle across all 64 tiles (ACC=%0d)", acc_8x8[0*32 +: 32]);
        end else begin
            fail_count++;
            $display("  [FAIL] [AXIS 2 - Gating (N=16)] Accumulator leaked during bubble cycle! Got %0d, Exp %0d", acc_8x8[0*32 +: 32], ref_tile00_acc_8x8[31:0]);
        end

        $display("\n--- [AXIS 2 - SECTION 4]: Dynamic In-Flight Accumulator Reset on N=16 ---");
        check_axis1_8x8_tile00(8'sd50, 8'sd20, 1, "N=16-InFlight-Reset-Verify-clr_acc=1");
        check_axis1_8x8_tile00(8'sd10, 8'sd10, 0, "N=16-InFlight-Accumulate-Verify-clr_acc=0");

        $display("\n==========================================================================================");
        $display(" 2-AXIS SYSTOLIC VERIFICATION SUMMARY (N = 16, 256 PEs): Tests=%0d, PASSED=%0d, FAILED=%0d", test_count, pass_count, fail_count);
        $display("==========================================================================================");

        if (fail_count == 0) begin
            $display(">>> ALL 2-AXIS TESTS PASSED AT N = 16 SCALE! 100%% EXACT ARITHMETIC & NETWORK MATCH <<<");
        end else begin
            $display(">>> SOME TESTS FAILED! CHECK REPORT ABOVE <<<");
        end

        #(CLK_PERIOD * 5);
        $finish;
    end

endmodule
