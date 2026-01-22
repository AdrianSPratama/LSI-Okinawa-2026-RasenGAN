// TODO: Make addr counter for bias_BRAM
// TODO: Change m_axis_tdata to connect from leakyReLu
// TODO: add LeakyReLu and noise adding
`timescale 1ns / 1ps

module top_level_conv_datapath #(
    parameter DATA_WIDTH = 16,
    parameter PIXEL_WIDTH = 16,
    parameter KERNEL_WIDTH = 16,
    parameter RESULT_WIDTH = 48
) (
    // Control inputs
    input wire clk,
    input wire slave_select,
    input wire en_reg_last_chan,
    input wire rst_reg_last_chan,

    input wire Kernel_BRAM_Reset,
    input wire load_BRAM_dina,
    input wire update_BRAM_doutb,

    input wire Input_line_buffer_Reset,
    input wire Stream_first_row,
    input wire Stream_mid_row,
    input wire Stream_last_row,

    input wire PE_with_buffers_Reset,
    input wire Load_kernel_reg,

    input wire en_top_row_counter,
    input wire rst_top_row_counter,

    input wire [8:0] CHANNEL_SIZE,
    input wire [7:0] IMAGE_SIZE,

    // Control outputs
    output wire reg_last_chan,
    
    output wire last_loading_1ker,
    output wire last_channel,
    output wire Kernel_BRAM_IDLE,

    output wire Done_1row,
    output wire Input_line_buffer_IDLE,
    output wire PE_ready,
    output wire PE_with_buffers_IDLE,
    output wire ena_bias_BRAM_addr_counter,
    output wire rst_bias_BRAM_addr_counter,

    output wire [6:0] top_row_counter_out,

    // Data I/O AXI Stream
    input wire [255:0] s_axis_tdata,
    output wire [63:0] m_axis_tdata,

    // Data input bias from bias_BRAM (instantiated outside)
    input wire signed [15:0] bias_in,
    // Output wire for bias_BRAM addr counter

    // AXI signals
    // Slave
    input wire s_axis_tvalid,
    input wire s_axis_tlast,
    output wire s_axis_tready,

    // Master
    output wire m_axis_tvalid,
    output wire m_axis_tlast,
    input wire m_axis_tready
);
    
    // Wires
    wire signed [47:0] bias_padded;

    // Controls
    wire kernel_BRAM_s_axis_tready;
    wire input_line_buffer_s_axis_tready;
    wire Output_valid;

    wire [7:0] b_counter_output;

    wire [143:0] kernel_BRAM_dina;
    wire [143:0] kernel_BRAM_doutb;

    wire signed [PIXEL_WIDTH-1:0] out_window_00;
    wire signed [PIXEL_WIDTH-1:0] out_window_01;
    wire signed [PIXEL_WIDTH-1:0] out_window_02;
    wire signed [PIXEL_WIDTH-1:0] out_window_10;
    wire signed [PIXEL_WIDTH-1:0] out_window_11;
    wire signed [PIXEL_WIDTH-1:0] out_window_12;
    wire signed [PIXEL_WIDTH-1:0] out_window_20;
    wire signed [PIXEL_WIDTH-1:0] out_window_21;
    wire signed [PIXEL_WIDTH-1:0] out_window_22;

    wire signed [47:0] output_BRAM_doutb;

    // Assigns
    assign bias_padded = bias_in;

    assign kernel_BRAM_dina = s_axis_tdata[143:0];
    assign input_line_buffer_dina = s_axis_tdata[15:0];

    assign m_axis_tdata = {{16{output_BRAM_doutb[47]}} ,output_BRAM_doutb};// For now assign m_axis_tdata to output_BRAM

    // Reg_last_chan
    reg Reg_last_chan;
    always @(posedge clk) begin
        if(!rst_reg_last_chan) Reg_last_chan <= 0;
        else begin
            if(en_reg_last_chan) Reg_last_chan <= 1;
            else Reg_last_chan <= Reg_last_chan;
        end
    end
    assign reg_last_chan = Reg_last_chan;

    // Instantiate en_top_row_counter
    counter #(
        .BITWIDTH(7)
    ) TOP_ROW_COUNTER (
        .enable(en_top_row_counter),
        .reset(rst_top_row_counter), 
        .clk(clk),
        .counter_out(top_row_counter_out)
    );

    // MUX for s_axis_tready
    always @(*) begin
        if(slave_select) s_axis_tready <= input_line_buffer_s_axis_tready;
        else s_axis_tready <= kernel_BRAM_s_axis_tready;
    end

    // Instantiate sub modules
    kernel_BRAM #(
        .KERNEL_WIDTH(KERNEL_WIDTH)
    ) KERNEL_BRAM (
        // Control inputs
        .clk(clk),
        .Reset(Kernel_BRAM_Reset),
        .load_BRAM_dina(load_BRAM_dina),
        .update_BRAM_doutb(update_BRAM_doutb),
        .CHANNEL_SIZE(CHANNEL_SIZE),

        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast), // Not used

        // Control output interface for other blocks
        .last_loading_1ker(last_loading_1ker),
        .last_channel(last_channel),
        .s_axis_tready(kernel_BRAM_s_axis_tready),
        .Kernel_BRAM_IDLE(Kernel_BRAM_IDLE),
        .b_counter_output(b_counter_output),

        // Data ports
        .kernel_BRAM_dina(kernel_BRAM_dina),
        .kernel_BRAM_doutb(kernel_BRAM_doutb)
    );

    input_line_buffer #(
        .DATA_WIDTH(DATA_WIDTH)
    ) INPUT_LINE_BUFFER (
        // Data I/O
        .dina(input_line_buffer_dina),
        .out_window_00(out_window_00), 
        .out_window_01(out_window_01), 
        .out_window_02(out_window_02),
        .out_window_10(out_window_10), 
        .out_window_11(out_window_11), 
        .out_window_12(out_window_12),
        .out_window_20(out_window_20), 
        .out_window_21(out_window_21), 
        .out_window_22(out_window_22),

        // Control signals interface with other blocks
        // Input controls interface
        .clk(clk),
        .Reset(Input_line_buffer_Reset),
        .Stream_first_row(Stream_first_row),
        .Stream_mid_row(Stream_mid_row), 
        .Stream_last_row(Stream_last_row),
        .IMAGE_SIZE(IMAGE_SIZE),
        .last_channel(last_channel),

        // AXI input signals
        .m_axis_tready(m_axis_tready),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),

        // Output controls for interface
        .Done_1row(Done_1row),
        .Output_valid(Output_valid),
        .Input_line_buffer_IDLE(Input_line_buffer_IDLE),
        .s_axis_tready(input_line_buffer_s_axis_tready)
    );

    pe_with_buffers #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .KERNEL_WIDTH(KERNEL_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) PE_WITH_BUFFERS (
        .clk(clk),
        // Data I/O
        .x00(out_window_02),
        .x01(out_window_01), 
        .x02(out_window_00),
        .x10(out_window_12),
        .x11(out_window_11), 
        .x12(out_window_10),
        .x20(out_window_22),
        .x21(out_window_21), 
        .x22(out_window_20),
        .kernel_flat(kernel_BRAM_doutb),
        .bias(bias_padded),
        .BRAM_doutb(output_BRAM_doutb),

        // Control signals
        // From inside this module
        // input wire Wr_kernel,
        // input wire Rst_kernel,
        // input wire [13:0] addra_output_BRAM, // Address for write port A
        // input wire [13:0] addrb_output_BRAM, // Address for read port B
        // input wire add_bias,

        // Control inputs
        .Reset(PE_with_buffers_Reset),
        .b_counter_output(b_counter_output),
        .Load_kernel_reg(Load_kernel_reg),
        .Stream_mid_row(Stream_mid_row),
        .Stream_last_row(Stream_last_row),
        .Output_valid(Output_valid),
        .Done_1row(Done_1row),
        .last_channel(last_channel),

        // Output BRAM controls
        // From inside this module
        // input wire ena_output_BRAM,
        // input wire wea_output_BRAM,
        // input wire enb_output_BRAM // Write port b not used
        .ena_bias_BRAM_addr_counter(ena_bias_BRAM_addr_counter),
        .rst_bias_BRAM_addr_counter(rst_bias_BRAM_addr_counter),

        // AXI signalsm_axis_tvalid
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),

        // Controls output interface
        .PE_ready(PE_ready),
        .PE_with_buffers_IDLE(PE_with_buffers_IDLE)
    );

endmodule