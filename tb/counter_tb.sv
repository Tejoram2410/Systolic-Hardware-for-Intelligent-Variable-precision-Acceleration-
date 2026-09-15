//-----------------------------------------------------------------------------
// Module: counter_tb.sv
// Description: Self-Checking Testbench for Up/Down Counter
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module counter_tb;

    localparam int WIDTH = 8;
    localparam time CLK_PERIOD = 10ns;

    // DUT Interface Signals
    logic             clk;
    logic             rst_n;
    logic             enable;
    logic             up_down;
    logic             load;
    logic [WIDTH-1:0] load_val;
    logic [WIDTH-1:0] count;
    logic             overflow;
    logic             underflow;

    int error_count = 0;
    int test_count  = 0;

    // Instantiate Design Under Test (DUT)
    counter #(
        .WIDTH(WIDTH)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .enable   (enable),
        .up_down  (up_down),
        .load     (load),
        .load_val (load_val),
        .count    (count),
        .overflow (overflow),
        .underflow(underflow)
    );

    // Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Helper Task for Asserting Expectations
    task automatic check_outputs(
        input logic [WIDTH-1:0] exp_count,
        input logic             exp_ovf,
        input logic             exp_udf,
        input string            test_name
    );
        test_count++;
        #1; // Sample output shortly after clock edge
        if (count !== exp_count || overflow !== exp_ovf || underflow !== exp_udf) begin
            $display("[FAIL] %s @ %0t ps | Got: count=%0d (0x%0h), ovf=%b, udf=%b | Expected: count=%0d (0x%0h), ovf=%b, udf=%b",
                     test_name, $time, count, count, overflow, underflow, exp_count, exp_count, exp_ovf, exp_udf);
            error_count++;
        end else begin
            $display("[PASS] %s @ %0t ps | Count: %0d (0x%0h), Overflow: %b, Underflow: %b",
                     test_name, $time, count, count, overflow, underflow);
        end
    endtask

    // Main Test Stimulus Sequence
    initial begin
        // Initialize Signals
        clk      = 0;
        rst_n    = 0;
        enable   = 0;
        up_down  = 1;
        load     = 0;
        load_val = '0;

        $display("==================================================");
        $display("   STARTING SYSTEMVERILOG COUNTER TESTBENCH       ");
        $display("==================================================");

        // Test 1: Reset Release
        #(CLK_PERIOD * 2);
        @(negedge clk);
        rst_n = 1; // Release reset on negedge clk
        @(posedge clk);
        check_outputs(8'd0, 1'b0, 1'b0, "Test 1: Synchronous Reset Release");

        // Test 2: Up Counting
        @(negedge clk);
        enable  = 1;
        up_down = 1;
        repeat (5) @(posedge clk);
        check_outputs(8'd5, 1'b0, 1'b0, "Test 2: Count Up 5 Cycles");

        // Test 3: Synchronous Load
        @(negedge clk);
        load     = 1;
        load_val = 8'hFA; // 250
        @(posedge clk);
        check_outputs(8'hFA, 1'b0, 1'b0, "Test 3: Synchronous Load 8'hFA");

        @(negedge clk);
        load     = 0;

        // Test 4: Overflow Check
        repeat (5) @(posedge clk); // 251, 252, 253, 254, 255
        check_outputs(8'hFF, 1'b0, 1'b0, "Test 4a: Count to Max (255)");
        
        @(posedge clk); // Wraps to 0, overflow flag set
        check_outputs(8'h00, 1'b1, 1'b0, "Test 4b: Overflow Triggered");

        // Test 5: Down Counting & Underflow
        @(negedge clk);
        up_down = 0;
        @(posedge clk); // Wraps down to 255, underflow flag set
        check_outputs(8'hFF, 1'b0, 1'b1, "Test 5: Underflow Triggered");

        // Test 6: Disable Counter
        @(negedge clk);
        enable = 0;
        repeat (3) @(posedge clk);
        check_outputs(8'hFF, 1'b0, 1'b0, "Test 6: Disable Hold Value");

        // Final Summary Report
        $display("==================================================");
        $display("               SIMULATION RESULTS                 ");
        $display("==================================================");
        $display(" Total Tests Run : %0d", test_count);
        $display(" Errors Found    : %0d", error_count);
        if (error_count == 0) begin
            $display(" STATUS: SIMULATION PASSED SUCCESSFUL ");
        end else begin
            $display(" STATUS: SIMULATION FAILED WITH %0d ERRORS ", error_count);
        end
        $display("==================================================");

        $finish;
    end

// Clean up duplicate displays in parsing by normalizing log filter
endmodule
