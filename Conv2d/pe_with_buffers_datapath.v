`timescale 1ns / 1ps

module pe_with_buffers_datapath #(
    parameter PIXEL_WIDTH = 16,
    parameter KERNEL_WIDTH = 16,
    parameter RESULT_WIDTH = 48
) (
    // Data signals
    input wire signed [PIXEL_WIDTH-1:0] x00, x01, x02,
    input wire signed [PIXEL_WIDTH-1:0] x10, x11, x12,
    input wire signed [PIXEL_WIDTH-1:0] x20, x21, x22,
    input wire [9*KERNEL_WIDTH-1:0] kernel_flat,
    input wire signed [RESULT_WIDTH-1:0] bias,
    output wire signed [RESULT_WIDTH-1:0] BRAM_doutb,

    // Control signals
    input wire clk,
    input wire Wr_kernel,
    input wire Rst_kernel,
    input wire [13:0] addra_output_BRAM, // Address for write port A
    input wire [13:0] addrb_output_BRAM, // Address for read port B
    input wire add_bias,

    // Output BRAM controls
    input wire ena_output_BRAM,
    input wire wea_output_BRAM,
    input wire enb_output_BRAM // Write port b not used
);

    wire signed [RESULT_WIDTH-1:0] result_mult_add;
    // Instantiate Multiplier-Adder Unit
    multiplier_adder #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .KERNEL_WIDTH(KERNEL_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) mult_add_inst (
        .x00(x00), .x01(x01), .x02(x02),
        .x10(x10), .x11(x11), .x12(x12),
        .x20(x20), .x21(x21), .x22(x22),
        .k00(kernel[0]), .k01(kernel[1]), .k02(kernel[2]),
        .k10(kernel[3]), .k11(kernel[4]), .k12(kernel[5]),
        .k20(kernel[6]), .k21(kernel[7]), .k22(kernel[8]),
        .result(result_mult_add)
    );

    // Bagian kernel register
    reg signed [15:0] kernel [0:8]; // 9 kernel values of 16 bits each

    // Unflatten kernel input into 2D array
    integer i;
    integer j;
    integer k;
    always @(posedge clk) begin
        if (!Rst_kernel) begin
            for (i = 0; i < 9; i = i + 1) begin
                kernel[i] <= 16'd0;
            end
        end 
        else begin
            if (Wr_kernel) begin
                for (j = 0; j < 9; j = j + 1) begin
                    kernel[j] <= kernel_flat[(9-j)*KERNEL_WIDTH-1 -: KERNEL_WIDTH]; // Extract each kernel value, reversed
                end
            end
            else begin
                // Retain previous kernel values
                for (k = 0; k < 9; k = k + 1) begin
                    kernel[k] <= kernel[k];
                end
            end
        end
    end

    // Bagian mux pemilih jumlah bias
    wire signed [RESULT_WIDTH-1:0] BRAM_douta;
    wire signed [RESULT_WIDTH-1:0] in_2_accumulator;
    assign in_2_accumulator = add_bias ? bias : BRAM_douta;

    // Bagian depan accumulator dina
    wire signed [RESULT_WIDTH-1:0] accumulator_out;
    assign accumulator_out = result_mult_add + in_2_accumulator;

    // Bagian output BRAM, instantiate true dual-port BRAM
    true_dual_port_bram #(
        .RAM_WIDTH(RESULT_WIDTH),
        .RAM_DEPTH(16384) // Depth for 128x128 output, address width auto adjusted by RAM_DEPTH
    ) output_BRAM (
        // Port A
        .clka(clk),
        .ena(ena_output_BRAM),
        .wea(wea_output_BRAM),
        .addra(addra_output_BRAM),
        .dina(accumulator_out),
        .douta(BRAM_douta),

        // Port B
        .clkb(clk),
        .enb(enb_output_BRAM),
        .web(1'b0), // No write on port B
        .addrb(addrb_output_BRAM),
        .dinb( {RESULT_WIDTH{1'b0}} ), // No data input on port B
        .doutb(BRAM_doutb)
    );

endmodule