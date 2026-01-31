`timescale 1ns/1ps

module shift_ra #(
    parameter WIDTH = 16
)(
    input  wire [WIDTH-1:0]         in,
    input  wire [$clog2(WIDTH)-1:0] shift_amt,
    output reg  [WIDTH-1:0]         out
);
    always @(*) begin
        out = $signed(in) >>> shift_amt;
    end
endmodule