`timescale 1ns / 1ps

module tb_convolution_top_4x4;

    // ========================================================================
    // 1. PARAMETERS & CONFIGURATION
    // ========================================================================
    parameter PIXEL_WIDTH  = 16;
    parameter KERNEL_WIDTH = 16;
    parameter RESULT_WIDTH = 48; // Internal result width
    
    // User Configuration
    parameter IMG_SIZE     = 4;   // 4x4 Image
    parameter CHANNELS     = 256; // 256 Channels
    
    // File Names (Ensure these are in your simulation directory)
    parameter KERNEL_FILE  = "weight_conv_4x4.mem";
    parameter IMAGE_FILE   = "layer_input_4x4.mem";

    // ========================================================================
    // 2. SIGNALS
    // ========================================================================
    reg clk;
    reg aresetn;

    // Control Signals
    reg Load_kernel_BRAM;
    reg [7:0] Image_size_in;
    reg [8:0] Channel_size_in;

    // Kernel BRAM Interface (Simulating External Memory)
    wire [255:0] kernel_BRAM_doutb;
    wire enb_kernel_BRAM;
    wire [7:0] kernel_BRAM_counter_out;

    // Bias BRAM Interface (Fixed Bias for Test)
    reg [47:0] bias_BRAM_douta;
    wire ena_bias_BRAM_addr_counter;

    // AXI-Stream Slave (Input to FPGA)
    reg [15:0] s_axis_tdata;
    reg s_axis_tvalid;
    wire s_axis_tready;
    reg s_axis_tlast;

    // AXI-Stream Master (Output from FPGA)
    wire [63:0] m_axis_tdata;
    wire m_axis_tvalid;
    reg m_axis_tready;
    wire m_axis_tlast;

    // ========================================================================
    // 3. TESTBENCH MEMORIES (The "Golden" Data)
    // ========================================================================
    // Kernel Memory: 256 entries. Each entry is 144 bits (9 weights * 16 bits).
    // Note: We use 144 bits here. The top module expects 256 bits but only uses the bottom 144.
    reg [143:0] tb_kernel_mem [0:CHANNELS-1];
    
    // Image Memory: Stores all pixels for all channels linearly.
    // Size = 4 * 4 * 256 = 4096 pixels. 
    // We allocate more just in case the file is larger.
    reg [15:0] tb_image_mem [0:20000]; 

    // ========================================================================
    // 4. DUT INSTANTIATION
    // ========================================================================
    convolution_top_alt uut (
        .clk(clk),
        .aresetn(aresetn),
        
        // Configuration
        .Load_kernel_BRAM(Load_kernel_BRAM),
        .Image_size(Image_size_in),
        .Channel_size(Channel_size_in),
        
        // Kernel Interface
        .kernel_BRAM_doutb(kernel_BRAM_doutb),
        .enb_kernel_BRAM(enb_kernel_BRAM),
        .kernel_BRAM_counter_out(kernel_BRAM_counter_out),
        
        // Bias Interface
        .bias_BRAM_douta(bias_BRAM_douta),
        // .ena_bias_BRAM_addr_counter(ena_bias_BRAM_addr_counter), // Uncomment if port exists
        
        // AXI Stream Input
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        
        // AXI Stream Output
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // ========================================================================
    // 5. MOCK HARDWARE LOGIC
    // ========================================================================
    
    // Clock Generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Simulate External Kernel BRAM
    // When the Top Module asks for data (enb=1), we provide it from our array.
    // We pad the 144-bit data to 256 bits because the port is 256 bits wide.
    assign kernel_BRAM_doutb = (enb_kernel_BRAM) ? {112'b0, tb_kernel_mem[kernel_BRAM_counter_out]} : 256'd0;

    // ========================================================================
    // 6. MAIN TEST PROCESS
    // ========================================================================
    integer i, ch, r, c;
    integer pixel_idx;
    
    initial begin
        // --- A. Initialize Signals ---
        aresetn = 0;
        Load_kernel_BRAM = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        s_axis_tdata = 0;
        m_axis_tready = 1; // Always ready to receive result
        bias_BRAM_douta = 48'd0; // Zero bias for now
        Image_size_in = IMG_SIZE;
        Channel_size_in = CHANNELS;

        // --- B. Load .MEM Files ---
        $display("Loading Kernel File: %s", KERNEL_FILE);
        $readmemh(KERNEL_FILE, tb_kernel_mem);
        
        $display("Loading Image File: %s", IMAGE_FILE);
        $readmemh(IMAGE_FILE, tb_image_mem);

        // --- C. Reset Sequence ---
        $display("Applying Reset...");
        repeat(10) @(posedge clk);
        aresetn = 1;
        repeat(10) @(posedge clk);

        // --- D. Load Kernels Phase ---
        $display("Starting Kernel Loading Phase...");
        Load_kernel_BRAM = 1;
        
        // Wait for the Counter to wrap up to Channel Size
        // The CU will assert 'enb_kernel_BRAM' to read our mock memory
        wait (kernel_BRAM_counter_out == CHANNELS - 1);
        @(posedge clk);
        Load_kernel_BRAM = 0;
        
        $display("Kernel Loading Complete.");
        repeat(10) @(posedge clk);

        // --- E. Stream Input Image Phase ---
        $display("Starting Image Stream (4x4 x 256 Channels)...");
        
        pixel_idx = 0;
        
        // Loop through all channels
        for (ch = 0; ch < CHANNELS; ch = ch + 1) begin
            $display("  -> Streaming Channel %0d", ch);
            
            // Loop through Rows and Columns (4x4)
            for (r = 0; r < IMG_SIZE; r = r + 1) begin
                for (c = 0; c < IMG_SIZE; c = c + 1) begin
                    
                    // Drive Data
                    s_axis_tvalid = 1;
                    s_axis_tdata  = tb_image_mem[pixel_idx];
                    
                    // TLAST Logic: Only on the very last pixel of the CURRENT channel? 
                    // Or usually TLAST is per packet (frame).
                    // Assuming TLAST is asserted at the end of every 4x4 frame (channel).
                    if (r == IMG_SIZE-1 && c == IMG_SIZE-1)
                        s_axis_tlast = 1;
                    else
                        s_axis_tlast = 0;

                    // Handshake: Wait for Ready
                    @(posedge clk);
                    while (!s_axis_tready) @(posedge clk);
                    
                    pixel_idx = pixel_idx + 1;
                end
            end
            
            // End of Channel: Drop Valid
            s_axis_tvalid = 0;
            s_axis_tlast  = 0;
            
            // Small gap between channels (optional, but good for stability check)
            repeat(2) @(posedge clk);
        end
        
        $display("All Input Data Streamed. Waiting for output...");
        
        // Wait for output stream to finish
        // We set a timeout just in case
        repeat(1000) @(posedge clk);
        $display("Simulation Finished.");
        $stop;
    end

    // ========================================================================
    // 7. OUTPUT MONITOR
    // ========================================================================
    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            // Sign extend check or simply print hex
            $display("Time: %t | Output Pixel: %h | Last: %b", $time, m_axis_tdata, m_axis_tlast);
        end
    end

endmodule