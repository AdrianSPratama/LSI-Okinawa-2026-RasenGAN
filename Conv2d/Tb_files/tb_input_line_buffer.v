`timescale 1ns / 1ps

module tb_input_line_buffer;

    // Variables
    parameter DATA_WIDTH = 16;
    parameter IMAGE_SIZE = 8'd4;
    parameter CHANNEL_SIZE = 256;
    parameter INPUT_MEM_FILE = "layer_input_4x4.mem";

    integer DDR_INDEX;

    // Control inputs
    reg clk;
    reg Reset;
    reg Stream_first_row;
    reg Stream_mid_row;
    reg Stream_last_row;
    reg last_channel;

    // AXI input signals
    reg m_axis_tready;
    reg s_axis_tvalid;
    reg s_axis_tlast;

    // DDR mock with array of registers
    reg [DATA_WIDTH-1:0] input_reg [0:IMAGE_SIZE*IMAGE_SIZE*CHANNEL_SIZE-1];
    // Data input (AXI slave wire)
    wire [255:0] s_axis_tdata;
    assign s_axis_tdata = {{240{input_reg[DDR_INDEX][DATA_WIDTH-1]}}, input_reg[DDR_INDEX][DATA_WIDTH-1:0]};
    wire [15:0] dina;
    assign dina = s_axis_tdata[15:0];

    // Outputs
    wire [15:0] out_window_00;
    wire [15:0] out_window_01; 
    wire [15:0] out_window_02;
    wire [15:0] out_window_10;
    wire [15:0] out_window_11;
    wire [15:0] out_window_12;
    wire [15:0] out_window_20;
    wire [15:0] out_window_21;
    wire [15:0] out_window_22;

    // Control signal outputs for interface
    wire Done_1row;
    wire Output_valid;
    wire s_axis_tready;

    // Instantiate top level DUT
    input_line_buffer #(
        .DATA_WIDTH(DATA_WIDTH)
    ) DUT (
        // Data I/O
        .dina(dina),
        .out_window_00(out_window_00),
        .out_window_01(out_window_01), 
        .out_window_02(out_window_02),
        .out_window_10(out_window_10),
        .out_window_11(out_window_11),
        .out_window_12(out_window_12),
        .out_window_20(out_window_20),
        .out_window_21(out_window_21), 
        .out_window_22(out_window_22),

        // Control signals interface with other blocks
        // Input controls interface
        .clk(clk),
        .Reset(Reset),
        .Stream_first_row(Stream_first_row),
        .Stream_mid_row(Stream_mid_row),
        .Stream_last_row(Stream_last_row),
        .IMAGE_SIZE(IMAGE_SIZE),
        .last_channel(last_channel),

        // AXI input signals
        .m_axis_tready(m_axis_tready),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),

        // Output controls for interface
        .Done_1row(Done_1row),
        .Output_valid(Output_valid),
        .s_axis_tready(s_axis_tready)
    );
    
    // Generate clock (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // TO-DO: tambahin task buat setiap checks, ini contoh task nya
    // task check_first_row;
    //     input [15:0] pixel_value; // Inputs to the task
    //     begin
    //         // A task can wait for clocks! (Functions cannot)
    //         @(posedge clk); 
    //         data = pixel_value;
            
    //         @(posedge clk);
    //         data = 0;
    //     end
    // endtask

    initial begin
        $readmemh(INPUT_MEM_FILE, input_reg);
        
        // Control inputs
        Reset = 0;
        Stream_first_row = 0;
        Stream_mid_row = 0;
        Stream_last_row = 0;
        last_channel = 0;

        // AXI input signals
        m_axis_tready = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;

        Reset = 1;

        // Wait until stable to Idle state, minimum 2 clocks
        repeat (5) @(posedge clk);

        Stream_first_row = 1;

        @(posedge clk);

        Stream_first_row = 0;

        // Test Stream_first_row done, verified
        for (DDR_INDEX=0; DDR_INDEX<IMAGE_SIZE*IMAGE_SIZE; DDR_INDEX = DDR_INDEX+1) begin
            s_axis_tvalid = 1;
            // s_axis_tlast signal and start streaming last row
            if (DDR_INDEX == IMAGE_SIZE*IMAGE_SIZE-1) begin
                s_axis_tlast = 1;
                @(posedge clk);
                s_axis_tlast = 0;
                repeat (3) @(posedge clk);
                Stream_last_row = 1;
                @(posedge clk);
                Stream_last_row = 0;
            end
            // Start streaming row 2, verified
            else if (DDR_INDEX == IMAGE_SIZE) begin
                repeat (2) @(posedge clk);
                Stream_mid_row = 1;
                @(posedge clk);
                Stream_mid_row = 0;
            end
            // Start streaming row 3
            else if (DDR_INDEX == 2*IMAGE_SIZE) begin
                repeat (3) @(posedge clk);
                Stream_mid_row = 1;
                @(posedge clk);
                Stream_mid_row = 0;
            end
            // Start streaming row 4
            else if (DDR_INDEX == 3*IMAGE_SIZE) begin
                repeat (3) @(posedge clk);
                Stream_mid_row = 1;
                @(posedge clk);
                Stream_mid_row = 0;
            end
            @(posedge clk);
            s_axis_tvalid = 0;
            @(posedge clk);

            // Waiting for s_axis_tready
            while (!s_axis_tready) @(posedge clk);
        end

        s_axis_tlast = 0;
        s_axis_tvalid = 0;
        repeat (5) @(posedge clk);

        $stop;
    end

endmodule