`timescale 1ns/1ps

module seq_mult_add #(
    parameter WIDTH_IN  = 48,
    parameter WIDTH_OUT = 112
)(
    input  wire clk,
    input  wire rst,
    input  wire en,

    input  wire signed [WIDTH_IN-1:0]  multiplicand,
    input  wire signed [WIDTH_IN-1:0]  multiplier,
    input  wire signed [WIDTH_OUT-1:0] offset,
    output wire signed [WIDTH_OUT-1:0] out
);
    reg signed [2*WIDTH_IN-1:0] product;
    always @(posedge clk) begin
        if (en) begin
            product <= multiplicand * multiplier;
        end
    end
    
    seq_adder #(
        .WIDTH(WIDTH_OUT)
    ) adder (
        .clk(clk),
        .rst(rst),
        .en(en),
        
        .in1({{(WIDTH_OUT-2*WIDTH_IN){product[2*WIDTH_IN-1]}}, product}),
        .in2(offset),
        .out(out)
    );
endmodule