`timescale 1ns / 1ps

module tb_top_level_conv;

    // Variables
    parameter DATA_WIDTH = 16;
    parameter PIXEL_WIDTH = 16;
    parameter KERNEL_WIDTH = 16;
    parameter RESULT_WIDTH = 48;

    parameter IMAGE_SIZE = 4;
    parameter CHANNEL_SIZE = 256;

    parameter INPUT_MEM_FILE = "weight_and_image_input_4x4.mem";
    parameter OUTPUT_MEM_FILE = "result_conv_4x4.mem";

    integer DDR_INDEX;
    integer i;
    integer errors;

    // Control input reg (simulating AXI GPIO)
    reg clk;
    reg Reset_top;
    reg Load_kernel_BRAM;
    reg [1:0] CHANNEL_SIZE_choose;
    reg [2:0] IMAGE_SIZE_choose;

    // Control outputs
    wire ena_bias_BRAM_addr_counter;
    wire rst_bias_BRAM_addr_counter;
    wire [11:0] bias_BRAM_addr_counter_out;
    wire conv_DONE;

    // AXI control signals
    reg aresetn;

    reg s_axis_tvalid;
    reg s_axis_tlast;
    reg m_axis_tready;

    wire s_axis_tready;
    wire m_axis_tvalid;
    wire m_axis_tlast;

    // Data I/O
    // Array of reg for simulating DDR
    // This DDR is for receiving the output
    reg [63:0] captured_output_ram [0:1023]; 
    integer out_write_pointer;

    // This DDR contains 1 kernel in the upper indexes, and full input image after the kernel indexes
    reg [255:0] input_reg [0:(IMAGE_SIZE*IMAGE_SIZE*CHANNEL_SIZE+CHANNEL_SIZE)-1]; // Using 255 because s_axis_tdata is 256 bits
    // Data input (AXI slave wire)
    wire [255:0] s_axis_tdata;
    assign s_axis_tdata = input_reg[DDR_INDEX][255:0];

    // Data output (AXI master wire)
    wire [63:0] m_axis_tdata;

    // Bias input (for now it's the top output layer's bias)
    wire [15:0] bias_in;
    assign bias_in = 16'he1; // Assign to a spesific value for one output layer

    // Output memory for automated checking
    reg [63:0] result_reg [0:15];

    // Instantiate DUT
    top_level_conv #(
        .DATA_WIDTH(DATA_WIDTH),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .KERNEL_WIDTH(KERNEL_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) DUT (
        // Control inputs
        .clk(clk),
        // Input from AXI GPIO
        .Reset_top(Reset_top),
        .Load_kernel_BRAM(Load_kernel_BRAM),
        .CHANNEL_SIZE_choose(CHANNEL_SIZE_choose),
        .IMAGE_SIZE_choose(IMAGE_SIZE_choose),

        // Control outputs
        .ena_bias_BRAM_addr_counter(ena_bias_BRAM_addr_counter),
        .rst_bias_BRAM_addr_counter(rst_bias_BRAM_addr_counter),
        .bias_BRAM_addr_counter_out(bias_BRAM_addr_counter_out),
        .conv_DONE(conv_DONE),

        // Data I/O
        .bias_in(bias_in),
        .s_axis_tdata(s_axis_tdata),
        .m_axis_tdata(m_axis_tdata),

        // AXI Stream controls
        .aresetn(aresetn),

        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tready(m_axis_tready),

        .s_axis_tready(s_axis_tready),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast)
    );

    // Generate clock (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

        // --- Simulating DDR Write Logic ---
    // This behaves like a DMA writing data to memory
    initial out_write_pointer = 0;

    always @(posedge clk) begin
        // Check for AXI Stream Handshake (Valid + Ready)
        if (aresetn && m_axis_tvalid && m_axis_tready) begin
            
            // 1. Write the data to our "Mock DDR"
            captured_output_ram[out_write_pointer] = m_axis_tdata;
            
            // 2. Debug print to console (optional, helps verify it's working)
            $display("[DDR WRITE] Time: %0t | Addr: %0d | Data: %h", 
                     $time, out_write_pointer, m_axis_tdata);

            // 3. Increment the pointer for the next write
            out_write_pointer = out_write_pointer + 1;
        end
    end

    // Stimulus
    initial begin
        $readmemh(INPUT_MEM_FILE, input_reg);
        $readmemh(OUTPUT_MEM_FILE, result_reg);

        // Control inputs
        Reset_top = 1;
        Load_kernel_BRAM = 0;
        CHANNEL_SIZE_choose = 0;
        IMAGE_SIZE_choose = 0;

        // AXI control signals
        aresetn = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        m_axis_tready = 0;

        repeat (5) @(posedge clk);

        Reset_top = 1;
        aresetn = 1;

        repeat (5) @(posedge clk);

        Load_kernel_BRAM = 1;

        @(posedge clk);

        Load_kernel_BRAM = 0;

        repeat (10) @(posedge clk);

        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        m_axis_tready = 1;

        @(posedge clk);

        for (DDR_INDEX = 0; DDR_INDEX < (IMAGE_SIZE*IMAGE_SIZE*CHANNEL_SIZE+CHANNEL_SIZE); DDR_INDEX = DDR_INDEX + 1) begin
            s_axis_tvalid = 1;

            // Give s_axis_tlast signal
            if (DDR_INDEX == (IMAGE_SIZE*IMAGE_SIZE*CHANNEL_SIZE+CHANNEL_SIZE)-1) begin
                s_axis_tlast = 1;
            end
            else begin
                s_axis_tlast = 0;
            end

            @(posedge clk);

            // Waiting for s_axis_tready
            while (s_axis_tready == 0) begin
                @(posedge clk);
            end 
        end

        s_axis_tlast = 0;
        s_axis_tvalid = 0;
        repeat (100) @(posedge clk);

        // ... (Your existing wait delays) ...
        
        // ---------------------------------------------------------
        // SELF-CHECK ROUTINE
        // ---------------------------------------------------------
        $display("\n");
        $display("---------------------------------------------------------");
        $display("STARTING AUTOMATED CHECK");
        $display("---------------------------------------------------------");
        
        // Check 1: Did we receive the correct NUMBER of outputs?
        // We expect 16 outputs (based on result_reg [0:15])
        if (out_write_pointer != 16) begin
            $display("[WARNING] Output Count Mismatch!");
            $display("          Expected: 16 outputs");
            $display("          Received: %0d outputs", out_write_pointer);
            // We continue checking anyway, up to the smaller count
        end else begin
            $display("[INFO] Received correct number of outputs (16).");
        end

        // Check 2: Verify Data Integrity
        errors = 0;
        
        // Loop through all expected results
        for (i = 0; i < 16; i = i + 1) begin
            
            // Use !== to catch 'X' (unknown) or 'Z' (high-z) values as errors
            if (captured_output_ram[i] !== result_reg[i]) begin
                $display("[ERROR] Mismatch at Index %0d", i);
                $display("        Expected: %h", result_reg[i]);
                $display("        Actual:   %h", captured_output_ram[i]);
                errors = errors + 1;
            end 
        end

        // Final Report
        $display("---------------------------------------------------------");
        if (errors == 0) begin
            $display("    SIMULATION PASSED: All 16 outputs match!");
        end else begin
            $display("    SIMULATION FAILED: Found %0d errors.", errors);
        end
        $display("---------------------------------------------------------");
        $display("\n");

        $finish;
    end
    
endmodule