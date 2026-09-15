//-----------------------------------------------------------------------------
// Module: mac_reconfig_top_tb.sv
// Description: Comprehensive Self-Checking Testbench for Reconfigurable
//              4-bit / 8-bit MAC Architecture with Accumulator Reuse.
// Tests:
//   1. Reset & Initialization
//   2. Quad 4-bit SIMD Mode Operation & Accumulation
//   3. Unified 8-bit MAC Mode Operation with 32-bit Fused Accumulator Reuse
//   4. Corner Case 8-bit Signed Multiplications (-128 to +127)
//   5. Dynamic Mode Switching (4-bit -> 8-bit -> 4-bit runtime re-configuration)
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_top_tb;

    localparam time CLK_PERIOD = 10ns;

    // Interface Signals
    logic              clk;
    logic              rst_n;
    logic              mode_8b;
    logic              valid_in;
    logic              clr_acc;

    // 4-bit Mode Inputs
    logic signed [3:0] A_4b_00, B_4b_00;
    logic signed [3:0] A_4b_01, B_4b_01;
    logic signed [3:0] A_4b_10, B_4b_10;
    logic signed [3:0] A_4b_11, B_4b_11;

    // 8-bit Mode Inputs
    logic signed [7:0] A_8b, B_8b;

    // Outputs
    logic              valid_out;
    logic signed [15:0] acc_00;
    logic signed [15:0] acc_01;
    logic signed [15:0] acc_10;
    logic signed [15:0] acc_11;
    logic signed [31:0] acc_32b;

    // Metrics
    int test_count  = 0;
    int pass_count  = 0;
    int error_count = 0;

    // Golden Reference Model Accumulators
    longint ref_acc_00 = 0;
    longint ref_acc_01 = 0;
    longint ref_acc_10 = 0;
    longint ref_acc_11 = 0;
    longint ref_acc_32b = 0;

    // Instantiate DUT
    mac_reconfig_top dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .mode_8b   (mode_8b),
        .valid_in  (valid_in),
        .clr_acc   (clr_acc),
        .A_4b_00   (A_4b_00),
        .B_4b_00   (B_4b_00),
        .A_4b_01   (A_4b_01),
        .B_4b_01   (B_4b_01),
        .A_4b_10   (A_4b_10),
        .B_4b_10   (B_4b_10),
        .A_4b_11   (A_4b_11),
        .B_4b_11   (B_4b_11),
        .A_8b      (A_8b),
        .B_8b      (B_8b),
        .valid_out (valid_out),
        .acc_00    (acc_00),
        .acc_01    (acc_01),
        .acc_10    (acc_10),
        .acc_11    (acc_11),
        .acc_32b   (acc_32b)
    );

    // Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper task to clear inputs
    task automatic clear_inputs();
        valid_in = 0;
        clr_acc  = 0;
        A_4b_00  = 0; B_4b_00 = 0;
        A_4b_01  = 0; B_4b_01 = 0;
        A_4b_10  = 0; B_4b_10 = 0;
        A_4b_11  = 0; B_4b_11 = 0;
        A_8b     = 0; B_8b    = 0;
    endtask

    // Task for 4-bit SIMD MAC execution & golden assertion
    task automatic execute_mac_4b(
        input logic signed [3:0] a0, b0,
        input logic signed [3:0] a1, b1,
        input logic signed [3:0] a2, b2,
        input logic signed [3:0] a3, b3,
        input logic              do_clr,
        input string             test_name
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
            ref_acc_00 = ref_acc_00 + p0;
            ref_acc_01 = ref_acc_01 + p1;
            ref_acc_10 = ref_acc_10 + p2;
            ref_acc_11 = ref_acc_11 + p3;
        end

        @(negedge clk);
        mode_8b  = 1'b0;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A_4b_00  = a0; B_4b_00 = b0;
        A_4b_01  = a1; B_4b_01 = b1;
        A_4b_10  = a2; B_4b_10 = b2;
        A_4b_11  = a3; B_4b_11 = b3;

        @(posedge clk);
        #1;
        test_count++;
        if (acc_00 === ref_acc_00[15:0] && acc_01 === ref_acc_01[15:0] &&
            acc_10 === ref_acc_10[15:0] && acc_11 === ref_acc_11[15:0]) begin
            $display("[PASS] 4-bit SIMD: %s | ACCs=[%0d, %0d, %0d, %0d]", test_name, acc_00, acc_01, acc_10, acc_11);
            pass_count++;
        end else begin
            $display("[FAIL] 4-bit SIMD: %s | Got ACCs=[%0d, %0d, %0d, %0d] | Expected=[%0d, %0d, %0d, %0d]",
                     test_name, acc_00, acc_01, acc_10, acc_11,
                     ref_acc_00[15:0], ref_acc_01[15:0], ref_acc_10[15:0], ref_acc_11[15:0]);
            error_count++;
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    // Task for 8-bit Unified MAC execution & golden assertion
    task automatic execute_mac_8b(
        input logic signed [7:0] a_val,
        input logic signed [7:0] b_val,
        input logic              do_clr,
        input string             test_name
    );
        longint prod;
        prod = $signed(a_val) * $signed(b_val);

        if (do_clr) begin
            ref_acc_32b = prod;
        end else begin
            ref_acc_32b = ref_acc_32b + prod;
        end

        @(negedge clk);
        mode_8b  = 1'b1;
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A_8b     = a_val;
        B_8b     = b_val;

        @(posedge clk);
        #1;
        test_count++;
        if (acc_32b === ref_acc_32b[31:0]) begin
            $display("[PASS] 8-bit Unified: %s | A=%0d, B=%0d | 32b-ACC=%0d (0x%0h)",
                     test_name, a_val, b_val, acc_32b, acc_32b);
            pass_count++;
        end else begin
            $display("[FAIL] 8-bit Unified: %s | A=%0d, B=%0d | Got 32b-ACC=%0d (0x%0h) | Expected=%0d (0x%0h)",
                     test_name, a_val, b_val, acc_32b, acc_32b, ref_acc_32b[31:0], ref_acc_32b[31:0]);
            error_count++;
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    // Main Test Stimulus
    initial begin
        clk     = 0;
        rst_n   = 0;
        mode_8b = 0;
        clear_inputs();

        $display("==========================================================");
        $display("  STARTING RECONFIGURABLE 4-BIT/8-BIT MAC VERIFICATION   ");
        $display("==========================================================");

        // Phase 1: Reset Release
        #(CLK_PERIOD * 2);
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        if (acc_00 === 16'sd0 && acc_32b === 32'sd0) begin
            $display("[PASS] Phase 1: Reset Release Successful");
        end else begin
            $display("[FAIL] Phase 1: Reset Failed");
            error_count++;
        end

        // Phase 2: Quad 4-bit SIMD Mode Tests
        $display("\n--- PHASE 2: QUAD 4-BIT SIMD MODE TESTS ---");
        execute_mac_4b(4'sd3, 4'sd4, 4'sd2, 4'sd5, -4'sd4, 4'sd2, -4'sd8, -4'sd2, 1'b1, "Phase 2.1: 4-bit Multi-PE Parallel Load");
        execute_mac_4b(4'sd1, 4'sd1, 4'sd1, 4'sd1, 4'sd1, 4'sd1, 4'sd1, 4'sd1, 1'b0, "Phase 2.2: 4-bit Multi-PE Accumulate (+1)");
        execute_mac_4b(-4'sd8, 4'sd7, 4'sd7, -4'sd8, -4'sd8, -4'sd8, 4'sd7, 4'sd7, 1'b1, "Phase 2.3: 4-bit Signed Corner Cases");

        // Phase 3: Unified 8-bit Mode Tests (with Accumulator Reuse)
        $display("\n--- PHASE 3: UNIFIED 8-BIT MODE TESTS (32-BIT ACC REUSE) ---");
        execute_mac_8b(8'sd0, 8'sd0, 1'b1, "Phase 3.1: Zero Multiplication (0 * 0)");
        execute_mac_8b(8'sd127, 8'sd127, 1'b1, "Phase 3.2: Max Pos Multiplication (127 * 127 = 16129)");
        execute_mac_8b(-8'sd128, -8'sd128, 1'b1, "Phase 3.3: Max Neg Multiplication (-128 * -128 = 16384)");
        execute_mac_8b(-8'sd128, 8'sd127, 1'b1, "Phase 3.4: Asymmetric Multiplication (-128 * 127 = -16256)");
        execute_mac_8b(8'sd50, -8'sd30, 1'b1, "Phase 3.5: Mixed Signed Multiplication (50 * -30 = -1500)");

        // Phase 4: Multi-Cycle 8-bit Accumulation Test
        $display("\n--- PHASE 4: MULTI-CYCLE 8-BIT ACCUMULATION TEST ---");
        execute_mac_8b(8'sd100, 8'sd100, 1'b1, "Phase 4.1: Load 8-bit ACC (100 * 100 = 10000)");
        execute_mac_8b(8'sd50, 8'sd40, 1'b0, "Phase 4.2: Accumulate (+50 * 40 = +2000 -> 12000)");
        execute_mac_8b(-8'sd100, 8'sd50, 1'b0, "Phase 4.3: Accumulate (-100 * 50 = -5000 -> 7000)");

        // Phase 5: Dynamic Mode Switching (4-bit -> 8-bit -> 4-bit)
        $display("\n--- PHASE 5: DYNAMIC RUNTIME MODE SWITCHING TEST ---");
        execute_mac_4b(4'sd2, 4'sd3, 4'sd4, 4'sd5, 4'sd6, 4'sd7, 4'sd1, 4'sd1, 1'b1, "Phase 5.1: 4-bit Mode Active");
        execute_mac_8b(8'sd75, 8'sd80, 1'b1, "Phase 5.2: Switch to 8-bit Mode (75 * 80 = 6000)");
        execute_mac_4b(4'sd7, 4'sd7, 4'sd7, 4'sd7, 4'sd7, 4'sd7, 4'sd7, 4'sd7, 1'b1, "Phase 5.3: Switch back to 4-bit Mode");

        // Final Summary
        $display("\n==========================================================");
        $display("   RECONFIGURABLE MAC SIMULATION RESULTS SUMMARY ");
        $display("==========================================================");
        $display(" Total Test Assertions : %0d", test_count);
        $display(" Passed Assertions     : %0d", pass_count);
        $display(" Failed Assertions     : %0d", error_count);
        if (error_count == 0) begin
            $display(" STATUS: SIMULATION PASSED SUCCESSFUL ");
        end else begin
            $display(" STATUS: SIMULATION FAILED WITH %0d ERRORS ", error_count);
        end
        $display("==========================================================\n");

        $finish;
    end

endmodule
