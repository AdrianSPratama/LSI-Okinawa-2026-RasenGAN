`timescale 1ns / 1ps

`include "reg_input.v"

module tb_reg_input;

    // 1. Deklarasi Parameter dan Sinyal
    parameter LENGTH = 16;
    
    // Input ke DUT (Device Under Test) harus berupa reg
    reg clk;
    reg rst;
    reg [LENGTH-1:0] din;

    // Output dari DUT harus berupa wire
    wire [LENGTH-1:0] dout1;
    wire [LENGTH-1:0] dout2;
    wire [LENGTH-1:0] dout3;
    wire [LENGTH-1:0] dout4;

    // Variabel loop untuk input data
    integer i;

    // 2. Instansiasi Unit (DUT)
    reg_input #(
        .length(LENGTH)
    ) uut (
        .clk(clk), 
        .rst(rst), 
        .din(din), 
        .dout1(dout1), 
        .dout2(dout2), 
        .dout3(dout3), 
        .dout4(dout4)
    );

    // 3. Generator Clock
    // Periode = 10ns (Frekuensi 100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 4. Stimulus (Skenario Pengujian)
    initial begin
        // Setup awal: Dump file untuk waveform (opsional, bisa dihapus jika tidak perlu)
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_reg_input);

        // Inisialisasi
        rst = 1; // Asumsi active low (berdasarkan kode: if (!rst))
        din = 0;
        
        // --- PROSES RESET ---
        $display("--- Memulai Reset ---");
        #10;
        rst = 0; // Aktifkan reset
        #10;
        rst = 1; // Matikan reset
        $display("--- Reset Selesai ---");

        // --- MULAI INPUT DATA 1 s.d 17 ---
        $display("--- Memasukkan Data 1 sampai 17 ---");
        
        // Kita gunakan @(negedge clk) agar data stabil saat posedge (setup time aman)
        for (i = 1; i <= 17; i = i + 1) begin
            @(negedge clk); 
            din = i;
            
            // Menampilkan monitor output di console
            // Kita beri delay sedikit agar output stabil sebelum di-print
            #1; 
            $display("Time: %0t | In: %d | Window Out: [%d %d] / [%d %d]", 
                     $time, din, dout1, dout2, dout3, dout4);
        end

        // Tunggu beberapa siklus clock tambahan untuk melihat efek pipeline
        #20;
        
        $display("--- Simulasi Selesai ---");
        $finish;
    end

endmodule

// 1   2   3   4
// 5   6   7   8
// 9  10  11  12
// 13 14  15  16