//-----------------------------------------------------------------------------
// Module: mac_radix4_dadda_tb.sv
// Description: Industry-Grade Self-Checking Testbench for Radix-4 Dadda MAC Unit
// Tests:
//   1. Directed Corner-Case Verification (Zero, Max Pos, Max Neg, Mixed)
//   2. Exhaustive Search over all 256 Signed 4-bit Input Combinations
//   3. Multi-Cycle Accumulation & Clear Control Sequence
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_radix4_dadda_tb;

    localparam time CLK_PERIOD = 10ns;

    // Interface Signals
    logic              clk;
    logic              rst_n;
    logic              valid_in;
    logic              clr_acc;
    logic signed [3:0] A;
    logic signed [3:0] B;
    logic              valid_out;
    logic signed [15:0] ACC;

    // Tracking Metrics
    int test_count  = 0;
    int error_count = 0;
    int pass_count  = 0;

    // Instantiate DUT
    mac_radix4_dadda dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .valid_in (valid_in),
        .clr_acc  (clr_acc),
        .A        (A),
        .B        (B),
        .valid_out(valid_out),
        .ACC      (ACC)
    );

    // Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Reference Model Accumulator Variable
    longint ref_acc = 0;

    // Task for driving MAC operation and asserting against Golden Reference Model
    task automatic execute_mac(
        input logic signed [3:0] in_a,
        input logic signed [3:0] in_b,
        input logic              do_clr,
        input string             test_name
    );
        longint expected_prod;
        longint expected_acc;

        expected_prod = $signed(in_a) * $signed(in_b);
        if (do_clr) begin
            ref_acc = expected_prod;
        end else begin
            ref_acc = ref_acc + expected_prod;
        end
        expected_acc = ref_acc;

        // Drive inputs on negedge clock for setup safety
        @(negedge clk);
        valid_in = 1'b1;
        clr_acc  = do_clr;
        A        = in_a;
        B        = in_b;

        // Wait for clock edge and pipeline update
        @(posedge clk);
        #1; // Sample output after register propagation

        test_count++;
        if (ACC !== expected_acc[15:0]) begin
            $display("[FAIL] %s | A=%0d, B=%0d, clr=%b | Got ACC=%0d (0x%0h) | Expected ACC=%0d (0x%0h)",
                     test_name, in_a, in_b, do_clr, ACC, ACC, expected_acc[15:0], expected_acc[15:0]);
            error_count++;
        end else begin
            $display("[PASS] %s | A=%0d, B=%0d, clr=%b | ACC=%0d",
                     test_name, in_a, in_b, do_clr, ACC);
            pass_count++;
        end

        @(negedge clk);
        valid_in = 1'b0;
    endtask

    // Main Test Stimulus
    initial begin
        clk      = 0;
        rst_n    = 0;
        valid_in = 0;
        clr_acc  = 0;
        A        = 0;
        B        = 0;

        $display("==========================================================");
        $display("   STARTING RADIX-4 DADDA MAC UNIT VERIFICATION TESTBENCH ");
        $display("==========================================================");

        // Phase 1: Reset Release
        #(CLK_PERIOD * 2);
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        if (ACC === 16'sd0 && valid_out === 1'b0) begin
            $display("[PASS] Phase 1: Reset Initialization Successful");
        end else begin
            $display("[FAIL] Phase 1: Reset Initialization Failed");
            error_count++;
        end

        // Phase 2: Directed Corner-Case Tests
        $display("\n--- PHASE 2: DIRECTED CORNER-CASE TESTS ---");
        execute_mac(4'sd0,  4'sd0,  1'b1, "Test 2.1: Zero Multiplication (0 * 0)");
        execute_mac(4'sd7,  4'sd7,  1'b1, "Test 2.2: Max Pos Multiplication (7 * 7)");
        execute_mac(-4'sd8, -4'sd8, 1'b1, "Test 2.3: Max Neg Multiplication (-8 * -8)");
        execute_mac(-4'sd8, 4'sd7,  1'b1, "Test 2.4: Asymmetric Multiplication (-8 * 7)");
        execute_mac(4'sd5, -4'sd3,  1'b1, "Test 2.5: Mixed Sign Multiplication (5 * -3)");

        // Phase 3: Multi-Cycle Accumulation
        $display("\n--- PHASE 3: MULTI-CYCLE ACCUMULATION TEST ---");
        execute_mac(4'sd3,  4'sd4,  1'b1, "Test 3.1: Accumulator Load (3 * 4 = 12)");
        execute_mac(4'sd2,  4'sd5,  1'b0, "Test 3.2: Accumulate (+2 * 5 = +10 -> 22)");
        execute_mac(-4'sd4, 4'sd2,  1'b0, "Test 3.3: Accumulate (+-4 * 2 = -8 -> 14)");
        execute_mac(-4'sd8, -4'sd2, 1'b0, "Test 3.4: Accumulate (+-8 * -2 = +16 -> 30)");

        // Phase 4: Exhaustive Verification of All 256 Input Combinations
        $display("\n--- PHASE 4: EXHAUSTIVE 256 INPUT COMBINATIONS TEST ---");
        for (int i = -8; i <= 7; i++) begin
            for (int j = -8; j <= 7; j++) begin
                execute_mac(i[3:0], j[3:0], (i == -8 && j == -8) ? 1'b1 : 1'b0, 
                            $sformatf("Exhaustive A=%0d B=%0d", i, j));
            end
        end

        // Final Summary Report
        $display("\n==========================================================");
        $display("               MAC SIMULATION RESULTS SUMMARY             ");
        $display("==========================================================");
        $display(" Total Test Vectors : %0d", test_count);
        $display(" Passed Assertions  : %0d", pass_count);
        $display(" Failed Assertions  : %0d", error_count);
        if (error_count == 0) begin
            $display(" STATUS: SIMULATION PASSED SUCCESSFUL ");
        end else begin
            $display(" STATUS: SIMULATION FAILED WITH %0d ERRORS ", error_count);
        end
        $display("==========================================================\n");

        $finish;
    end

endmodule
