`timescale 1ns/1ps

module shifter_ra #(
    parameter WIDTH     = 16,
    parameter MAX_SHIFT = 3
)(
    input  wire [WIDTH-1:0]                 in,
    input  wire [$clog2(MAX_SHIFT+1)-1:0]   shift_amt,
    output reg  [WIDTH-1:0]                 out
);
    always @(*) begin
        out = $signed(in) >>> shift_amt;
    end
endmodule