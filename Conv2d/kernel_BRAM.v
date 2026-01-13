`timescale 1ns / 1ps

module kernel_BRAM #(
    parameter KERNEL_WIDTH = 16
) (
    // Control inputs
    input wire clk,
    input wire Reset,
    input wire load_BRAM_dina,
    input wire update_BRAM_doutb,
    input wire [8:0] CHANNEL_SIZE,
    // input wire [7:0] a_counter_output, // from inside this module
    // input wire [7:0] b_counter_output,
    input wire s_axis_tvalid,
    input wire s_axis_tlast, // Not used

    // Control output interface for other blocks
    output wire done_loading_1ker,
    output wire last_channel,
    output wire s_axis_tready,

    // Data ports
    input wire [143:0] kernel_BRAM_dina,
    output wire [143:0] kernel_BRAM_doutb
);
    
    // Wires
    wire ena_ker_BRAM;
    wire wea_ker_BRAM;
    wire enb_ker_BRAM;
    wire enb_ker_BRAM_counter;
    wire rstb_ker_BRAM_counter;
    wire ena_ker_BRAM_counter;
    wire rsta_ker_BRAM_counter;

    wire [7:0] a_counter_output;
    wire [7:0] b_counter_output;

    // Instantiate address counters
    // Counter for port a address
    counter #(
        .BITWIDTH(8)
    ) ADDRA_COUNTER (
        .enable(ena_ker_BRAM_counter),
        .reset(rsta_ker_BRAM_counter),
        .clk(clk),
        .counter_out(a_counter_output)
    );

    // Counter for port b address
    counter #(
        .BITWIDTH(8)
    ) ADDRA_COUNTER (
        .enable(enb_ker_BRAM_counter),
        .reset(rstb_ker_BRAM_counter),
        .clk(clk),
        .counter_out(b_counter_output)
    );

    // Instantiate CU
    kernel_BRAM_CU kernel_BRAM_CONTROL (
        // Control inputs
        .clk(clk),
        .Reset(Reset),
        .load_BRAM_dina(load_BRAM_dina),
        .update_BRAM_doutb(update_BRAM_doutb),
        .CHANNEL_SIZE(CHANNEL_SIZE),
        .a_counter_output(a_counter_output),
        .b_counter_output(b_counter_output),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast), // Not used

        // Control outputs
        .done_loading_1ker(done_loading_1ker),
        .last_channel(last_channel),
        .ena_ker_BRAM(ena_ker_BRAM),
        .wea_ker_BRAM(wea_ker_BRAM),
        .enb_ker_BRAM(enb_ker_BRAM),
        .enb_ker_BRAM_counter(enb_ker_BRAM_counter),
        .rstb_ker_BRAM_counter(rstb_ker_BRAM_counter),
        .ena_ker_BRAM_counter(ena_ker_BRAM_counter),
        .rsta_ker_BRAM_counter(rsta_ker_BRAM_counter),
        .s_axis_tready(s_axis_tready)
    );

    // Instantiate datapath
    kernel_BRAM_datapath #(
        .KERNEL_WIDTH(KERNEL_WIDTH)
    ) DATAPATH (
        // Controls
        .clk(clk),
        .ena_kernel_BRAM(ena_ker_BRAM),
        .wea_kernel_BRAM(wea_ker_BRAM),
        .enb_kernel_BRAM(enb_ker_BRAM),

        // Address input
        .kernel_BRAM_addra(a_counter_output),
        .kernel_BRAM_addrb(b_counter_output),
        
        // Data
        .kernel_BRAM_dina(kernel_BRAM_dina),
        .kernel_BRAM_doutb(kernel_BRAM_doutb)
    );

endmodule