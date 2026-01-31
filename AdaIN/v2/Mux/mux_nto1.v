`timescale 1ns/1ps

module mux_nto1 #(
    parameter N = 5,
    parameter WIDTH = 16
)(
    input  wire [$clog2(N)-1:0] sel,
    input  wire [N*WIDTH-1:0]   in,
    output reg  [WIDTH-1:0]     out
);
    localparam MAX_N = 1 << $clog2(N);
    
    wire [WIDTH-1:0] in_array [0:MAX_N-1];
    genvar i;
    generate
        for (i = 0; i < MAX_N; i = i + 1) begin : map_logic
            if (i < N) begin
                assign in_array[i] = in[i*WIDTH +: WIDTH];
            end else begin
                assign in_array[i] = {WIDTH{1'b0}};
            end
        end
    endgenerate

    always @(*) begin
        out <= in_array[sel];
    end
endmodule