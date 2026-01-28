`timescale 1ns / 1ps

module top_level_conv #(
    parameter DATA_WIDTH = 16,
    parameter PIXEL_WIDTH = 16,
    parameter KERNEL_WIDTH = 16,
    parameter RESULT_WIDTH = 48
) (
    // Control inputs
    input wire clk,
    // Input from AXI GPIO
    input wire Reset_top,
    input wire Load_kernel_BRAM,
    input wire [1:0] CHANNEL_SIZE_choose,
    input wire [2:0] IMAGE_SIZE_choose,

    // Control outputs
    output wire ena_bias_BRAM_addr_counter,
    output wire rst_bias_BRAM_addr_counter,
    output wire [11:0] bias_BRAM_addr_counter_out,
    output wire conv_DONE,

    // Data I/O
    input wire [15:0] bias_in,
    input wire [255:0] s_axis_tdata,
    output wire [63:0] m_axis_tdata,

    // AXI Stream controls
    input wire aresetn,

    input wire s_axis_tvalid,
    input wire s_axis_tlast,
    input wire m_axis_tready,

    output wire s_axis_tready,
    output wire m_axis_tvalid,
    output wire m_axis_tlast,

    // Output BRAM counter output for noise address counter (same)
    output wire [13:0] output_BRAM_counter_out,

    // Noise weight BRAM counter output
    output reg [8:0] noise_weight_BRAM_counter_out,

    // Output control for generating (start) noise generator module
    output wire start_noise_gen
);
    
    // Wires
    wire reg_last_chan;

    wire last_loading_1ker;
    wire last_channel;
    wire Kernel_BRAM_IDLE;

    wire Done_1row;
    wire Input_line_buffer_IDLE;

    wire PE_ready;
    wire PE_with_buffers_IDLE;
    
    wire [6:0] top_row_counter_out;

    wire slave_select;
    wire en_reg_last_chan;
    wire rst_reg_last_chan;

    wire Kernel_BRAM_Reset;
    wire load_BRAM_dina;
    wire update_BRAM_doutb;

    wire Input_line_buffer_Reset;
    wire Stream_first_row;
    wire Stream_mid_row;
    wire Stream_last_row;

    wire PE_with_buffers_Reset;
    wire Load_kernel_reg; 

    wire en_top_row_counter;
    wire rst_top_row_counter;

    wire [8:0] CHANNEL_SIZE;
    wire [7:0] IMAGE_SIZE;

    // Instantiate CU
    top_level_conv_CU CONV_CONTROL (
        .clk(clk),
        // Control inputs
        .Reset_top(Reset_top),
        .Load_kernel_BRAM(Load_kernel_BRAM),
        .reg_last_chan(reg_last_chan),
        
        // CHANNEL_SIZE_choose: 2'd0 = 256, 2'd1 = 128, 2'd2 = 64 (from GPIO)
        .CHANNEL_SIZE_choose(CHANNEL_SIZE_choose),
        // IMAGE_SIZE_choose: 3'd0 = 4, 3'd1 = 8, 3'd2 = 16, 3'd3 = 32, 3'd4 = 64, 3'd5 = 128 (from GPIO)
        .IMAGE_SIZE_choose(IMAGE_SIZE_choose),
        
        .last_loading_1ker(last_loading_1ker),
        .last_channel(last_channel),
        .Kernel_BRAM_IDLE(Kernel_BRAM_IDLE),

        .Done_1row(Done_1row),
        .Input_line_buffer_IDLE(Input_line_buffer_IDLE),

        .PE_ready(PE_ready),
        .PE_with_buffers_IDLE(PE_with_buffers_IDLE),

        .top_row_counter_out(top_row_counter_out),

        .aresetn(aresetn),

        // Control outputs
        .slave_select(slave_select),
        .conv_DONE(conv_DONE),
        .en_reg_last_chan(en_reg_last_chan),
        .rst_reg_last_chan(rst_reg_last_chan),

        .Kernel_BRAM_Reset(Kernel_BRAM_Reset),
        .load_BRAM_dina(load_BRAM_dina),
        .update_BRAM_doutb(update_BRAM_doutb),

        .Input_line_buffer_Reset(Input_line_buffer_Reset),
        .Stream_first_row(Stream_first_row),
        .Stream_mid_row(Stream_mid_row),
        .Stream_last_row(Stream_last_row),

        .PE_with_buffers_Reset(PE_with_buffers_Reset),
        .Load_kernel_reg(Load_kernel_reg),

        .en_top_row_counter(en_top_row_counter),
        .rst_top_row_counter(rst_top_row_counter),

        .CHANNEL_SIZE(CHANNEL_SIZE),
        .IMAGE_SIZE(IMAGE_SIZE)
    );

    top_level_conv_datapath #(
        .DATA_WIDTH(DATA_WIDTH),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .KERNEL_WIDTH(KERNEL_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) CONV_DATAPATH (
        // Control inputs
        .clk(clk),
        .slave_select(slave_select),
        .en_reg_last_chan(en_reg_last_chan),
        .rst_reg_last_chan(rst_reg_last_chan),

        .Kernel_BRAM_Reset(Kernel_BRAM_Reset),
        .load_BRAM_dina(load_BRAM_dina),
        .update_BRAM_doutb(update_BRAM_doutb),

        .Input_line_buffer_Reset(Input_line_buffer_Reset),
        .Stream_first_row(Stream_first_row),
        .Stream_mid_row(Stream_mid_row),
        .Stream_last_row(Stream_last_row),

        .PE_with_buffers_Reset(PE_with_buffers_Reset),
        .Load_kernel_reg(Load_kernel_reg),

        .en_top_row_counter(en_top_row_counter),
        .rst_top_row_counter(rst_top_row_counter),

        .CHANNEL_SIZE(CHANNEL_SIZE),
        .IMAGE_SIZE(IMAGE_SIZE),

        // Control outputs
        .reg_last_chan(reg_last_chan),
        
        .last_loading_1ker(last_loading_1ker),
        .last_channel(last_channel),
        .Kernel_BRAM_IDLE(Kernel_BRAM_IDLE),

        .Done_1row(Done_1row),
        .Input_line_buffer_IDLE(Input_line_buffer_IDLE),
        .PE_ready(PE_ready),
        .PE_with_buffers_IDLE(PE_with_buffers_IDLE),
        .ena_bias_BRAM_addr_counter(ena_bias_BRAM_addr_counter),
        .rst_bias_BRAM_addr_counter(rst_bias_BRAM_addr_counter),
        .bias_BRAM_addr_counter_out(bias_BRAM_addr_counter_out),

        .top_row_counter_out(top_row_counter_out),

        // Data I/O AXI Stream
        .s_axis_tdata(s_axis_tdata),
        .m_axis_tdata(m_axis_tdata),

        // Data input bias from bias_BRAM (instantiated outside)
        .bias_in(bias_in),

        // AXI signals
        // Slave
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),

        // Master
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tready(m_axis_tready)
    );

    // Noise weight BRAM addr counter
    always @(posedge clk) begin
        if ((!Reset_top) || (!aresetn)) begin
            noise_weight_BRAM_counter_out <= 9'd0;
        end
        else begin
            if (noise_weight_BRAM_counter_out > CHANNEL_SIZE-1) begin // Reset if already more than channel size
                noise_weight_BRAM_counter_out <= 9'd0;
            end
            else if (ena_bias_BRAM_addr_counter) begin
                noise_weight_BRAM_counter_out <= noise_weight_BRAM_counter_out + 9'd1;
            end
            else begin
                noise_weight_BRAM_counter_out <= noise_weight_BRAM_counter_out;
            end
        end
    end

    // Start signal for generating noise from other module
    assign start_noise_gen = load_BRAM_dina;

endmodule