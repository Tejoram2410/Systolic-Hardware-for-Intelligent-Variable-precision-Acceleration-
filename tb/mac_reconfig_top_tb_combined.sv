//-----------------------------------------------------------------------------
// Module: mac_reconfig_top_tb_combined.sv
// Description: Dynamic Runtime Reconfiguration & Combined INT4/INT8 Testbench 
//              with Self-Checking Assertions & Gate-Level VCD Activity Dump.
//
// Test Phases:
//   Phase 1: Quad 4-bit SIMD Mode Execution (30 cycles)
//   Phase 2: Dynamic Mode Switch to Unified 8-bit Mode (30 cycles)
//   Phase 3: Dynamic Mode Switch back to Quad 4-bit SIMD Mode (30 cycles)
//   Phase 4: High-Frequency Interleaved Mode Switching (4-bit <-> 8-bit every 2 cycles)
//   Phase 5: Self-Checking Golden Reference Model Verification & Pass/Fail Sign-off
//
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_top_tb_combined;

    localparam time CLK_PERIOD = 10ns; // 100 MHz clock matching Genus constraint

    // Signals
    logic              clk;
    logic              rst_n;
    logic              mode_8b;
    logic              valid_in;
    logic              clr_acc;

    logic signed [3:0] A_4b_00, B_4b_00;
    logic signed [3:0] A_4b_01, B_4b_01;
    logic signed [3:0] A_4b_10, B_4b_10;
    logic signed [3:0] A_4b_11, B_4b_11;
    logic signed [7:0] A_8b, B_8b;

    logic              valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [31:0] acc_32b;

    // Metrics & Golden Reference Tracking
    int test_count  = 0;
    int pass_count  = 0;
    int error_count = 0;

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

    // Helper task for 4-bit SIMD MAC execution & golden assertion
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

    // Helper task for 8-bit Unified MAC execution & golden assertion
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

    // Main Test Sequence
    initial begin
        // Dump VCD for Cadence Gate-Level Activity Propagation
        $dumpfile("mac_reconfig_top_combined_gls.vcd");
        $dumpvars(0, mac_reconfig_top_tb_combined.dut);

        clk      = 0;
        rst_n    = 0;
        mode_8b  = 0;
        valid_in = 0;
        clr_acc  = 0;
        A_4b_00  = 0; B_4b_00 = 0;
        A_4b_01  = 0; B_4b_01 = 0;
        A_4b_10  = 0; B_4b_10 = 0;
        A_4b_11  = 0; B_4b_11 = 0;
        A_8b     = 0; B_8b    = 0;

        $display("==========================================================");
        $display(" STARTING COMBINED INT4/INT8 DYNAMIC SWITCHING VERIFICATION");
        $display("==========================================================");

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // PHASE 1: INT4 SIMD Mode Operations (30 iterations)
        $display("\n--- PHASE 1: QUAD INT4 SIMD MODE COMPUTATIONS ---");
        for (int i = 0; i < 30; i++) begin
            execute_mac_4b(
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                (i % 10 == 0), $sformatf("INT4 Op #%0d", i+1)
            );
        end

        // PHASE 2: Dynamic Runtime Switch to INT8 Unified Mode (30 iterations)
        $display("\n--- PHASE 2: DYNAMIC SWITCH TO INT8 UNIFIED MODE ---");
        for (int i = 0; i < 30; i++) begin
            execute_mac_8b(
                $urandom_range(0, 255) - 128,
                $urandom_range(0, 255) - 128,
                (i % 10 == 0), $sformatf("INT8 Op #%0d", i+1)
            );
        end

        // PHASE 3: Dynamic Runtime Switch back to INT4 SIMD Mode (30 iterations)
        $display("\n--- PHASE 3: DYNAMIC SWITCH BACK TO INT4 SIMD MODE ---");
        for (int i = 0; i < 30; i++) begin
            execute_mac_4b(
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                $urandom_range(0, 15) - 8, $urandom_range(0, 15) - 8,
                (i % 10 == 0), $sformatf("INT4 Return Op #%0d", i+1)
            );
        end

        // PHASE 4: Rapid High-Frequency Interleaved Mode Switching (INT4 <-> INT8 every cycle)
        $display("\n--- PHASE 4: HIGH-FREQUENCY INTERLEAVED MODE SWITCHING ---");
        for (int i = 0; i < 20; i++) begin
            if (i % 2 == 0) begin
                execute_mac_4b(
                    4'sd7, -4'sd8, -4'sd8, 4'sd7,
                    4'sd5, -4'sd6, -4'sd7, 4'sd3,
                    1'b1, $sformatf("Interleaved INT4 Op #%0d", i+1)
                );
            end else begin
                execute_mac_8b(
                    8'sd127, -8'sd128,
                    1'b1, $sformatf("Interleaved INT8 Op #%0d", i+1)
                );
            end
        end

        // Final Verification Summary
        $display("\n==========================================================");
        $display("   COMBINED INT4/INT8 DYNAMIC VERIFICATION RESULTS ");
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
