`timescale 1ns / 1ps

module multiplier_adder # (
    parameter PIXEL_WIDTH = 16,
    parameter KERNEL_WIDTH = 16,
    parameter RESULT_WIDTH = 48
) (
    input wire rst, clk,
    input wire signed [PIXEL_WIDTH-1:0] x00, x01, x02,
    input wire signed [PIXEL_WIDTH-1:0] x10, x11, x12,
    input wire signed [PIXEL_WIDTH-1:0] x20, x21, x22,
    input wire signed [KERNEL_WIDTH-1:0] k00, k01, k02,
    input wire signed [KERNEL_WIDTH-1:0] k10, k11, k12,
    input wire signed [KERNEL_WIDTH-1:0] k20, k21, k22,
    output reg signed [RESULT_WIDTH-1:0] result
);

    // Intermediate multiplication results
    reg signed [RESULT_WIDTH-1:0] p00, p01, p02;
    reg signed [RESULT_WIDTH-1:0] p10, p11, p12;
    reg signed [RESULT_WIDTH-1:0] p20, p21, p22;

    // Perform multiplications (pipelined)
    always @(posedge clk) begin
        if (!rst) begin
            p00 <= 0;
            p01 <= 0;
            p02 <= 0;
            p10 <= 0;
            p11 <= 0;
            p12 <= 0;
            p20 <= 0;
            p21 <= 0;
            p22 <= 0;
        end
        else begin
            p00 <= x00 * k00;
            p01 <= x01 * k01;
            p02 <= x02 * k02;
            p10 <= x10 * k10;
            p11 <= x11 * k11;
            p12 <= x12 * k12;
            p20 <= x20 * k20;
            p21 <= x21 * k21;
            p22 <= x22 * k22;
        end
    end

    // Adder tree to sum the products
    wire signed [RESULT_WIDTH-1:0] sum0, sum1, sum2, sum3, sum4;
    reg signed [RESULT_WIDTH-1:0] sum01, sum23, sum4_2;
    wire signed [RESULT_WIDTH-1:0] sum0123;

    assign sum0 = p00 + p01;
    assign sum1 = p02 + p10;
    assign sum2 = p11 + p12;
    assign sum3 = p20 + p21;
    assign sum4 = p22;

    // Make pipeline
    always @(posedge clk) begin
        if (!rst) begin
            sum01 <= 0;
            sum23 <= 0;
            sum4_2 <= 0;
        end
        else begin
            sum01 <= sum0 + sum1;
            sum23 <= sum2 + sum3;
            sum4_2 <= sum4;
        end
    end

    assign sum0123 = sum01 + sum23;

    // Make pipeline
    always @(posedge clk) begin
        if (!rst) begin
           result <= 0; 
        end
        else begin
            result <= sum0123 + sum4_2;
        end
    end

endmodule