`timescale 1ns / 1ps

module tb_top_level_conv;

    // Variables
    parameter DATA_WIDTH = 16;
    parameter PIXEL_WIDTH = 16;
    parameter KERNEL_WIDTH = 16;
    parameter RESULT_WIDTH = 48;

    parameter IMAGE_SIZE = 4;
    parameter CHANNEL_SIZE = 256;

    parameter INPUT_MEM_FILE = "weight_and_image_input_4x4";
    parameter OUTPUT_MEM_FILE = "result_conv_4x4.mem";

    integer DDR_INDEX;

    // Control input reg (simulating AXI GPIO)
    reg clk;
    reg Reset_top;
    reg Load_kernel_BRAM;
    reg [1:0] CHANNEL_SIZE_choose;
    reg [2:0] IMAGE_SIZE_choose;

    // Control outputs
    wire ena_bias_BRAM_addr_counter;
    wire rst_bias_BRAM_addr_counter;
    wire bias_BRAM_addr_counter_out;
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

    // Stimulus
    initial begin
        $readmemh(INPUT_MEM_FILE, input_reg);
        $readmemh(OUTPUT_MEM_FILE, result_reg);

        // Control inputs
        Reset_top = 0;
        Load_kernel_BRAM = 0;
        CHANNEL_SIZE_choose = 0;
        IMAGE_SIZE_choose = 0;

        // AXI control signals
        aresetn = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        m_axis_tready = 0;

        @(posedge clk);

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

            @(posedge clk);

            // Waiting for s_axis_tready
            while (!s_axis_tready) @(posedge clk);
        end

        s_axis_tlast = 0;
        s_axis_tvalid = 0;
        repeat (5) @(posedge clk);

        $finish;
    end
    
endmodule