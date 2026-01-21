`include "noise_matrix_filler.v"
module tb_noise_filler;
    reg  clk;
    reg rst_n;
    reg start;
    reg [2:0] size;
    
    wire [13:0] bram_addr;
    wire [63:0] bram_wdata;
    wire bram_we;           
    wire done;

    noise_matrix_filler #(
        .DATA_WIDTH(64),
        .ADDR_WIDTH(14)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .size(size),
        .bram_addr(bram_addr),
        .bram_wdata(bram_wdata),
        .bram_we(bram_we),           
        .done(done)
    );

    initial begin
        forever #10 clk = ~clk;
    end

    initial begin
        $dumpfile("tb_noise_filler.vcd");
        $dumpvars(0, tb_noise_filler);
        

        clk = 0;
        rst_n = 0;
        start = 0;
        size = 3'b001; // 4x4
        #20;
        rst_n = 1;
        #20;
        start = 1;
        #20;
        start = 0;
        #1000;
        $finish;
    end

endmodule;