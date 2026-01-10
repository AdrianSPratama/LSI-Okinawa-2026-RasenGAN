`timescale 1ns/1ps

module reg_sync_rst #(
    parameter WIDTH = 16
)(
    input  wire clk,
    input  wire rst,    
    input  wire en,            

    input  wire [WIDTH-1:0] in,
    output reg  [WIDTH-1:0] out
);
    always @(posedge clk) begin
        if (rst) begin
            out <= 0;
        end else if (en) begin
            out <= in;
        end
    end
endmodule