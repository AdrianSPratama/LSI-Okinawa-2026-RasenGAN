`timescale 1ns / 1ps

module tb_convolution_top();

    // --- Parameters ---
    parameter PIXEL_W  = 16;
    parameter KERNEL_W = 16;
    parameter RESULT_W = 48;
    parameter IMG_SIZE = 128; 
    parameter CHANNELS = 256;

    // --- Clock & Reset ---
    reg clk;
    reg aresetn;

    // --- UUT Signals ---
    reg Load_kernel_BRAM;
    wire [255:0] kernel_BRAM_doutb;
    wire enb_kernel_BRAM;
    wire [7:0] kernel_BRAM_counter_out;
    reg [47:0] bias_val;
    
    // Slave AXI-Stream (Input)
    reg [PIXEL_W-1:0] s_axis_tdata;
    reg s_axis_tvalid;
    wire s_axis_tready;
    reg s_axis_tlast;

    // Master AXI-Stream (Output)
    wire [63:0] m_axis_tdata;
    wire m_axis_tvalid;
    reg m_axis_tready;
    wire m_axis_tlast;

    // --- Reference Model Memories ---
    reg signed [PIXEL_W-1:0]  ref_input  [0:CHANNELS-1][0:IMG_SIZE-1][0:IMG_SIZE-1];
    reg signed [KERNEL_W-1:0] ref_kernel [0:CHANNELS-1][0:2][0:2]; // 3x3 kernels
    reg signed [RESULT_W-1:0] ref_output [0:IMG_SIZE-1][0:IMG_SIZE-1];

    // --- Simulation Internal Variables ---
    integer i, j, k, r, c, ch;
    integer err_count = 0;
    integer pixels_received = 0;

    // --- UUT Instantiation ---
    convolution_top uut (
        .clk(clk),
        .aresetn(aresetn),
        .Load_kernel_BRAM(Load_kernel_BRAM),
        .Image_size(IMG_SIZE),
        .Channel_size(CHANNELS),
        .kernel_BRAM_doutb(kernel_BRAM_doutb),
        .enb_kernel_BRAM(enb_kernel_BRAM),
        .kernel_BRAM_counter_out(kernel_BRAM_counter_out),
        .bias_BRAM_douta(bias_val),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast)
    );

    // --- Clock Generation ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- Mock Kernel BRAM ---
    // Packs 3x3 kernels from ref_kernel into the 256-bit bus for the UUT
    assign kernel_BRAM_doutb = { 112'b0, // padding
        ref_kernel[kernel_BRAM_counter_out][2][2], ref_kernel[kernel_BRAM_counter_out][2][1], ref_kernel[kernel_BRAM_counter_out][2][0],
        ref_kernel[kernel_BRAM_counter_out][1][2], ref_kernel[kernel_BRAM_counter_out][1][1], ref_kernel[kernel_BRAM_counter_out][1][0],
        ref_kernel[kernel_BRAM_counter_out][0][2], ref_kernel[kernel_BRAM_counter_out][0][1], ref_kernel[kernel_BRAM_counter_out][0][0]
    };

    // --- 1. Reference Model Calculation ---
    task calculate_golden_ref;
        reg signed [RESULT_W-1:0] sum;
        reg signed [PIXEL_W-1:0]  pix;
        begin
            $display("[%0t] Starting Reference Model Calculation...", $time);
            for (r=0; r<IMG_SIZE; r=r+1) begin
                for (c=0; c<IMG_SIZE; c=c+1) begin
                    ref_output[r][c] = bias_val; // Initialize with bias
                    for (ch=0; ch<CHANNELS; ch=ch+1) begin
                        sum = 0;
                        for (i=0; i<3; i=i+1) begin
                            for (j=0; j<3; j=j+1) begin
                                // Logic for Zero Padding (3x3 Kernel centered at r,c)
                                if ((r+i-1 >= 0) && (r+i-1 < IMG_SIZE) && (c+j-1 >= 0) && (c+j-1 < IMG_SIZE))
                                    pix = ref_input[ch][r+i-1][c+j-1];
                                else
                                    pix = 0; // Padding
                                sum = sum + (pix * ref_kernel[ch][i][j]);
                            end
                        end
                        ref_output[r][c] = ref_output[r][c] + sum;
                    end
                end
            end
            $display("[%0t] Golden Reference Calculation Finished.", $time);
        end
    endtask

    // --- 2. Main Stimulus Process ---
    initial begin
        // Init data
        aresetn = 0;
        Load_kernel_BRAM = 0;
        s_axis_tvalid = 0;
        m_axis_tready = 1;
        bias_val = 48'sd500;

        // Generate Random Input & Kernels
        for (ch=0; ch<CHANNELS; ch=ch+1) begin
            for (i=0; i<3; i=i+1) for (j=0; j<3; j=j+1) ref_kernel[ch][i][j] = $random % 10;
            for (r=0; r<IMG_SIZE; r=r+1) for (c=0; c<IMG_SIZE; c=c+1) ref_input[ch][r][c] = $random % 255;
        end

        // Calculate Golden Ref
        calculate_golden_ref();

        // Hardware Reset
        #100 aresetn = 1;
        #100;

        // LOAD KERNELS
        $display("[%0t] Loading Kernels into Hardware...", $time);
        Load_kernel_BRAM = 1;
        wait (kernel_BRAM_counter_out == CHANNELS-1);
        @(posedge clk);
        Load_kernel_BRAM = 0;

        // STREAM PIXELS
        $display("[%0t] Streaming %0d Channels...", $time, CHANNELS);
        for (ch=0; ch<CHANNELS; ch=ch+1) begin
            for (r=0; r<IMG_SIZE; r=r+1) begin
                for (c=0; c<IMG_SIZE; c=c+1) begin
                    s_axis_tvalid = 1;
                    s_axis_tdata  = ref_input[ch][r][c];
                    s_axis_tlast  = (r == IMG_SIZE-1 && c == IMG_SIZE-1);
                    @(posedge clk);
                    while (!s_axis_tready) @(posedge clk); // Handle backpressure
                end
            end
            s_axis_tvalid = 0;
            repeat(10) @(posedge clk); // Gap between channels
        end

        // Wait for final stream output to finish
        wait (pixels_received == IMG_SIZE*IMG_SIZE);
        #100;
        
        $display("---------------------------------------");
        $display("FINAL REPORT");
        $display("Pixels Checked: %0d", pixels_received);
        $display("Errors Found:   %0d", err_count);
        if (err_count == 0) $display("SUCCESS: Hardware matches reference!");
        else $display("FAILURE: Mismatches detected.");
        $display("---------------------------------------");
        $finish;
    end

    // --- 3. Self-Checking Monitor ---
    integer out_r = 0, out_c = 0;
    always @(posedge clk) begin
        if (m_axis_tvalid && m_axis_tready) begin
            // Compare 48-bit result (ignoring sign extension padding in m_axis_tdata)
            if (m_axis_tdata[47:0] !== ref_output[out_r][out_c]) begin
                $display("[%0t] ERROR at pixel [%0d,%0d] | HW: %h | REF: %h", $time, out_r, out_c, m_axis_tdata[47:0], ref_output[out_r][out_c]);
                err_count = err_count + 1;
            end
            
            pixels_received = pixels_received + 1;

            // Increment pointers
            if (out_c == IMG_SIZE-1) begin
                out_c = 0;
                out_r = out_r + 1;
            end else begin
                out_c = out_c + 1;
            end
        end
    end

endmodule