`timescale 1ns/1ps

module tb_adain;
    parameter WIDTH_IN = 48, WIDTH_OUT = 16, N_MAX = 256;

    reg clk, rst;
    reg [1:0] start;
    reg [$clog2(N_MAX+1)-1:0] N;
    reg [WIDTH_IN-1:0] in, ys, yb;
    wire [WIDTH_OUT-1:0] out;
    wire [1:0] done;

    reg [WIDTH_IN-1:0] x_mem [0:3];
    integer i;

    top_adain #(.WIDTH_IN(WIDTH_IN), .WIDTH_OUT(WIDTH_OUT), .N_MAX(N_MAX)) uut (
        .clk(clk), .rst(rst), .start(start), .N(N), .in(in), .ys(ys), .yb(yb), .out(out), .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Prosedur Pemberian Data (Piksel 1-4)
    task push_data;
    begin
        for (i = 0; i < 4; i = i + 1) begin
            in <= x_mem[i];
            @(posedge clk);
        end
        in <= 0;
    end
    endtask

    initial begin
        // Data Q16.16: {1, 2, 3, 4}
        x_mem[0] = 48'h10000; x_mem[1] = 48'h20000;
        x_mem[2] = 48'h30000; x_mem[3] = 48'h40000;

        rst = 1; start = 0; N = 2;
        ys = 48'h10000; yb = 0; 
        
        repeat(5) @(posedge clk);
        rst <= 0;
        repeat(2) @(posedge clk);

        // --- SEGMENT 1: MEAN ---
        $display("[%0t] START MEAN...", $time);
        start <= 2'b01;
        in    <= x_mem[0]; // Data pertama siap seketika saat start
        @(posedge clk) start <= 2'b00;
        push_data(); // Dorong sisa data
        wait(done == 2'b01);
        
        repeat(5) @(posedge clk);

        // --- SEGMENT 2: VAR TO B0 ---
        $display("[%0t] START VAR...", $time);
        start <= 2'b10;
        in    <= x_mem[0];
        @(posedge clk) start <= 2'b00;
        push_data();
        wait(done == 2'b10);

        repeat(5) @(posedge clk);

        // --- SEGMENT 3: NORM ---
        $display("[%0t] START NORM...", $time);
        start <= 2'b11;
        in    <= x_mem[0];
        @(posedge clk) start <= 2'b00;
        push_data();
        wait(done == 2'b11);

        repeat(10) @(posedge clk);
        $finish;
    end

    always @(posedge clk) if (uut.out_en) $display("[%0t] OUT: %h", $time, out);
endmodule