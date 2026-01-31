`timescale 1ns / 1ps
`include "reg_input.v"
`include "reg_output.v"
`include "control_unit_upsample.v"
`include "multi_upsample.v"


module top_upsample #(parameter length = 16) (
    input wire clk,
    input wire rst,
    input wire start,
    input wire [2:0] size_upsample,
    output wire done,
    // input data
    input wire [length - 1:0] t_data_in,
    output wire [length - 1:0] t_data_out,

    output wire en_write_out ,

    output wire [13:0] addr_input,
    output wire [13:0] addr_output
);

    wire [length-1:0] a;
    wire [length-1:0] b;
    wire [length-1:0] c;
    wire [length-1:0] d;

    wire [3:0] write_mode;

    wire [length-1:0] out1;
    wire [length-1:0] out2;
    wire [length-1:0] out3;
    wire [length-1:0] out4;

    wire [length-1:0] out5;
    wire [length-1:0] out6;
    wire [length-1:0] out7;
    wire [length-1:0] out8;
    wire [length-1:0] out9;

    multi_upsample upsample_inst(
        .a(a),
        .b(b),
        .c(c),
        .d(d),

        .write_mode(write_mode),

        .out1(out1),
        .out2(out2),
        .out3(out3),
        .out4(out4),

        .out5(out5),
        .out6(out6),
        .out7(out7),
        .out8(out8),
        .out9(out9)
    );
     
    wire en_write_in;
    wire even_row;
    wire even_coloumn;

    wire [7:0] kolom;
    wire [7:0] s_kolom;

    control_unit_upsample control_unit_inst (
        .clk(clk),
        .rst(rst),
        .start(start),
        .done(done),
        .size_upsample(size_upsample),


        .write_mode(write_mode),
        .en_write_in(en_write_in),
        .en_write_out(en_write_out),
        .addr_input(addr_input),
        .addr_output(addr_output),
        .kolom(kolom),
        .s_kolom(s_kolom),

        .row_even(even_row),
        .coloumn_even(even_coloumn)

    );


    reg_input #(
        .length(length)
    ) reg_input_inst (
        .clk(clk),
        .rst(rst),
        .din(t_data_in),
        .en_write_in(en_write_in),

        .size_upsample(size_upsample),

        .dout1(a),
        .dout2(b),
        .dout3(c),
        .dout4(d)
    );


    reg_output #(
        .length(length)
    ) reg_output_inst (
        .clk(clk),
        .rst(rst),
        .write_mode(write_mode),

        .row_even(even_row),
        .coloumn_even(even_coloumn),

        .data_in1(out1),
        .data_in2(out2),
        .data_in3(out3),
        .data_in4(out4),
        .kolom(kolom),
        .s_kolom(s_kolom),

        .data_in5(out5),
        .data_in6(out6),
        .data_in7(out7),
        .data_in8(out8),
        .data_in9(out9),
        .dout(t_data_out)
    );





endmodule