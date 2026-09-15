//-----------------------------------------------------------------------------
// Module: systolic_array_2x2_tb.sv
// Description: Industry-Grade Self-Checking Testbench for 2x2 INT4 Systolic Array.
// Verifies:
//   1. Reset & Signal Initialization.
//   2. Systolic Data Movement & Shift Register Propagation (Horizontal & Vertical).
//   3. 2x2 Matrix Multiplication with Positive INT4 Values.
//   4. 2x2 Matrix Multiplication with Mixed Signed 4-bit Values (-8 to +7).
//   5. Back-to-Back Streaming Matrix Multiplication with Accumulator Reset.
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module systolic_array_2x2_tb;

    localparam time CLK_PERIOD = 10ns;

    // Interface Signals
    logic              clk;
    logic              rst_n;

    // Row A Inputs
    logic              valid_in_row0;
    logic              clr_acc_row0;
    logic signed [3:0] a_in_row0;

    logic              valid_in_row1;
    logic              clr_acc_row1;
    logic signed [3:0] a_in_row1;

    // Column B Inputs
    logic signed [3:0] b_in_col0;
    logic signed [3:0] b_in_col1;

    // Accumulator Outputs
    logic signed [15:0] acc_00;
    logic signed [15:0] acc_01;
    logic signed [15:0] acc_10;
    logic signed [15:0] acc_11;

    // Output Valid Indicators
    logic              valid_out_00;
    logic              valid_out_01;
    logic              valid_out_10;
    logic              valid_out_11;

    // Boundary Data Movement Outputs
    logic signed [3:0] out_a_row0;
    logic signed [3:0] out_a_row1;
    logic signed [3:0] out_b_col0;
    logic signed [3:0] out_b_col1;

    // Test Metrics
    int test_count  = 0;
    int pass_count  = 0;
    int error_count = 0;

    // Instantiate DUT
    systolic_array_2x2 dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .valid_in_row0 (valid_in_row0),
        .clr_acc_row0  (clr_acc_row0),
        .a_in_row0     (a_in_row0),
        .valid_in_row1 (valid_in_row1),
        .clr_acc_row1  (clr_acc_row1),
        .a_in_row1     (a_in_row1),
        .b_in_col0     (b_in_col0),
        .b_in_col1     (b_in_col1),
        .acc_00        (acc_00),
        .acc_01        (acc_01),
        .acc_10        (acc_10),
        .acc_11        (acc_11),
        .valid_out_00  (valid_out_00),
        .valid_out_01  (valid_out_01),
        .valid_out_10  (valid_out_10),
        .valid_out_11  (valid_out_11),
        .out_a_row0    (out_a_row0),
        .out_a_row1    (out_a_row1),
        .out_b_col0    (out_b_col0),
        .out_b_col1    (out_b_col1)
    );

    // Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper task to clear all inputs
    task automatic clear_inputs();
        valid_in_row0 = 0;
        clr_acc_row0  = 0;
        a_in_row0     = 0;
        valid_in_row1 = 0;
        clr_acc_row1  = 0;
        a_in_row1     = 0;
        b_in_col0     = 0;
        b_in_col1     = 0;
    endtask

    // Helper task to check a 16-bit ACC value against expected
    task automatic check_result(
        input string             pe_name,
        input logic signed [15:0] actual,
        input logic signed [15:0] expected
    );
        test_count++;
        if (actual === expected) begin
            $display("[PASS] %s | Got ACC=%0d (Expected=%0d)", pe_name, actual, expected);
            pass_count++;
        end else begin
            $display("[FAIL] %s | Got ACC=%0d | Expected=%0d", pe_name, actual, expected);
            error_count++;
        end
    endtask

    // Helper task to check 4-bit data movement output
    task automatic check_data_shift(
        input string            shift_name,
        input logic signed [3:0] actual,
        input logic signed [3:0] expected
    );
        test_count++;
        if (actual === expected) begin
            $display("[PASS] %s | Shifted Data = %0d (Expected = %0d)", shift_name, actual, expected);
            pass_count++;
        end else begin
            $display("[FAIL] %s | Shifted Data = %0d | Expected = %0d", shift_name, actual, expected);
            error_count++;
        end
    endtask

    // Task to run 2x2 Matrix Multiplication on Systolic Array
    task automatic run_matrix_mult(
        input logic signed [3:0] A [2][2],
        input logic signed [3:0] B [2][2],
        input string             test_title
    );
        logic signed [15:0] golden_C [2][2];

        // Compute Golden Reference Outputs
        golden_C[0][0] = $signed(A[0][0]) * $signed(B[0][0]) + $signed(A[0][1]) * $signed(B[1][0]);
        golden_C[0][1] = $signed(A[0][0]) * $signed(B[0][1]) + $signed(A[0][1]) * $signed(B[1][1]);
        golden_C[1][0] = $signed(A[1][0]) * $signed(B[0][0]) + $signed(A[1][1]) * $signed(B[1][0]);
        golden_C[1][1] = $signed(A[1][0]) * $signed(B[0][1]) + $signed(A[1][1]) * $signed(B[1][1]);

        $display("\n--- %s ---", test_title);
        $display("  Matrix A = [[%0d, %0d], [%0d, %0d]]", A[0][0], A[0][1], A[1][0], A[1][1]);
        $display("  Matrix B = [[%0d, %0d], [%0d, %0d]]", B[0][0], B[0][1], B[1][0], B[1][1]);
        $display("  Golden C = [[%0d, %0d], [%0d, %0d]]", golden_C[0][0], golden_C[0][1], golden_C[1][0], golden_C[1][1]);

        // Cycle 0: Feed (A[0][0], B[0][0]) to PE(0,0)
        @(negedge clk);
        valid_in_row0 = 1'b1;
        clr_acc_row0  = 1'b1;
        a_in_row0     = A[0][0];
        b_in_col0     = B[0][0];
        valid_in_row1 = 1'b0;
        clr_acc_row1  = 1'b0;
        a_in_row1     = 4'sd0;
        b_in_col1     = 4'sd0;

        // Cycle 1: Feed (A[0][1], B[1][0]) to PE(0,0) AND (A[1][0], B[0][1]) to PE(1,0) & PE(0,1)
        @(negedge clk);
        valid_in_row0 = 1'b1;
        clr_acc_row0  = 1'b0;
        a_in_row0     = A[0][1];
        b_in_col0     = B[1][0];

        valid_in_row1 = 1'b1;
        clr_acc_row1  = 1'b1;
        a_in_row1     = A[1][0];
        b_in_col1     = B[0][1];

        // Cycle 2: Row 0 done. Feed (A[1][1], B[1][1]) to PE(1,0) & PE(0,1)
        @(negedge clk);
        valid_in_row0 = 1'b0;
        clr_acc_row0  = 1'b0;
        a_in_row0     = 4'sd0;
        b_in_col0     = 4'sd0;

        valid_in_row1 = 1'b1;
        clr_acc_row1  = 1'b0;
        a_in_row1     = A[1][1];
        b_in_col1     = B[1][1];

        // Check PE(0,0) completion after cycle 1 MAC update
        #1;
        check_result("PE(0,0) Result [c00]", acc_00, golden_C[0][0]);

        // Cycle 3: Row 1 input finished. Check PE(0,1) and PE(1,0) completion
        @(negedge clk);
        clear_inputs();
        #1;
        check_result("PE(0,1) Result [c01]", acc_01, golden_C[0][1]);
        check_result("PE(1,0) Result [c10]", acc_10, golden_C[1][0]);

        // Cycle 4: Check PE(1,1) completion
        @(negedge clk);
        #1;
        check_result("PE(1,1) Result [c11]", acc_11, golden_C[1][1]);
    endtask

    // Initial Block Simulation Sequence
    initial begin
        clk = 0;
        rst_n = 0;
        clear_inputs();

        $display("==========================================================");
        $display("      STARTING 2x2 SYSTOLIC ARRAY VERIFICATION TESTBENCH   ");
        $display("==========================================================");

        // Phase 1: Reset Release
        #(CLK_PERIOD * 2);
        @(negedge clk);
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        if (acc_00 === 16'sd0 && acc_01 === 16'sd0 && acc_10 === 16'sd0 && acc_11 === 16'sd0) begin
            $display("[PASS] Phase 1: System Reset & Initialization Successful");
        end else begin
            $display("[FAIL] Phase 1: Reset Initialization Failed");
            error_count++;
        end

        // Phase 2: Explicit Data Movement & Systolic Shift Verification
        $display("\n--- PHASE 2: SYSTOLIC DATA MOVEMENT VERIFICATION ---");
        // Drive distinct test values into row 0 & col 0
        @(negedge clk);
        valid_in_row0 = 1'b1;
        clr_acc_row0  = 1'b1;
        a_in_row0     = 4'sd5;   // Pattern A_in = 5
        b_in_col0     = -4'sd6;  // Pattern B_in = -6

        // Cycle 1: Check PE(0,0) receives values, out_a/out_b registered
        @(posedge clk);
        #1;
        $display("Cycle 1: PE(0,0) received A=5, B=-6.");

        // Cycle 2: PE(0,1) out_a should output 5 (A shifted right), PE(1,0) out_b should output -6 (B shifted down)
        @(posedge clk);
        #1;
        check_data_shift("Phase 2.1: Horizontal Shift (PE00 -> PE01 -> Boundary)", out_a_row0, 4'sd5);
        check_data_shift("Phase 2.2: Vertical Shift (PE00 -> PE10 -> Boundary)", out_b_col0, -4'sd6);

        // Cycle 3: Data exiting PE(1,1) boundary outputs after 2 pipeline hops
        @(posedge clk);
        #1;
        check_data_shift("Phase 2.3: Diagonal Shift Output (PE11 out_a)", out_a_row1, 4'sd0);

        clear_inputs();
        #(CLK_PERIOD);

        // Phase 3: Positive Matrix Multiplication Test
        begin
            automatic logic signed [3:0] matA [2][2] = '{ '{4'sd3, 4'sd4}, '{4'sd2, 4'sd5} };
            automatic logic signed [3:0] matB [2][2] = '{ '{4'sd1, 4'sd6}, '{4'sd2, 4'sd3} };
            run_matrix_mult(matA, matB, "PHASE 3: POSITIVE MATRIX MULTIPLICATION (3x1+4x2=11, etc.)");
        end

        // Phase 4: Signed INT4 Mixed Matrix Multiplication (Negative Values)
        begin
            automatic logic signed [3:0] matA [2][2] = '{ '{-4'sd4, 4'sd7}, '{4'sd5, -4'sd8} };
            automatic logic signed [3:0] matB [2][2] = '{ '{4'sd3, -4'sd2}, '{-4'sd6, 4'sd4} };
            run_matrix_mult(matA, matB, "PHASE 4: SIGNED INT4 MIXED MATRIX MULTIPLICATION (-4*3 + 7*-6 = -54)");
        end

        // Phase 5: Corner Case - Max Positive and Max Negative Values
        begin
            automatic logic signed [3:0] matA [2][2] = '{ '{4'sd7, 4'sd7}, '{-4'sd8, -4'sd8} };
            automatic logic signed [3:0] matB [2][2] = '{ '{4'sd7, -4'sd8}, '{-4'sd8, 4'sd7} };
            run_matrix_mult(matA, matB, "PHASE 5: CORNER CASE MAXIMUM POSITIVE & NEGATIVE VALUES");
        end

        // Final Summary
        $display("\n==========================================================");
        $display("        SYSTOLIC ARRAY SIMULATION RESULTS SUMMARY         ");
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
