`timescale 1ns/1ps

module seq_adder #(
    parameter WIDTH = 112
)(
    input  wire clk,
    input  wire rst,

    input  wire signed [WIDTH-1:0] in1,
    input  wire signed [WIDTH-1:0] in2,
    output reg  signed [WIDTH-1:0] out
);
    always @(posedge clk) begin
        if (rst) begin
            out <= 0;
        end else begin
            out <= in1 + in2;
        end
    end
endmodule