`timescale 1ns / 1ps

module pe_with_buffers #(
    parameter PIXEL_WIDTH = 16,
    parameter KERNEL_WIDTH = 16,
    parameter RESULT_WIDTH = 48
) (
    input wire clk,
    // Data I/O
    input wire signed [PIXEL_WIDTH-1:0] x00, x01, x02,
    input wire signed [PIXEL_WIDTH-1:0] x10, x11, x12,
    input wire signed [PIXEL_WIDTH-1:0] x20, x21, x22,
    input wire [9*KERNEL_WIDTH-1:0] kernel_flat,
    input wire signed [RESULT_WIDTH-1:0] bias,
    output wire signed [RESULT_WIDTH-1:0] accumulator_out,

    // Control signals
    // From inside this module
    // input wire Wr_kernel,
    // input wire Rst_kernel,
    // input wire [13:0] addra_output_BRAM, // Address for write port A
    // input wire [13:0] addrb_output_BRAM, // Address for read port B
    // input wire add_bias,

    // Control inputs
    input wire Reset,
    input wire [7:0] b_counter_output,
    input wire Load_kernel_reg,
    input wire Stream_mid_row,
    input wire Stream_last_row,
    input wire Output_valid,
    input wire Done_1row,
    input wire last_channel,

    input wire m_axis_tready,

    // Output BRAM controls
    // From inside this module
    // input wire ena_output_BRAM,
    // input wire wea_output_BRAM,
    // input wire enb_output_BRAM // Write port b not used
    output wire ena_bias_BRAM_addr_counter,
    output wire rst_bias_BRAM_addr_counter,

    // AXI signalsm_axis_tvalid
    output wire m_axis_tvalid,
    output wire m_axis_tlast,

    // Controls output interface
    output wire PE_ready,
    output wire PE_with_buffers_IDLE,

    // Output BRAM address counter output for noise BRAM counter (same)
    output wire [13:0] output_BRAM_counter_out
);

    // Wires
    wire Wr_kernel;
    wire Rst_kernel;
    wire add_bias;

    wire ena_output_BRAM;
    wire wea_output_BRAM;
    wire enb_output_BRAM;

    wire ena_output_BRAM_counter;
    wire rsta_output_BRAM_counter;
    wire [14:0] a_output_BRAM_counter_out;

    wire [13:0] addra_output_BRAM;
    wire [13:0] addrb_output_BRAM;

    // Assign addra_output_BRAM and addrb_output_BRAM
    assign addra_output_BRAM = a_output_BRAM_counter_out[13:0];
    assign addrb_output_BRAM = addra_output_BRAM;
    assign output_BRAM_counter_out = addra_output_BRAM;

    // Instantiate counters
    counter #(
        .BITWIDTH(15)
    ) OUTPUT_BRAM_ADDRA_COUNTER (
        .enable(ena_output_BRAM_counter),
        .reset(rsta_output_BRAM_counter),
        .clk(clk),
        .counter_out(a_output_BRAM_counter_out)
    );

    // Instantiate CU
    pe_with_buffers_CU PE_WITH_BUFFERS_CONTROL (
        .clk(clk),
        .Reset(Reset),

        // Input interface from other submodules
        .b_counter_output(b_counter_output),
        .Load_kernel_reg(Load_kernel_reg),
        .Stream_mid_row(Stream_mid_row),
        .Stream_last_row(Stream_last_row),
        .Output_valid(Output_valid),
        .Done_1row(Done_1row),
        .last_channel(last_channel),
        .a_output_BRAM_counter_out(a_output_BRAM_counter_out), // Add one bit for extending
        .m_axis_tready(m_axis_tready),

        // Control outputs
        // Interface outputs
        // AXI signals
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),

        .PE_ready(PE_ready),
        .PE_with_buffers_IDLE(PE_with_buffers_IDLE),

        .ena_bias_BRAM_addr_counter(ena_bias_BRAM_addr_counter),
        .rst_bias_BRAM_addr_counter(rst_bias_BRAM_addr_counter),
        
        // Internal outputs
        .add_bias(add_bias),

        .Wr_kernel(Wr_kernel),
        .Rst_kernel(Rst_kernel),

        .ena_output_BRAM(ena_output_BRAM),
        .wea_output_BRAM(wea_output_BRAM),
        .enb_output_BRAM(enb_output_BRAM),

        .ena_output_BRAM_counter(ena_output_BRAM_counter),
        .rsta_output_BRAM_counter(rsta_output_BRAM_counter)
    );

    // Instantiate datapath
    pe_with_buffers_datapath #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .KERNEL_WIDTH(KERNEL_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) DATAPATH (
        // Data signals
        .x00(x00),
        .x01(x01),
        .x02(x02),
        .x10(x10),
        .x11(x11),
        .x12(x12),
        .x20(x20),
        .x21(x21),
        .x22(x22),

        .kernel_flat(kernel_flat),
        .bias(bias),
        .accumulator_out(accumulator_out),

        // Control signals
        .clk(clk),
        .Wr_kernel(Wr_kernel),
        .Rst_kernel(Rst_kernel),
        .addra_output_BRAM(addra_output_BRAM), // Address for write port A
        .addrb_output_BRAM(addrb_output_BRAM), // Address for read port B
        .add_bias(add_bias),

        // Output BRAM controls
        .ena_output_BRAM(ena_output_BRAM),
        .wea_output_BRAM(wea_output_BRAM),
        .enb_output_BRAM(enb_output_BRAM) // Write port b not used
    );
    
endmodule