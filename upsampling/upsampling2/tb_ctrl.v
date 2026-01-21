`include "control_unit_upsample.v"

module tb_ctrl;

    reg clk;
    reg rst; // active low
    reg start;
    reg [2:0] size_upsample;
    wire done;
    wire [3:0] write_mode;
    wire en_write_in;
    wire en_write_out;
    wire [13:0] addr_input;
    wire [13:0] addr_output;

    control_unit_upsample uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .size_upsample(size_upsample),
        .done(done),
        .write_mode(write_mode),
        .en_write_in(en_write_in),
        .en_write_out(en_write_out),
        .addr_input(addr_input),
        .addr_output(addr_output)
    ); 

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10 time units clock period
    end

    initial begin
        $dumpfile("tb_ctrl.vcd");
        $dumpvars(0, tb_ctrl);

        // Initialize signals
        rst = 0;
        start = 0;
        size_upsample = 3'b000;
        #15;
        rst = 1;
        #10;
        start = 1;
        #10;
        start = 0;
        #900;
        $finish;

    end



endmodule;