`timescale 1ns / 1ps

module convolution_top_alt (
    input  wire        clk,
    input  wire        aresetn,

    // --- Configuration / Control ---
    input wire         Load_kernel_BRAM,
    input wire [7:0]   Image_size,    // e.g., 128
    input wire [8:0]   Channel_size,  // e.g., 256

    // --- AXI-Stream Slave (Input Pixels) ---
    input  wire [15:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // --- AXI-Stream Master (Output Pixels) ---
    output wire [63:0] m_axis_tdata, // 64-bit to handle padding if needed, or valid data
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    // --- Kernel BRAM Interface ---
    // (Assuming external BRAM or BRAM Controller)
    input  wire [255:0] kernel_BRAM_doutb,
    output wire         enb_kernel_BRAM,       // Read Enable
    output wire [7:0]   kernel_BRAM_counter_out, // Read Address

    // --- Bias BRAM Interface ---
    input  wire [47:0]  bias_BRAM_douta,
    output wire         ena_bias_BRAM_addr_counter // Address Counter Enable
);

    // =========================================================================
    // 1. SIGNAL DECLARATIONS (Fixing Implicit Wires)
    // =========================================================================
    
    // -- Control Unit Outputs --
    wire processing_done;
    wire Wr_kernel;
    wire Rst_kernel;
    wire Rst_window;
    wire Wr_window;
    wire Shift_window;
    wire window_row_n_mux_sel; // 1 = Zero Pad, 0 = Input Data
    wire [1:0] padding_mux_sel; // (Unused, logic handled by counters locally)
    wire add_bias;
    
    // Output BRAM Controls (Port A: Write/Accumulate, Port B: Stream Out)
    wire ena_output_BRAM, wea_output_BRAM;
    wire rsta_output_BRAM_addr_counter, ena_output_BRAM_addr_counter;
    wire enb_output_BRAM;
    wire rstb_output_BRAM_addr_counter, enb_output_BRAM_addr_counter;
    
    // -- Counter Outputs --
    wire [6:0]  window_BRAM_counter_out; // For Line Buffers (0-127)
    wire [13:0] a_output_BRAM_counter_out; // Write Address
    wire [13:0] b_output_BRAM_counter_out; // Read Address
    wire [7:0]  in_row_counter;
    wire [7:0]  in_col_counter;
    wire [8:0]  bias_BRAM_counter_out; // Added for Bias

    // -- Data Path Wires --
    wire [15:0] window_input_data;     // Input to Window Reg (Data or Zero)
    wire [15:0] line_buffer_1_out;
    wire [15:0] line_buffer_2_out;
    
    // Window Register Outputs
    wire signed [15:0] out_window_00, out_window_01, out_window_02;
    wire signed [15:0] out_window_10, out_window_11, out_window_12;
    wire signed [15:0] out_window_20, out_window_21, out_window_22;

    // Masked Window Outputs (for Horizontal Padding)
    wire signed [15:0] masked_00, masked_01, masked_02;
    wire signed [15:0] masked_10, masked_11, masked_12;
    wire signed [15:0] masked_20, masked_21, masked_22;
    
    // PE & Output BRAM
    wire signed [47:0] pe_result_doutb; // From PE to Output BRAM (unused direct wire)
    // Note: PE connects directly to BRAM instance inside PE module usually, 
    // but based on your pe_with_buffers, it instantiates the BRAM internally?
    // Let's check your pe_with_buffers.v...
    // output wire signed [RESULT_WIDTH-1:0] BRAM_doutb
    // It seems pe_with_buffers HAS the BRAM inside it. 
    wire signed [47:0] output_BRAM_read_data; // Data read from Output BRAM (Port B)


    // =========================================================================
    // 2. CONTROL UNIT INSTANTIATION
    // =========================================================================
    convolution_top_CU_alt CTRL_UNIT (
        .clk(clk),
        .aresetn(aresetn),
        
        // Config
        .Load_kernel_BRAM(Load_kernel_BRAM),
        .Image_size(Image_size),
        .Channel_size(Channel_size),
        
        // Status Inputs
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tready(m_axis_tready),
        
        // Counter Feedback
        .kernel_BRAM_counter_out(kernel_BRAM_counter_out),
        .in_row_counter(in_row_counter),
        .in_col_counter(in_col_counter),
        
        // Controls
        .processing_done(processing_done),
        .Wr_kernel(Wr_kernel),
        .Rst_kernel(Rst_kernel),
        .enb_kernel_BRAM(enb_kernel_BRAM),
        
        .Rst_window(Rst_window),
        .Wr_window(Wr_window),
        .Shift_window(Shift_window),
        .window_row_n_mux(window_row_n_mux_sel),
        .padding_mux_sel(padding_mux_sel), // Unused, we use counters below
        
        .add_bias(add_bias),
        
        .ena_output_BRAM(ena_output_BRAM),
        .wea_output_BRAM(wea_output_BRAM),
        .rsta_output_BRAM_addr_counter(rsta_output_BRAM_addr_counter),
        .ena_output_BRAM_addr_counter(ena_output_BRAM_addr_counter),
        
        .enb_output_BRAM(enb_output_BRAM),
        .rstb_output_BRAM_addr_counter(rstb_output_BRAM_addr_counter),
        .enb_output_BRAM_addr_counter(enb_output_BRAM_addr_counter),
        
        .s_axis_tready(s_axis_tready),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast)
    );

    // =========================================================================
    // 3. DATAPATH: VERTICAL PADDING MUX
    // =========================================================================
    // If CU says Pad (state PAD_TOP or PAD_BOTTOM), force 0. Otherwise use AXIS data.
    assign window_input_data = (window_row_n_mux_sel) ? 16'sd0 : s_axis_tdata;


    // =========================================================================
    // 4. COUNTERS
    // =========================================================================
    
    // Note: Counters in your library are Active Low Reset (if(!reset)).
    // The CU outputs Active High Reset signals (Rst_...). So we invert them (~).

    // Kernel Address Counter (0 to 255)
    counter #(8) counter_kernel_BRAM_addr (
        .clk(clk),
        .reset(~Rst_kernel), 
        .enable(enb_kernel_BRAM), // Increment when reading
        .counter_out(kernel_BRAM_counter_out)
    );

    // Window / Line Buffer Column Counter (0 to 127)
    // Used for line buffer addressing
    counter #(7) counter_window_BRAM_addr (
        .clk(clk),
        .reset(~Rst_window),
        .enable(Shift_window), // Increment when we shift/write window
        .counter_out(window_BRAM_counter_out)
    );

    // Image Row Counter (0 to Image_size-1)
    counter #(8) counter_in_row (
        .clk(clk),
        .reset(~Rst_window), // Reset with window reset
        .enable((in_col_counter == Image_size - 1) && Shift_window), // Inc at end of row
        .counter_out(in_row_counter)
    );

    // Image Col Counter (0 to Image_size-1)
    counter #(8) counter_in_col (
        .clk(clk),
        .reset(~Rst_window && !(in_col_counter == Image_size-1 && Shift_window)), 
        // Logic: Reset if global reset OR if we wrapped around
        // Actually, simple counter wraps automatically? Your counter doesn't wrap logic internally?
        // Let's assume standard behavior: we rely on wrapping or reset.
        // Better: Reset when count == Image_size-1.
        .enable(Shift_window),
        .counter_out(in_col_counter)
    );
    // **NOTE**: You might need to adjust counter_in_col logic inside counter.v 
    // to wrap at 'Image_size', or simply use the fact that 127+1 = 128 (bit 7 high)
    // For now, assuming Image_size=128, an 8-bit counter counts 0..255. 
    // You must reset it manually in CU or logic if not power of 2.
    // Since 128 is power of 2 (7 bits), 8-bit counter works fine if we look at lower 7 bits.

    // Output BRAM Write Address (Accumulator)
    counter #(14) counter_a_output_BRAM_addr (
        .clk(clk),
        .reset(~rsta_output_BRAM_addr_counter),
        .enable(ena_output_BRAM_addr_counter),
        .counter_out(a_output_BRAM_counter_out)
    );

    // Output BRAM Read Address (Stream Out)
    counter #(14) counter_b_output_BRAM_addr (
        .clk(clk),
        .reset(~rstb_output_BRAM_addr_counter),
        .enable(enb_output_BRAM_addr_counter),
        .counter_out(b_output_BRAM_counter_out)
    );
    
    // Bias Counter
    counter #(9) counter_bias (
        .clk(clk),
        .reset(aresetn), // Reset globally
        .enable(ena_bias_BRAM_addr_counter),
        .counter_out(bias_BRAM_counter_out)
    );


    // =========================================================================
    // 5. LINE BUFFERS (BRAMs)
    // =========================================================================
    
    // Line Buffer 1: Stores Row N-1
    true_dual_port_bram #(
        .RAM_WIDTH(16),
        .RAM_DEPTH(128) // 1 Row
    ) LINE_BUFFER_1 (
        .clka(clk),
        .ena(Wr_window),
        .wea(Wr_window),
        .addra(window_BRAM_counter_out),
        .dina(window_input_data), // Input Row
        .douta(), // Unused port A out
        
        .clkb(clk),
        .enb(1'b1), // Always read for window
        .web(1'b0),
        .addrb(window_BRAM_counter_out), // Read same address (simultaneous R/W)
        .dinb(16'd0),
        .doutb(line_buffer_1_out) // To Window Reg
    );

    // Line Buffer 2: Stores Row N-2
    true_dual_port_bram #(
        .RAM_WIDTH(16),
        .RAM_DEPTH(128)
    ) LINE_BUFFER_2 (
        .clka(clk),
        .ena(Wr_window),
        .wea(Wr_window),
        .addra(window_BRAM_counter_out),
        .dina(line_buffer_1_out), // Input from LB1
        .douta(),
        
        .clkb(clk),
        .enb(1'b1),
        .web(1'b0),
        .addrb(window_BRAM_counter_out),
        .dinb(16'd0),
        .doutb(line_buffer_2_out) // To Window Reg
    );

    // =========================================================================
    // 6. WINDOW REGISTER
    // =========================================================================
    window_reg_3x3 #(16) WINDOW_REG (
        .clk(clk),
        .Rst_window(~Rst_window), // Invert for active low internal logic
        .Wr_window(Wr_window),
        .Shift_window(Shift_window),
        .in_row_n(window_input_data),
        .in_row_n_1(line_buffer_1_out),
        .in_row_n_2(line_buffer_2_out),
        
        .out_window_00(out_window_00), .out_window_01(out_window_01), .out_window_02(out_window_02),
        .out_window_10(out_window_10), .out_window_11(out_window_11), .out_window_12(out_window_12),
        .out_window_20(out_window_20), .out_window_21(out_window_21), .out_window_22(out_window_22)
    );

    // =========================================================================
    // 7. HORIZONTAL PADDING (MASKING)
    // =========================================================================
    // Logic: If col_counter == 0, Mask Left Column (x02, x12, x22 in your reversed notation)
    // If col_counter == 127, Mask Right Column (x00, x10, x20)
    
    wire pad_left  = (in_col_counter == 0);
    wire pad_right = (in_col_counter == Image_size - 1); // 127

    assign masked_00 = (pad_right) ? 16'sd0 : out_window_00;
    assign masked_10 = (pad_right) ? 16'sd0 : out_window_10;
    assign masked_20 = (pad_right) ? 16'sd0 : out_window_20;

    assign masked_01 = out_window_01; // Center never masked horizontally
    assign masked_11 = out_window_11;
    assign masked_21 = out_window_21;

    assign masked_02 = (pad_left)  ? 16'sd0 : out_window_02;
    assign masked_12 = (pad_left)  ? 16'sd0 : out_window_12;
    assign masked_22 = (pad_left)  ? 16'sd0 : out_window_22;


    // =========================================================================
    // 8. PROCESSING ENGINE (PE)
    // =========================================================================
    // NOTE: pe_with_buffers contains the Output BRAM internally.
    pe_with_buffers #(
        .PIXEL_WIDTH(16),
        .KERNEL_WIDTH(16),
        .RESULT_WIDTH(48)
    ) CONV_ENGINE (
        .clk(clk),
        
        // Kernel Loading
        .Wr_kernel(Wr_kernel),
        .Rst_kernel(~Rst_kernel),
        // Fix bit-width mismatch: slice 144 bits from 256-bit bus
        .kernel_flat(kernel_BRAM_doutb[143:0]), 
        
        // Data Inputs (Masked Window)
        // Ensure mapping matches multiplier_adder expectations
        .x00(masked_02), .x01(masked_01), .x02(masked_00),
        .x10(masked_12), .x11(masked_11), .x12(masked_10),
        .x20(masked_22), .x21(masked_21), .x22(masked_20),
        
        // Bias
        .bias(bias_BRAM_douta), // 48-bit
        .add_bias(add_bias),
        
        // Output BRAM Controls
        .addra_output_BRAM(a_output_BRAM_counter_out), // Write/Accum Addr
        .addrb_output_BRAM(b_output_BRAM_counter_out), // Read Addr (Stream Out)
        
        .ena_output_BRAM(ena_output_BRAM),
        .wea_output_BRAM(wea_output_BRAM),
        .enb_output_BRAM(enb_output_BRAM),
        
        // Output Data (for Stream)
        .BRAM_doutb(output_BRAM_read_data)
    );

    // =========================================================================
    // 9. AXI MASTER OUTPUT
    // =========================================================================
    // Pack 48-bit result to 64-bit for AXI (Sign Extend)
    assign m_axis_tdata = {{16{output_BRAM_read_data[47]}}, output_BRAM_read_data};

endmodule