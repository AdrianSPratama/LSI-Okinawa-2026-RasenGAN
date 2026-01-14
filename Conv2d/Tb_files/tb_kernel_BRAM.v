`timescale 1ns / 1ps

module tb_kernel_BRAM;

    parameter KERNEL_WIDTH = 16;
    parameter CHANNEL_SIZE = 9'd128;

    parameter KERNEL_FILE = "weight_conv_4x4.mem";

    // Variables
    integer chan_index = 0;
    integer i = 8'd0;
    integer valid = 0;

    // Inputs
    reg clk, rst;
    reg load_BRAM_dina;
    reg update_BRAM_doutb;
    reg s_axis_tvalid;
    reg s_axis_tlast;

    // Outputs
    wire done_loading_1ker;
    wire last_channel;
    wire s_axis_tready;

    // Simulate M_AXIS to input S_AXIS (DDR simulated by BRAM)
    reg [255:0] kernel_3x3 [0:CHANNEL_SIZE-1];
    
    // Data I/O
    wire [143:0] kernel_BRAM_dina;
    wire [143:0] kernel_BRAM_doutb;

    // Data check
    wire [255:0] kernel_BRAM_doutb_padded;
    assign kernel_BRAM_doutb_padded = {{112{1'b0}},kernel_BRAM_doutb};

    // Assign kernel_BRAM_dina wire to DDR output reg, take 144 LSB
    assign kernel_BRAM_dina = kernel_3x3[chan_index][143:0];

    // Instantiate kernel_BRAM
    kernel_BRAM #(
        .KERNEL_WIDTH(KERNEL_WIDTH)
    ) DUT (
        // Control inputs
        .clk(clk),
        .Reset(rst),
        .load_BRAM_dina(load_BRAM_dina),
        .update_BRAM_doutb(update_BRAM_doutb),
        .CHANNEL_SIZE(CHANNEL_SIZE),

        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast), // Not used

        // Control output interface for other blocks
        .done_loading_1ker(done_loading_1ker),
        .last_channel(last_channel),
        .s_axis_tready(s_axis_tready),

        // Data ports
        .kernel_BRAM_dina(kernel_BRAM_dina),
        .kernel_BRAM_doutb(kernel_BRAM_doutb)
    );

    // Clock Generation (100 MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // Testbench stimulus
    initial begin
        // Read initialization file for DDR simulation
        $readmemh(KERNEL_FILE, kernel_3x3);

        // Load kenrel BRAM from dina test
        rst <= 0;
        load_BRAM_dina <= 0;
        update_BRAM_doutb <= 0;
        s_axis_tvalid <= 0;
        s_axis_tlast <= 0;

        @(posedge clk);

        rst <= 1;
        load_BRAM_dina <= 0;
        update_BRAM_doutb <= 0;
        s_axis_tvalid <= 0;
        s_axis_tlast <= 0;

        @(posedge clk);

        load_BRAM_dina <= 1;
        update_BRAM_doutb <= 0;
        s_axis_tvalid <= 0;
        s_axis_tlast <= 0;
        
        @(posedge clk)
        load_BRAM_dina <= 0;

        repeat (10) @(posedge clk);

        s_axis_tvalid <= 1;
        for (chan_index=0; chan_index<CHANNEL_SIZE; chan_index = chan_index + 1) begin
            while (!s_axis_tready) @(posedge clk);
            @(posedge clk);
        end

        s_axis_tvalid <= 0;
    

        for (i = 0; i<CHANNEL_SIZE; i = i+1) begin
            @(posedge clk);
            if (DUT.DATAPATH.kernel_BRAM.BRAM[i] == kernel_3x3[i]) begin
                $display("Index %d valid", i);
            end
            else begin
                $display("ERROR: Index %d invalid", i);
                $display("Should be: %h", kernel_3x3[i]);
                $display("Got: %h", kernel_BRAM_doutb_padded);
                valid = valid + 1;
            end
        end

        if(valid == 0) begin
            $display("All test passed");
        end
        else begin
            $display("SOME ERROR OCCURED, number of errors: %d", valid);
        end

        repeat (10) @(posedge clk);

        // Update kernel BRAM addrb test
        for (i = 0; i<CHANNEL_SIZE; i=i+1) begin
            update_BRAM_doutb <= 1;
            @(posedge clk); 
            update_BRAM_doutb <= 0;
            repeat (5) @(posedge clk); 
        end

        $stop;
    end

endmodule