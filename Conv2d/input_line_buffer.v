`timescale 1ns / 1ps

module input_line_buffer #(
    parameter DATA_WIDTH = 16
) (
    // Data I/O
    input wire signed [DATA_WIDTH-1:0] dina,
    output wire signed [DATA_WIDTH-1:0] out_window_00, out_window_01, out_window_02,
    output wire signed [DATA_WIDTH-1:0] out_window_10, out_window_11, out_window_12,
    output wire signed [DATA_WIDTH-1:0] out_window_20, out_window_21, out_window_22,

    // Control signals interface with other blocks
    // Input controls interface
    input wire clk,
    input wire Reset,
    input wire Stream_first_row, Stream_mid_row, Stream_last_row,
    input wire [7:0] IMAGE_SIZE,
    input wire last_channel,

    // AXI input signals
    input wire m_axis_tready,
    input wire s_axis_tvalid,
    input wire s_axis_tlast,

    // Output controls for interface
    output wire Done_1row,
    output wire Output_valid,
    output wire s_axis_tready
);

    // Wires
    wire [6:0] linebuff_BRAM_counter_out;
    wire Rst_window;
    wire Wr_window;
    wire Shift_window;

    wire window_row_n_2_mux;
    wire window_row_n_1_mux;
    wire window_row_n_mux;

    wire ena_linebuff_BRAM;
    wire wea_linebuff_BRAM;
    wire enb_linebuff_BRAM;

    wire en_linebuff_BRAM_counter;
    wire rst_linebuff_BRAM_counter;

    // Instantiate CU
    input_line_buffer_CU CONTROL (
        // Inputs
        .clk(clk),
        .Reset(Reset),
        .Stream_first_row(Stream_first_row),
        .Stream_mid_row(Stream_mid_row),
        .Stream_last_row(Stream_last_row),
        .IMAGE_SIZE(IMAGE_SIZE),
        .last_channel(last_channel),
        .linebuff_BRAM_counter_out(linebuff_BRAM_counter_out),

        // AXI input signals
        .m_axis_tready(m_axis_tready),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast), // Not used in CU

        // Control signal outputs
        // Interface for other blocks
        .Done_1row(Done_1row),
        .Output_valid(Output_valid),
        .s_axis_tready(s_axis_tready),

        // Internal output control signals
        .Rst_window(Rst_window),
        .Wr_window(Wr_window),
        .Shift_window(Shift_window),

        .window_row_n_2_mux(window_row_n_2_mux),
        .window_row_n_1_mux(window_row_n_1_mux),
        .window_row_n_mux(window_row_n_mux),

        .ena_linebuff_BRAM(ena_linebuff_BRAM),
        .wea_linebuff_BRAM(wea_linebuff_BRAM),
        .enb_linebuff_BRAM(enb_linebuff_BRAM),

        .en_linebuff_BRAM_counter(en_linebuff_BRAM_counter),
        .rst_linebuff_BRAM_counter(rst_linebuff_BRAM_counter)
    );

    // Instantiate datapath
    input_line_buffer_datapath #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DATAPATH (
        // Data ports
        .dina(dina),
        .out_window_00(out_window_00),
        .out_window_01(out_window_01),
        .out_window_02(out_window_02),
        .out_window_10(out_window_10),
        .out_window_11(out_window_11),
        .out_window_12(out_window_12),
        .out_window_20(out_window_20),
        .out_window_21(out_window_21),
        .out_window_22(out_window_22),

        // Control signals
        // Window register control signals
        .clk(clk),
        .Wr_window(Wr_window),
        .Shift_window(Shift_window),
        .Rst_window(Rst_window),
        .window_row_n_mux(window_row_n_mux),
        .window_row_n_1_mux(window_row_n_1_mux),
        .window_row_n_2_mux(window_row_n_2_mux),

        // Line buffer BRAM control signals
        .ena_linebuff_BRAM(ena_linebuff_BRAM), 
        .wea_linebuff_BRAM(wea_linebuff_BRAM),
        .enb_linebuff_BRAM(enb_linebuff_BRAM), 

        // Line buffer BRAM counter control signals
        .en_linebuff_BRAM_counter(en_linebuff_BRAM_counter), 
        .rst_linebuff_BRAM_counter(rst_linebuff_BRAM_counter),
        .linebuff_BRAM_counter_out(linebuff_BRAM_counter_out) // Max image size 128, counter 7 bit
    );

endmodule