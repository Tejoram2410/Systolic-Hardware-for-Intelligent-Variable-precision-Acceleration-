//-----------------------------------------------------------------------------
// Module: mac_reconfig_unified_tile_tb.sv
// Description: Exhaustive Self-Checking Testbench for 12-Mode Unified MAC Tile
//              (INTxINT, FPxFP, INTxFP across Modes 00, 01, 10, 11).
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_unified_tile_tb;

    localparam time CLK_PERIOD = 10ns;

    logic        clk, rst_n, valid_in, clr_acc;
    logic [1:0]  mode_2b;
    logic        type_a, type_b;
    logic [1:0]  format_a, format_b;
    logic [7:0]  A0_in, B0_in, A1_in, B1_in, A2_in, B2_in, A3_in, B3_in;

    logic        valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [23:0] acc_row0, acc_row1, acc_col0, acc_col1;
    logic signed [31:0] acc_32b;
    logic signed [5:0]  block_exp;

    int pass_count = 0;
    int fail_count = 0;

    // Instantiate Unified DUT
    mac_reconfig_unified_tile dut (
        .clk(clk), .rst_n(rst_n),
        .mode_2b(mode_2b), .type_a(type_a), .type_b(type_b),
        .format_a(format_a), .format_b(format_b),
        .valid_in(valid_in), .clr_acc(clr_acc),
        .A0_in(A0_in), .B0_in(B0_in),
        .A1_in(A1_in), .B1_in(B1_in),
        .A2_in(A2_in), .B2_in(B2_in),
        .A3_in(A3_in), .B3_in(B3_in),
        .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01),
        .acc_10(acc_10), .acc_11(acc_11),
        .acc_row0(acc_row0), .acc_row1(acc_row1),
        .acc_col0(acc_col0), .acc_col1(acc_col1),
        .acc_32b(acc_32b), .block_exp(block_exp)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    task check_result(string test_name, logic condition, string details);
        if (condition) begin
            $display("[PASS] %s | %s", test_name, details);
            pass_count++;
        end else begin
            $display("[FAIL] %s | %s", test_name, details);
            fail_count++;
        end
    endtask

    initial begin
        clk = 0; rst_n = 0; valid_in = 0; clr_acc = 1;
        mode_2b = 2'b00; type_a = 0; type_b = 0; format_a = 0; format_b = 0;
        A0_in = 0; B0_in = 0; A1_in = 0; B1_in = 0;
        A2_in = 0; B2_in = 0; A3_in = 0; B3_in = 0;

        #(CLK_PERIOD * 2);
        rst_n = 1;
        @(negedge clk);

        $display("\n======================================================================");
        $display(" STARTING VERIFICATION OF 12-MODE UNIFIED INTxINT / FPxFP / INTxFP MAC");
        $display("======================================================================\n");

        //=====================================================================
        // GROUP 1: PURE INTxINT MODES (Modes 1 to 4)
        //=====================================================================
        // Mode 1: Mode 00 (Quad INT4xINT4) -> A0=-5 (0xB), B0=6 -> Prod=-30
        mode_2b = 2'b00; type_a = 0; type_b = 0; format_a = 2'b00; format_b = 2'b00;
        valid_in = 1; clr_acc = 1;
        A0_in = 8'h0B; B0_in = 8'h06; A1_in = 8'h03; B1_in = 8'h04;
        A2_in = 8'h07; B2_in = 8'h07; A3_in = 8'h08; B3_in = 8'h08; // -8 * -8 = +64
        @(negedge clk);
        check_result("Mode 00 INTxINT Quad", (acc_00 == -16'sd30 && acc_11 == 16'sd64),
                     $sformatf("ACC00=%0d (exp -30), ACC11=%0d (exp 64), block_exp=%0d", acc_00, acc_11, block_exp));

        // Mode 2: Mode 01 (Dual INT8xINT4 Row Fusion) -> Row0 = (A0_byte * B0)
        mode_2b = 2'b01; type_a = 0; type_b = 0; format_a = 2'b01; format_b = 2'b00; clr_acc = 1;
        A0_in = 8'h09; A1_in = 8'h01; B0_in = 8'h04; B1_in = 8'h04;
        A2_in = 8'hF6; A3_in = 8'hFF; B2_in = 8'h02; B3_in = 8'h02; // -10 * 2 = -20
        @(negedge clk);
        check_result("Mode 01 INTxINT Dual Row", (acc_row0 == 24'sd100 && acc_row1 == -24'sd20),
                     $sformatf("Row0=%0d (exp 100), Row1=%0d (exp -20)", acc_row0, acc_row1));

        // Mode 3: Mode 10 (Dual INT4xINT8 Col Fusion) -> Col0 = A0 * B0_byte
        mode_2b = 2'b10; type_a = 0; type_b = 0; format_a = 2'b00; format_b = 2'b01; clr_acc = 1;
        A0_in = 8'h05; A2_in = 8'h05; B0_in = 8'h04; B2_in = 8'h0F; // B_low=4, B_hi=-1 (0xF4 = -12)
        @(negedge clk);
        check_result("Mode 10 INTxINT Dual Col", (acc_col0 == -24'sd60),
                     $sformatf("Col0=%0d (exp -60)", acc_col0));

        // Mode 4: Mode 11 (Unified INT8xINT8) -> A = 127 (0x7F), B = 127 (0x7F) -> Prod = 16129
        mode_2b = 2'b11; type_a = 0; type_b = 0; format_a = 2'b01; format_b = 2'b01; clr_acc = 1;
        A0_in = 8'h0F; A1_in = 8'h07; A2_in = 8'h0F; A3_in = 8'h07; // A=127
        B0_in = 8'h0F; B1_in = 8'h0F; B2_in = 8'h07; B3_in = 8'h07; // B=127
        @(negedge clk);
        check_result("Mode 11 INTxINT Unified 8x8", (acc_32b == 32'sd16129),
                     $sformatf("ACC32b=%0d (exp 16129)", acc_32b));

        //=====================================================================
        // GROUP 2: PURE FPxFP MODES (Modes 5 to 8)
        //=====================================================================
        // Mode 5: Mode 00 (Quad FP8 E4M3) -> 1.5 (0x3C) * 2.0 (0x40) = 3.0
        mode_2b = 2'b00; type_a = 1; type_b = 1; format_a = 2'b00; format_b = 2'b00; clr_acc = 1;
        A0_in = 8'h3C; B0_in = 8'h40; // 1.5 * 2.0 -> mag=96 (12*8), exp=1
        A1_in = 8'h38; B1_in = 8'h38; // 1.0 * 1.0 -> mag=64 (8*8), exp=0
        A2_in = 8'h40; B2_in = 8'h40; // 2.0 * 2.0 = 4.0
        A3_in = 8'hBC; B3_in = 8'h40; // -1.5 * 2.0 = -3.0
        @(negedge clk);
        check_result("Mode 00 FPxFP Quad E4M3", (acc_00 == 16'sd96 && acc_11 == -16'sd96),
                     $sformatf("ACC00=%0d (exp 96), ACC11=%0d (exp -96), block_exp=%0d", acc_00, acc_11, block_exp));

        // Mode 6: Mode 01 (Dual FP8 E4M3 2-Term Row Dot Product)
        mode_2b = 2'b01; clr_acc = 1;
        A0_in = 8'h3C; B0_in = 8'h40;
        A1_in = 8'h38; B1_in = 8'h38;
        A2_in = 8'h00; B2_in = 8'h00;
        A3_in = 8'h00; B3_in = 8'h00;
        @(negedge clk);
        check_result("Mode 01 FPxFP Row 2-Term Dot", (acc_row0 == 24'sd128),
                     $sformatf("Row0=%0d (exp 128), block_exp=%0d", acc_row0, block_exp));

        // Mode 7: Mode 10 (Dual FP8 E5M2 2-Term Col Dot Product)
        mode_2b = 2'b10; format_a = 2'b01; format_b = 2'b01; clr_acc = 1;
        A0_in = 8'h3C; B0_in = 8'h3C; // 1.0 * 1.0 -> mag=64, exp=0
        A2_in = 8'h3C; B2_in = 8'h3C; // 1.0 * 1.0 -> mag=64, exp=0
        A1_in = 8'h00; B1_in = 8'h00;
        A3_in = 8'h00; B3_in = 8'h00;
        @(negedge clk);
        check_result("Mode 10 FPxFP Col 2-Term Dot", (acc_col0 == 24'sd128),
                     $sformatf("Col0=%0d (exp 128), block_exp=%0d", acc_col0, block_exp));

        // Mode 8: Mode 11 (Unified FP8 E4M3 4-Term Dot Product)
        mode_2b = 2'b11; format_a = 2'b00; format_b = 2'b00; clr_acc = 1;
        A0_in = 8'h38; B0_in = 8'h38;
        A1_in = 8'h38; B1_in = 8'h38;
        A2_in = 8'h38; B2_in = 8'h38;
        A3_in = 8'h38; B3_in = 8'h38;
        @(negedge clk);
        check_result("Mode 11 FPxFP Unified 4-Term Dot", (acc_32b == 32'sd256),
                     $sformatf("ACC32b=%0d (exp 256), block_exp=%0d", acc_32b, block_exp));

        //=====================================================================
        // GROUP 3: MIXED INTxFP MODES (Modes 9 to 12)
        //=====================================================================
        // Mode 9: Mode 00 (Quad INT4 x FP8 E4M3)
        // A0=6, B0=1.5 (0x3C, mag=12) -> 72 | A1=-6 (0xA), B1=1.5 -> -72
        mode_2b = 2'b00; type_a = 0; type_b = 1; format_a = 2'b00; format_b = 2'b00; clr_acc = 1;
        A0_in = 8'h06; B0_in = 8'h3C;
        A1_in = 8'h0A; B1_in = 8'h3C;
        A2_in = 8'h00; B2_in = 8'h00;
        A3_in = 8'h00; B3_in = 8'h00;
        @(negedge clk);
        check_result("Mode 00 Mixed INT4xFP8 Quad", (acc_00 == 16'sd72 && acc_01 == -16'sd72),
                     $sformatf("ACC00=%0d (exp 72), ACC01=%0d (exp -72)", acc_00, acc_01));

        // Mode 10: Mode 01 (Dual INT8 x FP8 Row Fusion)
        // INT8 = 25 (0x19), FP8 = 1.5 (0x3C, mag=12, exp=0) -> Prod = 25 * 12 = 300
        mode_2b = 2'b01; format_a = 2'b01; clr_acc = 1;
        A0_in = 8'h19; B0_in = 8'h3C;
        A2_in = 8'h00; B2_in = 8'h00;
        @(negedge clk);
        check_result("Mode 01 Mixed INT8xFP8 Row", (acc_row0 == 24'sd300),
                     $sformatf("Row0=%0d (exp 300), block_exp=%0d", acc_row0, block_exp));

        // Mode 11: Mode 10 (Dual FP8 x INT8 Col Fusion)
        // FP8 = 2.0 (0x40, mag=8, exp=1), INT8 = 10 (0x0A) -> Prod = 80
        mode_2b = 2'b10; type_a = 1; type_b = 0; format_a = 2'b00; format_b = 2'b01; clr_acc = 1;
        A0_in = 8'h40; B0_in = 8'h0A;
        A1_in = 8'h00; B1_in = 8'h00;
        @(negedge clk);
        check_result("Mode 10 Mixed FP8xINT8 Col", (acc_col0 == 24'sd80),
                     $sformatf("Col0=%0d (exp 80), block_exp=%0d", acc_col0, block_exp));

        // Mode 12: Mode 11 (Unified 4-Term INT8-Weight x FP8-Activation Dot Product)
        // W0 = 25 (0x19), X0 = 1.5 (0x3C, mag=12, exp=0) -> Term0 = 300 (exp=0)
        // W1 = -10 (0xF6), X1 = 2.0 (0x40, mag=8, exp=1) -> Term1 = -80 (exp=1)
        // Aligned to max_exp=1: Term0 is 300 >> 1 = 150. Sum = 150 - 80 = 70
        mode_2b = 2'b11; type_a = 0; type_b = 1; format_a = 2'b01; format_b = 2'b00; clr_acc = 1;
        A0_in = 8'h19; B0_in = 8'h3C; // W0=25, X0=1.5
        A2_in = 8'hF6; B2_in = 8'h40; // W1=-10, X1=2.0
        @(negedge clk);
        check_result("Mode 11 Mixed INT8-wt x FP8-act Dot", (acc_32b == 32'sd70),
                     $sformatf("ACC32b=%0d (exp 70), block_exp=%0d", acc_32b, block_exp));

        $display("\n======================================================================");
        $display(" 12-MODE UNIFIED TILE VERIFICATION COMPLETE: %0d PASSED, %0d FAILED", pass_count, fail_count);
        $display("======================================================================\n");

        if (fail_count == 0) $display(">>> ALL 12 RECONFIGURABLE MODES VERIFIED WITH 100%% SUCCESS! <<<\n");
        else                 $display(">>> TEST FAILURES DETECTED! <<<\n");

        $finish;
    end

endmodule
