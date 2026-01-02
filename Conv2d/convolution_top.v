// Modul ini adalah top level dari convolution yang disambung dengan AXI-Stream interface
module convolution_top (
    input  wire        aclk,
    input  wire        aresetn,

    // AXI-Stream Slave Interface (Input Pixels from DMA)
    input  wire [15:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // AXI-Stream Master Interface (Filtered Pixels to DMA)
    output wire [15:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);

    // --- 1. Internal Control Signals ---
    wire pixel_en;
    reg [6:0] col_count; // 0 to 127
    reg [6:0] row_count; // 0 to 127
    
    // Handshake logic: We only process data when both sides are ready
    assign pixel_en = s_axis_tvalid && s_axis_tready;
    
    // Backpressure: We are ready for input only if the output stage is ready
    assign s_axis_tready = m_axis_tready;

    // --- 2. Counters for 128x128 Image ---
    always @(posedge aclk) begin
        if (!aresetn) begin
            col_count <= 0;
            row_count <= 0;
        end else if (pixel_en) begin
            if (col_count == 127) begin
                col_count <= 0;
                row_count <= row_count + 1;
            end else begin
                col_count <= col_count + 1;
            end
        end
    end

    // --- 3. Line Buffers & Sliding Window (Your Logic Here) ---
    // This is where you instantiate your BRAM Line Buffers 
    // and the 3x3 register window you designed.
    
    wire [15:0] conv_result;
    wire        conv_valid; // High when the window is full and math is done

    // --- 4. Output Logic ---
    assign m_axis_tdata  = conv_result;
    assign m_axis_tvalid = conv_valid && s_axis_tvalid; // Only valid if input is also valid
    
    // TLAST Generation: High on the very last pixel of the 128x128 frame
    assign m_axis_tlast = (row_count == 127 && col_count == 127) && pixel_en;

endmodule