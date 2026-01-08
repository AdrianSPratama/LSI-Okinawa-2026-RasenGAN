module convolution_top (
    input  wire        clk,
    input  wire        aresetn,

    // Input control unit
    input wire Load_kernel_BRAM,
    input wire [7:0] Image_size, // (4, 8, 16, 32, 64, or 128)
    input wire [8:0] Channel_size, // (256, 128, or 64)
    input wire [7:0] kernel_BRAM_counter_out,
    input wire [6:0] window_BRAM_counter_out,
    input wire [13:0] a_output_BRAM_counter_out,
    input wire [13:0] b_output_BRAM_counter_out,
    input wire [7:0] in_row_counter,
    input wire [7:0] in_col_counter,

    // Kernel input from kernel BRAM
    input wire [255:0] kernel_BRAM_doutb,

    // Slave AXI-Stream Interface
    input  wire [15:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // Master AXI-Stream Interface
    output wire [63:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

endmodule