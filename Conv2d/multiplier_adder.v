`timescale 1ns / 1ps

module multiplier_adder # (
    parameter PIXEL_WIDTH = 16,
    parameter KERNEL_WIDTH = 16,
    parameter RESULT_WIDTH = 48
) (
    input wire signed [PIXEL_WIDTH-1:0] x00, x01, x02,
    input wire signed [PIXEL_WIDTH-1:0] x10, x11, x12,
    input wire signed [PIXEL_WIDTH-1:0] x20, x21, x22,
    input wire signed [KERNEL_WIDTH-1:0] k00, k01, k02,
    input wire signed [KERNEL_WIDTH-1:0] k10, k11, k12,
    input wire signed [KERNEL_WIDTH-1:0] k20, k21, k22,
    output wire signed [RESULT_WIDTH-1:0] result
);

    // Intermediate multiplication results
    wire signed [RESULT_WIDTH-1:0] p00, p01, p02;
    wire signed [RESULT_WIDTH-1:0] p10, p11, p12;
    wire signed [RESULT_WIDTH-1:0] p20, p21, p22;

    // Perform multiplications
    assign p00 = x00 * k00;
    assign p01 = x01 * k01;
    assign p02 = x02 * k02;
    assign p10 = x10 * k10;
    assign p11 = x11 * k11;
    assign p12 = x12 * k12;
    assign p20 = x20 * k20;
    assign p21 = x21 * k21;
    assign p22 = x22 * k22;

    // Adder tree to sum the products
    wire signed [RESULT_WIDTH-1:0] sum0, sum1, sum2, sum3, sum4;
    wire signed [RESULT_WIDTH-1:0] sum01, sum23;
    wire signed [RESULT_WIDTH-1:0] sum0123;

    assign sum0 = p00 + p01;
    assign sum1 = p02 + p10;
    assign sum2 = p11 + p12;
    assign sum3 = p20 + p21;
    assign sum4 = p22;

    assign sum01 = sum0 + sum1;
    assign sum23 = sum2 + sum3;

    assign sum0123 = sum01 + sum23;
    assign result = sum0123 + sum4;

endmodule