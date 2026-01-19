`timescale 1ns / 1ps

module input_line_buffer_datapath #(
    parameter DATA_WIDTH = 16
) (
    // Data ports
    input wire signed [DATA_WIDTH-1:0] dina,
    output wire signed [DATA_WIDTH-1:0] out_window_00, out_window_01, out_window_02,
    output wire signed [DATA_WIDTH-1:0] out_window_10, out_window_11, out_window_12,
    output wire signed [DATA_WIDTH-1:0] out_window_20, out_window_21, out_window_22,

    // Control signals
    // Window register control signals
    input wire clk,
    input wire Wr_window, Shift_window, Rst_window,
    input wire window_row_n_mux, window_row_n_1_mux, window_row_n_2_mux,

    // Line buffer BRAM control signals
    input wire ena_linebuff_BRAM, wea_linebuff_BRAM,
    input wire enb_linebuff_BRAM, 

    // Line buffer BRAM counter control signals
    input wire en_linebuff_BRAM_counter, rst_linebuff_BRAM_counter,
    output wire [6:0] linebuff_BRAM_counter_out // Max image size 128, counter 7 bit
);
    
    // Define wires
    // Line buffer BRAM wires
    wire signed [DATA_WIDTH-1:0] linebuff_n_1_doutb;
    wire signed [DATA_WIDTH-1:0] linebuff_n_2_doutb;

    // Define MUXes
    // MUX row n
    wire signed [DATA_WIDTH-1:0] mux_row_n_out;
    assign mux_row_n_out = window_row_n_mux ? dina : 0;

    // MUX row n-1
    wire signed [DATA_WIDTH-1:0] mux_row_n_1_out;
    assign mux_row_n_1_out = window_row_n_1_mux ? linebuff_n_1_doutb : 0;

    // MXU row n-1
    wire signed [DATA_WIDTH-1:0] mux_row_n_2_out;
    assign mux_row_n_2_out = window_row_n_2_mux ? linebuff_n_2_doutb : 0; 

    // Instantiate counters
    counter #(
        .BITWIDTH(7)
    ) LINEBUFF_BRAM_COUNTER (
        .enable(en_linebuff_BRAM_counter),
        .reset(rst_linebuff_BRAM_counter),
        .clk(clk),
        .counter_out(linebuff_BRAM_counter_out)
    );

    // Instantiate window_reg_3x3
    window_reg_3x3 #(
        .DATA_WIDTH(DATA_WIDTH)
    ) WINDOW_REG (
        .clk(clk),
        .Wr_window(Wr_window),
        .Shift_window(Shift_window),
        .Rst_window(Rst_window),
        .in_row_n(mux_row_n_out),
        .in_row_n_1(mux_row_n_1_out),
        .in_row_n_2(mux_row_n_2_out),

        // Output from every register
        .out_window_00(out_window_00),
        .out_window_01(out_window_01), 
        .out_window_02(out_window_02),
        .out_window_10(out_window_10),
        .out_window_11(out_window_11), 
        .out_window_12(out_window_12),
        .out_window_20(out_window_20),
        .out_window_21(out_window_21), 
        .out_window_22(out_window_22)
    );


    // Instantiate line buffers
    true_dual_port_bram #(
        .RAM_WIDTH(DATA_WIDTH),               // Data width (e.g., 32-bit)
        .RAM_DEPTH(128)                     // Memory depth, max image size 128
    ) LINE_BUFFER_N_1_BRAM (
        // Port A
        .clka(~clk),   // Clock A, using inverted clock so reading timing is not delayed
        .ena(ena_linebuff_BRAM),    // Enable A (Active High)
        .wea(wea_linebuff_BRAM),    // Write Enable A (Active High)
        .addra(linebuff_BRAM_counter_out),  // Address A
        .dina(mux_row_n_out),   // Data In A 
        .douta(),  // Data Out A not used

        // Port B
        .clkb(~clk),   // Clock B
        .enb(enb_linebuff_BRAM),    // Enable B (Active High)
        .web(1'b0),    // Write Enable B (Active High) not used, always 0
        .addrb(linebuff_BRAM_counter_out),  // Address B
        .dinb(),   // Data In B not used
        .doutb(linebuff_n_1_doutb)   // Data Out B
    );

    true_dual_port_bram #(
        .RAM_WIDTH(DATA_WIDTH),               // Data width (e.g., 32-bit)
        .RAM_DEPTH(128)                     // Memory depth, max image size 128
    ) LINE_BUFFER_N_2_BRAM (
        // Port A
        .clka(~clk),   // Clock A, using inverted clock so reading timing is not delayed
        .ena(ena_linebuff_BRAM),    // Enable A (Active High)
        .wea(wea_linebuff_BRAM),    // Write Enable A (Active High)
        .addra(linebuff_BRAM_counter_out),  // Address A
        .dina(mux_row_n_1_out),   // Data In A 
        .douta(),  // Data Out A not used

        // Port B
        .clkb(~clk),   // Clock B
        .enb(enb_linebuff_BRAM),    // Enable B (Active High)
        .web(1'b0),    // Write Enable B (Active High) not used, always 0
        .addrb(linebuff_BRAM_counter_out),  // Address B
        .dinb(),   // Data In B not used
        .doutb(linebuff_n_2_doutb)   // Data Out B
    );

endmodule