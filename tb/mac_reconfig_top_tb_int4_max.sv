//-----------------------------------------------------------------------------
// Module: mac_reconfig_top_tb_int4_max.sv
// Description: Maximum Power INT4 Testbench (100% Duty Cycle, Worst-Case Corner Flips)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module mac_reconfig_top_tb_int4_max;
    localparam time CLK_PERIOD = 10ns;

    logic              clk, rst_n, mode_8b, valid_in, clr_acc;
    logic signed [3:0] A_4b_00, B_4b_00, A_4b_01, B_4b_01, A_4b_10, B_4b_10, A_4b_11, B_4b_11;
    logic signed [7:0] A_8b, B_8b;
    logic              valid_out;
    logic signed [15:0] acc_00, acc_01, acc_10, acc_11;
    logic signed [31:0] acc_32b;

    mac_reconfig_top dut (
        .clk(clk), .rst_n(rst_n), .mode_8b(mode_8b), .valid_in(valid_in), .clr_acc(clr_acc),
        .A_4b_00(A_4b_00), .B_4b_00(B_4b_00), .A_4b_01(A_4b_01), .B_4b_01(B_4b_01),
        .A_4b_10(A_4b_10), .B_4b_10(B_4b_10), .A_4b_11(A_4b_11), .B_4b_11(B_4b_11),
        .A_8b(A_8b), .B_8b(B_8b), .valid_out(valid_out),
        .acc_00(acc_00), .acc_01(acc_01), .acc_10(acc_10), .acc_11(acc_11), .acc_32b(acc_32b)
    );

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        $dumpfile("mac_reconfig_top_int4_max.vcd");
        $dumpvars(0, mac_reconfig_top_tb_int4_max.dut);

        clk = 0; rst_n = 0; mode_8b = 0; valid_in = 0; clr_acc = 0;
        A_4b_00 = 0; B_4b_00 = 0; A_4b_01 = 0; B_4b_01 = 0;
        A_4b_10 = 0; B_4b_10 = 0; A_4b_11 = 0; B_4b_11 = 0;
        A_8b = 0; B_8b = 0;

        #(CLK_PERIOD * 2);
        rst_n = 1;

        // 100% Duty Cycle (valid_in = 1 continuously), Max Dynamic Flips (0x5 <-> 0xA and +7 <-> -8)
        for (int i = 0; i < 200; i++) begin
            @(negedge clk);
            valid_in = 1'b1; // 100% duty cycle
            clr_acc  = (i % 10 == 0);
            if (i % 2 == 0) begin
                A_4b_00 = 4'b0101; B_4b_00 = 4'b1010;
                A_4b_01 = 4'sd7;   B_4b_01 = -4'sd8;
                A_4b_10 = 4'b0101; B_4b_10 = 4'b1010;
                A_4b_11 = 4'sd7;   B_4b_11 = -4'sd8;
            end else begin
                A_4b_00 = 4'b1010; B_4b_00 = 4'b0101;
                A_4b_01 = -4'sd8;  B_4b_01 = 4'sd7;
                A_4b_10 = 4'b1010; B_4b_10 = 4'b0101;
                A_4b_11 = -4'sd8;  B_4b_11 = 4'sd7;
            end
        end

        @(negedge clk);
        valid_in = 0;
        #(CLK_PERIOD * 5);
        $finish;
    end
endmodule
