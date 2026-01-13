// NOTE(TO DO): Belum dikasih bagian add noise dan LeakyReLu 
`timescale 1ns / 1ps

module convolution_top (
    input  wire        clk,
    input  wire        aresetn,

    // Input control unit
    input wire Load_kernel_BRAM,
    input wire [7:0] Image_size, // (4, 8, 16, 32, 64, or 128)
    input wire [8:0] Channel_size, // (256, 128, or 64)
    // Counter from inside this module
    // input wire [6:0] window_BRAM_counter_out,
    // input wire [13:0] a_output_BRAM_counter_out,
    // input wire [13:0] b_output_BRAM_counter_out,
    // input wire [7:0] in_row_counter,
    // input wire [7:0] in_col_counter,

    // Kernel input from kernel BRAM
    input wire [255:0] kernel_BRAM_doutb,

    // Kernel BRAM control output
    output wire enb_kernel_BRAM, // kernel BRAM outside this module
    output wire [7:0] kernel_BRAM_counter_out, // kernel BRAM counter inside this module

    // Bias BRAM input (Bias BRAM outside this module)
    input wire [47:0] bias_BRAM_douta,

    // Bias BRAM controls
    output wire ena_bias_BRAM_addr_counter,
    output wire rsta_bias_BRAM_addr_counter,

    // Slave AXI-Stream Interfacew
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

// Control Unit Wires
// Kernel BRAM wires
wire rstb_kernel_BRAM_addr_counter;
wire enb_kernel_BRAM_addr_counter;

// Kernel register wires
wire Wr_kernel;
wire Rst_kernel;

// Window registers wires
wire Rst_window;
wire Wr_window;
wire Shift_window;

// Window MUX wires
wire window_row_n_2_mux;
wire window_row_n_1_mux;
wire window_row_n_mux;

// Window BRAM wires
wire rstb_window_BRAM_addr_counter;
wire enb_window_BRAM_addr_counter;
wire enb_window_BRAM;
wire wea_window_BRAM;

// Output BRAM wires
wire rsta_output_BRAM_addr_counter;
wire ena_output_BRAM_addr_counter;
wire rstb_output_BRAM_addr_counter;
wire enb_output_BRAM_addr_counter;

wire wea_output_BRAM;
wire ena_output_BRAM;

wire enb_output_BRAM;

wire add_bias;

// Input BRAM buffers wires
wire en_in_row_counter;
wire en_in_col_counter;
wire rst_in_row_counter;
wire rst_in_col_counter;

// in_row_counter, Input buffer (line buffer) row counter
wire [7:0] in_row_counter_o;

// in_col_counter, Input buffer (line buffer) col counter
wire [7:0] in_col_counter_o;

// Window BRAM n-1 doutb
wire [15:0] window_bram_n_1_doutb;
wire [15:0] window_bram_n_2_doutb;

// MUX for window input
reg [15:0] in_window_row_n_2;
reg [15:0] in_window_row_n_1;
reg [15:0] in_window_row_n;

// Window output wires
wire signed [15:0] out_window_00;
wire signed [15:0] out_window_01;
wire signed [15:0] out_window_02;
wire signed [15:0] out_window_10;
wire signed [15:0] out_window_11;
wire signed [15:0] out_window_12;
wire signed [15:0] out_window_20;
wire signed [15:0] out_window_21;
wire signed [15:0] out_window_22;

// Wire for output BRAM
wire signed [47:0] output_BRAM_doutb;

// Wires for counter outputs
wire [6:0] window_BRAM_counter_out;
wire [13:0] a_output_BRAM_counter_out;
wire [13:0] b_output_BRAM_counter_out;

// Address Counters for BRAM(s)
// Kernel BRAM addr counter
counter #(
    .BITWIDTH(8)
) kernel_BRAM_counter (
    .clk(clk),
    .reset(rstb_kernel_BRAM_addr_counter),
    .enable(enb_kernel_BRAM_addr_counter),
    .counter_out(kernel_BRAM_counter_out)
);

// Window BRAM counter
counter #(
    .BITWIDTH(7)
) window_BRAM_counter (
    .clk(clk),
    .reset(rstb_window_BRAM_addr_counter),
    .enable(enb_window_BRAM_addr_counter),
    .counter_out(window_BRAM_counter_out)
);

// a_output_BRAM_counter_out, Output BRAM port a addr counter
counter #(
    .BITWIDTH(14)
) a_output_BRAM_counter (
    .clk(clk),
    .reset(rsta_output_BRAM_addr_counter),
    .enable(ena_output_BRAM_addr_counter),
    .counter_out(a_output_BRAM_counter_out)
);

// b_output_BRAM_counter_out, Output BRAM port b addr counter
counter #(
    .BITWIDTH(14)
) b_output_BRAM_counter (
    .clk(clk),
    .reset(rstb_output_BRAM_addr_counter),
    .enable(enb_output_BRAM_addr_counter),
    .counter_out(b_output_BRAM_counter_out)
);

counter #(
    .BITWIDTH(8)
) in_row_counter (
    .clk(clk),
    .reset(rst_in_row_counter),
    .enable(en_in_row_counter),
    .counter_out(in_row_counter_o)
);

counter #(
    .BITWIDTH(8)
) in_col_counter (
    .clk(clk),
    .reset(rst_in_col_counter),
    .enable(en_in_col_counter),
    .counter_out(in_col_counter_o)
);

// Control Unit
convolution_top_CU CU (
    // Input signals
    .aresetn(aresetn),
    .clk(clk),
    .Load_kernel_BRAM(Load_kernel_BRAM),
    .Image_size(Image_size),
    .Channel_size(Channel_size),
    .kernel_BRAM_counter_out(kernel_BRAM_counter_out),
    .window_BRAM_counter_out(window_BRAM_counter_out),
    .a_output_BRAM_counter_out(a_output_BRAM_counter_out),
    .b_output_BRAM_counter_out(b_output_BRAM_counter_out),
    .in_row_counter(in_row_counter_o),
    .in_col_counter(in_col_counter_o),
    .s_axis_tvalid(s_axis_tvalid),
    .s_axis_tlast(s_axis_tlast),
    .m_axis_tready(m_axis_tready),

    // Output control signals
    // Kernel controls
    .Wr_kernel(Wr_kernel),
    .Rst_kernel(Rst_kernel),

    // Convolution window controls
    .Rst_window(Rst_window),
    .Wr_window(Wr_window),
    .Shift_window(Shift_window),
    .window_row_n_2_mux(window_row_n_2_mux),
    .window_row_n_1_mux(window_row_n_1_mux),
    .window_row_n_mux(window_row_n_mux),

    // Kernel BRAM controls
    .enb_kernel_BRAM(enb_kernel_BRAM),
    .enb_kernel_BRAM_addr_counter(enb_kernel_BRAM_addr_counter),
    .rstb_kernel_BRAM_addr_counter(rstb_kernel_BRAM_addr_counter),

    // Window BRAM controls
    .enb_window_BRAM(enb_window_BRAM),
    .wea_window_BRAM(wea_window_BRAM),
    .enb_window_BRAM_addr_counter(enb_window_BRAM_addr_counter),
    .rstb_window_BRAM_addr_counter(rstb_window_BRAM_addr_counter),

    // Bias controls
    .add_bias(add_bias),
    .ena_bias_BRAM_addr_counter(ena_bias_BRAM_addr_counter),
    .rsta_bias_BRAM_addr_counter(rsta_bias_BRAM_addr_counter),

    // Output BRAM controls port a
    .ena_output_BRAM(ena_output_BRAM),
    .wea_output_BRAM(wea_output_BRAM),
    .ena_output_BRAM_addr_counter(ena_output_BRAM_addr_counter),
    .rsta_output_BRAM_addr_counter(rsta_output_BRAM_addr_counter),

    // Output BRAM controls port b
    .enb_output_BRAM(enb_output_BRAM),
    .enb_output_BRAM_addr_counter(enb_output_BRAM_addr_counter),
    .rstb_output_BRAM_addr_counter(rstb_output_BRAM_addr_counter),

    // Col and row counters
    .en_in_row_counter(en_in_row_counter),
    .en_in_col_counter(en_in_col_counter),
    .rst_in_row_counter(rst_in_row_counter),
    .rst_in_col_counter(rst_in_col_counter),

    // AXI-Stream Output controls
    .s_axis_tready(s_axis_tready),
    .m_axis_tvalid(m_axis_tvalid),
    .m_axis_tlast(m_axis_tlast)
);

// Line buffers part
// Instantiate true dual port bram for input FIFO (line buffer)
true_dual_port_bram #(
    .RAM_WIDTH(16),
    .RAM_DEPTH(128)
) line_buffer_n_1 (
    // Port A
    .clka(clk),   // Clock A
    .ena(enb_window_BRAM),    // Enable A (Active High)
    .wea(wea_window_BRAM),    // Write Enable A (Active High)
    .addra(window_BRAM_counter_out),  // Address A
    .dina(in_window_row_n),   // Data In A from MUX row n
    .douta(),  // Data Out A not used

    // Port B
    .clkb(clk),   // Clock B
    .enb(enb_window_BRAM),    // Enable B (Active High)
    .web(1'b0),    // Write Enable B (Active High), not used
    .addrb(window_BRAM_counter_out),  // Address B
    .dinb(),   // Data In B not used
    .doutb(window_bram_n_1_doutb)   // Data Out B
);

true_dual_port_bram #(
    .RAM_WIDTH(16),
    .RAM_DEPTH(128)
) line_buffer_n_2 (
    // Port A
    .clka(clk),   // Clock A
    .ena(enb_window_BRAM),    // Enable A (Active High)
    .wea(wea_window_BRAM),    // Write Enable A (Active High)
    .addra(window_BRAM_counter_out),  // Address A
    .dina(in_window_row_n_1),   // Data In A from line buffer n-1
    .douta(),  // Data Out A not used

    // Port B
    .clkb(clk),   // Clock B
    .enb(enb_window_BRAM),    // Enable B (Active High)
    .web(1'b0),    // Write Enable B (Active High), not used
    .addrb(window_BRAM_counter_out),  // Address B
    .dinb(),   // Data In B not used
    .doutb(window_bram_n_2_doutb)   // Data Out B
);

// MUX for input window
always @(*) begin
    if (window_row_n_mux) begin
        in_window_row_n <= s_axis_tdata;
    end
    else begin
        in_window_row_n <= 0;
    end
end

always @(*) begin
    if (window_row_n_1_mux) begin
        in_window_row_n_1 <= window_bram_n_1_doutb;
    end
    else begin
        in_window_row_n_1 <= 0;
    end
end

always @(*) begin
    if (window_row_n_2_mux) begin
        in_window_row_n_2 <= window_bram_n_2_doutb;
    end
    else begin
        in_window_row_n_2 <= 0;
    end
end

// Window register 3x3 pixels for convolution input
// Window instantiation
window_reg_3x3 #(
    .DATA_WIDTH(16)
) window (
    .clk(clk),

    // Control signals
    .Wr_window(Wr_window),
    .Shift_window(Shift_window),
    .Rst_window(Rst_window),

    // Inputs
    .in_row_n(in_window_row_n),
    .in_row_n_1(in_window_row_n_1),
    .in_row_n_2(in_window_row_n_2),

    // Outputs
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

// Convolution PE Part
// Instantiate PE with buffers
pe_with_buffers CONV_ENGINE (
    // Data signals
    .x00(out_window_02),
    .x01(out_window_01),
    .x02(out_window_00),
    .x10(out_window_12),
    .x11(out_window_11),
    .x12(out_window_10),
    .x20(out_window_22),
    .x21(out_window_21),
    .x22(out_window_20),
    .kernel_flat(kernel_BRAM_doutb[143:0]),
    .bias(bias_BRAM_douta),
    .BRAM_doutb(output_BRAM_doutb),

    // Control signals
    .clk(clk),
    .Wr_kernel(Wr_kernel),
    .Rst_kernel(Rst_kernel),
    .addra_output_BRAM(a_output_BRAM_counter_out), // Address for write port A
    .addrb_output_BRAM(b_output_BRAM_counter_out), // Address for read port B
    .add_bias(add_bias),

    // Output BRAM controls
    .ena_output_BRAM(ena_output_BRAM),
    .wea_output_BRAM(wea_output_BRAM),
    .enb_output_BRAM(enb_output_BRAM)
);

// Note: buat sekarang simulasi dulu bagian konvolusi tanpa add noise
// Assign output wires
assign m_axis_tdata = {{16{output_BRAM_doutb[47]}}, output_BRAM_doutb};

endmodule