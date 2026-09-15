//-----------------------------------------------------------------------------
// Module: counter.sv
// Description: Parametric Up/Down Counter with Synchronous Load & Enable
// Standard: SystemVerilog (IEEE 1800)
//-----------------------------------------------------------------------------
`timescale 1ns / 1ps

module counter #(
    parameter int WIDTH = 8
) (
    input  logic             clk,
    input  logic             rst_n,    // Active-low synchronous reset
    input  logic             enable,   // Enable count
    input  logic             up_down,  // 1: Count Up, 0: Count Down
    input  logic             load,     // Synchronous load priority
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count,
    output logic             overflow,
    output logic             underflow
);

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            count     <= '0;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else if (load) begin
            count     <= load_val;
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end else if (enable) begin
            if (up_down) begin
                if (count == {WIDTH{1'b1}}) begin
                    count    <= '0;
                    overflow <= 1'b1;
                end else begin
                    count    <= count + 1'b1;
                    overflow <= 1'b0;
                end
                underflow <= 1'b0;
            end else begin
                if (count == '0) begin
                    count     <= {WIDTH{1'b1}};
                    underflow <= 1'b1;
                end else begin
                    count     <= count - 1'b1;
                    underflow <= 1'b0;
                end
                overflow <= 1'b0;
            end
        end else begin
            overflow  <= 1'b0;
            underflow <= 1'b0;
        end
    end

endmodule
