`timescale 1ns / 1ps

module convolution_top_CU_alt (
    input wire clk,
    input wire aresetn,

    // Configuration
    input wire Load_kernel_BRAM, // Trigger to start loading kernels
    input wire [7:0] Image_size, // e.g., 128
    input wire [8:0] Channel_size, // e.g., 256
    
    // Status / Handshake
    input wire s_axis_tvalid,
    input wire s_axis_tlast,
    input wire m_axis_tready,
    
    // Counter Inputs (Feedback from counters in Top Level)
    input wire [7:0] kernel_BRAM_counter_out,
    input wire [7:0] in_row_counter,
    input wire [7:0] in_col_counter,

    // --- Control Outputs ---

    // Global State Controls
    output reg processing_done,

    // Kernel BRAM Controls
    output reg Wr_kernel,        // Write enable for Kernel BRAM
    output reg Rst_kernel,       // Reset Kernel Counter
    output reg enb_kernel_BRAM,  // Enable Kernel BRAM Read

    // Window / Line Buffer Controls
    output reg Rst_window,       // Reset Window counters/logic
    output reg Wr_window,        // Enable writing to Window/LineBuffers
    output reg Shift_window,     // Enable shifting the 3x3 register
    output reg window_row_n_mux, // 0: Input Image, 1: Zero (for bottom padding)
    output reg [1:0] padding_mux_sel, // Control for Left/Right padding insertion

    // Accumulation / PE Controls
    output reg add_bias,         // 1: Add Bias (Ch 0), 0: Add Partial Sum (Ch > 0)
    
    // Output BRAM Controls
    output reg ena_output_BRAM,  // Enable Port A (Write/Read for Accum)
    output reg wea_output_BRAM,  // Write Enable Port A
    output reg rsta_output_BRAM_addr_counter,
    output reg ena_output_BRAM_addr_counter,
    output reg enb_output_BRAM,  // Enable Port B (Read for Output Stream)
    output reg rstb_output_BRAM_addr_counter,
    output reg enb_output_BRAM_addr_counter,

    // AXI Stream Controls
    output reg s_axis_tready,
    output reg m_axis_tvalid,
    output reg m_axis_tlast
);

    // --- State Definition ---
    localparam S_IDLE              = 4'd0;
    localparam S_LOAD_KERNELS      = 4'd1;
    localparam S_INIT_CHANNEL      = 4'd2;
    localparam S_PAD_TOP           = 4'd3; // Send dummy zero row
    localparam S_PROCESS_ROW       = 4'd4; // Main convolution
    localparam S_PAD_BOTTOM        = 4'd5; // Send dummy zero row
    localparam S_WAIT_ROW_DONE     = 4'd6; 
    localparam S_NEXT_CHANNEL      = 4'd7;
    localparam S_STREAM_OUT        = 4'd8;
    localparam S_DONE              = 4'd9;

    reg [3:0] current_state, next_state;

    // Internal Channel Counter
    reg [8:0] current_channel;
    
    // Pipeline Delay Logic
    // The PE takes time to compute. We need to delay the Write Enable to the Output BRAM
    // to match the latency of the Multiplier_Adder. 
    // Assuming roughly 3-4 cycles latency in PE + BRAM read latency. 
    // You may need to tune 'PIPELINE_DEPTH' based on your exact synthesis timing.
    parameter PIPELINE_DEPTH = 1; 
    reg [PIPELINE_DEPTH-1:0] valid_pipe;
    wire valid_calc_result;

    // --- State Sequential Logic ---
    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            current_state <= S_IDLE;
            current_channel <= 0;
        end else begin
            current_state <= next_state;
            
            // Channel Counter Logic
            if (current_state == S_NEXT_CHANNEL)
                current_channel <= current_channel + 1;
            else if (current_state == S_IDLE)
                current_channel <= 0;
        end
    end

    // --- Pipeline Shift Register for Write Enable ---
    // Tracks when valid data entered the pipeline to assert WE at the end
    wire pipeline_feed;
    // We are feeding valid data to PE if we are shifting window AND valid pixels are present
    assign pipeline_feed = (current_state == S_PROCESS_ROW || current_state == S_PAD_TOP || current_state == S_PAD_BOTTOM) && Shift_window;

    always @(posedge clk or negedge aresetn) begin
        if (!aresetn) 
            valid_pipe <= 0;
        else begin
            // Fix for PIPELINE_DEPTH = 1
            if (PIPELINE_DEPTH == 1) begin
                valid_pipe <= pipeline_feed;
            end 
            else begin
                // Standard shift register for Depth > 1
                valid_pipe <= {valid_pipe[PIPELINE_DEPTH-2:0], pipeline_feed};
            end
        end
    end
    
    // The write enable for accumulation is the output of this delay line
    // We only write if we are inside the valid image boundaries (handled by address counters usually)
    assign valid_calc_result = valid_pipe[PIPELINE_DEPTH-1];


    // --- Next State Logic ---
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            S_IDLE: begin
                if (Load_kernel_BRAM)
                    next_state = S_LOAD_KERNELS;
                else if (s_axis_tvalid && !Load_kernel_BRAM) // Start if data arrives and not loading kernels
                    next_state = S_INIT_CHANNEL;
            end

            S_LOAD_KERNELS: begin
                // Assuming Kernel Size is fixed or derived. 
                // If 3x3x256, wait until counter hits max.
                // Using s_axis_tlast is safer if DMA sends exactly the kernel packet.
                if (s_axis_tlast && s_axis_tvalid) 
                    next_state = S_IDLE; // Go back to IDLE to wait for Image Data
            end

            S_INIT_CHANNEL: begin
                next_state = S_PAD_TOP;
            end

            S_PAD_TOP: begin
                // Simulate one row of zeros before image starts
                if (in_col_counter == Image_size - 1)
                    next_state = S_PROCESS_ROW;
            end

            S_PROCESS_ROW: begin
                // Process actual image rows
                if (in_row_counter == Image_size - 1 && in_col_counter == Image_size - 1) begin
                    // If this was the last pixel of the last real row
                    next_state = S_PAD_BOTTOM; 
                end else if (in_col_counter == Image_size - 1) begin
                   // End of a normal row, stay in state (counters handle wrapping)
                   next_state = S_PROCESS_ROW; 
                end
            end

            S_PAD_BOTTOM: begin
                // Process one row of zeros after image ends
                if (in_col_counter == Image_size - 1)
                    next_state = S_NEXT_CHANNEL;
            end

            S_NEXT_CHANNEL: begin
                if (current_channel == Channel_size - 1)
                    next_state = S_STREAM_OUT;
                else
                    next_state = S_INIT_CHANNEL;
            end

            S_STREAM_OUT: begin
                // Read Output BRAM and stream to M_AXIS
                // Logic depends on address counter reaching max
                // Assuming address counter signals done or we check count
                // NOTE: You need a signal from the Top checking if Output Addr == Max
                // For now, assuming a manual check or added input for "output_done"
                 // Placeholder: stay here until reset or manual completion
                 // ideally: if (output_addr == Image_size*Image_size) next = S_IDLE;
            end

            default: next_state = S_IDLE;
        endcase
    end


    // --- Output Control Signals ---
    always @(*) begin
        // Defaults
        Wr_kernel = 0; Rst_kernel = 0; enb_kernel_BRAM = 0;
        Rst_window = 0; Wr_window = 0; Shift_window = 0;
        window_row_n_mux = 0; padding_mux_sel = 0;
        add_bias = 0;
        ena_output_BRAM = 0; wea_output_BRAM = 0; 
        rsta_output_BRAM_addr_counter = 0; ena_output_BRAM_addr_counter = 0;
        enb_output_BRAM = 0; rstb_output_BRAM_addr_counter = 0; enb_output_BRAM_addr_counter = 0;
        s_axis_tready = 0; m_axis_tvalid = 0; m_axis_tlast = 0;
        processing_done = 0;

        case (current_state)
            S_IDLE: begin
                Rst_kernel = 1; 
                Rst_window = 1;
                rsta_output_BRAM_addr_counter = 1;
                rstb_output_BRAM_addr_counter = 1;
            end

            S_LOAD_KERNELS: begin
                s_axis_tready = 1;
                if (s_axis_tvalid) begin
                    Wr_kernel = 1;
                    // Note: Kernel address counter should increment externally when Wr_kernel is high
                end
            end

            S_INIT_CHANNEL: begin
                Rst_window = 1; // Clear window registers and line buffers
                rsta_output_BRAM_addr_counter = 1; // Reset output pointer for accumulation
            end

            S_PAD_TOP: begin
                // Feeding Zeros to Line Buffers/Window
                Wr_window = 1;
                Shift_window = 1;
                window_row_n_mux = 1; // Force Input 0 (Zero Padding)
                
                // Address Counter for Output BRAM (Accumulator)
                // We might be reading old partial sums, so we enable read port
                ena_output_BRAM = 1;
                
                // Write Enable (Delayed by pipeline depth)
                if (valid_calc_result) begin
                    wea_output_BRAM = 1;
                    ena_output_BRAM_addr_counter = 1;
                end
                // Set Add Bias logic
                if (current_channel == 0) add_bias = 1;
                else add_bias = 0;
            end

            S_PROCESS_ROW: begin
                s_axis_tready = 1; // Ready to accept pixels
                
                if (s_axis_tvalid) begin
                    Wr_window = 1;
                    Shift_window = 1;
                    window_row_n_mux = 0; // Use actual S_AXIS data
                    
                    ena_output_BRAM = 1;
                    if (valid_calc_result) begin
                        wea_output_BRAM = 1;
                        ena_output_BRAM_addr_counter = 1;
                    end
                    if (current_channel == 0) add_bias = 1;
                    else add_bias = 0;
                end
            end

            S_PAD_BOTTOM: begin
                // Similar to PAD_TOP but specifically for the end
                Wr_window = 1;
                Shift_window = 1;
                window_row_n_mux = 1; // Force Zero input
                
                ena_output_BRAM = 1;
                if (valid_calc_result) begin
                    wea_output_BRAM = 1;
                    ena_output_BRAM_addr_counter = 1;
                end
                if (current_channel == 0) add_bias = 1;
                else add_bias = 0;
            end

            S_NEXT_CHANNEL: begin
                // Short wait state to ensure pipeline flushes if needed
                // Reset address counters for next pass
                rsta_output_BRAM_addr_counter = 1; 
            end

            S_STREAM_OUT: begin
                enb_output_BRAM = 1; // Enable Port B for reading
                if (m_axis_tready) begin
                    m_axis_tvalid = 1;
                    enb_output_BRAM_addr_counter = 1;
                    // Logic to drive tlast when address == MAX
                end
            end
        endcase
    end

endmodule