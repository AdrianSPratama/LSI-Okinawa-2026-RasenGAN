`timescale 1ns/1ps

module priority_encoder #(
    parameter WIDTH = 16
)(
    input wire  [WIDTH-1:0]          in,
    output wire [$clog2(WIDTH)-1:0]  out
);
    wire [$clog2(WIDTH)-1:0] chain [WIDTH-1:0];
    assign chain[0] = 0;
    
    genvar i;
    generate
        for (i = 1; i < WIDTH; i = i + 1) begin : gen_priority_logic
            assign chain[i] = in[i] ? i[$clog2(WIDTH)-1:0] : chain[i-1];
        end
    endgenerate
    
    assign out = chain[WIDTH-1];
endmodule