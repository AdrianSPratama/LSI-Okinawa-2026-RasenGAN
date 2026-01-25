`timescale 1ns/1ps

module mux_8to1 #(
    parameter WIDTH = 16
)(
    input  wire [2:0] sel,
    input  wire [WIDTH-1:0] in0,
    input  wire [WIDTH-1:0] in1,
    input  wire [WIDTH-1:0] in2,
    input  wire [WIDTH-1:0] in3,
    input  wire [WIDTH-1:0] in4,
    input  wire [WIDTH-1:0] in5,
    input  wire [WIDTH-1:0] in6,
    input  wire [WIDTH-1:0] in7,
    output reg  [WIDTH-1:0] out
);
    always @(*) begin
        case (sel)
            3'b000  : out = in0;
            3'b001  : out = in1;
            3'b010  : out = in2;
            3'b011  : out = in3;
            3'b100  : out = in4;
            3'b101  : out = in5;
            3'b110  : out = in6;
            3'b111  : out = in7;
            default : out = 8'b0;
        endcase
    end
endmodule