`timescale 1ns/1ps

module mac_adain #(
    parameter WIDTH_IN      = 48,
    parameter FRAC_BITS_IN  = 16,
    parameter WIDTH_OUT     = 112
)(
    input  wire clk,
    input  wire rst,
    input  wire rst_acc,                

    input  wire signed [WIDTH_IN-1:0]  multiplicand,
    input  wire signed [WIDTH_IN-1:0]  multiplier,
    input  wire signed [WIDTH_IN-1:0]  offset,
    output reg  signed [WIDTH_OUT-1:0] acc
);
    reg signed [2*WIDTH_IN-1:0] product;
    always @(posedge clk) begin
        product <= multiplicand * multiplier;
    end

    always @(posedge clk) begin
        if (rst) begin
            acc <= 0;
        end else begin
            acc <= product + (rst_acc ? {offset, {(FRAC_BITS_IN){1'b0}}} : acc);
        end
    end
endmodule