`timescale 1ns / 1ps

`include "top_upsample.v"

module tb_top_upsample;

    // ==========================================
    // 1. Parameter & Signal
    // ==========================================
    parameter LENGTH = 16;

    reg clk;
    reg rst;
    reg start;
    reg [2:0] mode;
    reg [2:0] size_upsample;
    
    wire [LENGTH - 1:0] t_data_in;
    wire done;
    wire [LENGTH - 1:0] t_data_out;
    wire [13:0] addr_input;
    wire [13:0] addr_output;

    // ==========================================
    // 2. Memori (Matrix)
    // ==========================================
    // Input 8x8 = 64 elemen
    reg [LENGTH-1:0] data_input [0:63];
    // Output 16x16 = 256 elemen
    reg [LENGTH-1:0] data_output [0:255];

    integer i, j;
    integer cycle_count; // Counter untuk timeout

    // ==========================================
    // 3. Instansiasi DUT
    // ==========================================
    top_upsample #(
        .length(LENGTH)
    ) uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .mode(mode), 
        .size_upsample(size_upsample), 
        .done(done), 
        .t_data_in(t_data_in), 
        .t_data_out(t_data_out), 
        .addr_input(addr_input), 
        .addr_output(addr_output)
    );

    // ==========================================
    // 4. Clock
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // ==========================================
    // 5. Logika Memori (Read & Write)
    // ==========================================
    
    // READ: Kirim data ke DUT (Batas diubah ke 64 untuk input 8x8)
    assign t_data_in = (addr_input < 64) ? data_input[addr_input] : 0;

    // WRITE: Tangkap output dari DUT (Batas diubah ke 256 untuk output 16x16)
    always @(posedge clk) begin
        if (uut.en_write_out) begin 
            if (addr_output < 256) begin
                data_output[addr_output] <= t_data_out;
            end
        end
    end

    // ==========================================
    // 6. Stimulus Utama
    // ==========================================
    initial begin
        // --- Setup Awal ---
        $dumpfile("dump.vcd"); 
        $dumpvars(0, tb_top_upsample);  
        
        rst = 1;
        start = 0;
        mode = 0;
        // MODIFIKASI: Size diset ke 001
        size_upsample = 3'b001; 
        cycle_count = 0;

        // --- Isi Data Input (100, 110, 120... sampai 64 data) ---
        $display("--------------------------------");
        $display("Initializing Memory (64 items)...");
        // MODIFIKASI: Loop 64 kali
        for (i = 0; i < 64; i = i + 1) begin
            data_input[i] = 100 + (i * 10);
        end

        // Bersihkan output (256 items)
        for (i = 0; i < 256; i = i + 1) begin
            data_output[i] = 0;
        end

        // --- Reset Sequence ---
        #20 rst = 0; // Active Low Reset (Assuming logic uses !rst) or active high depending on design
        // Jika modul Anda reset active LOW (rst=0 reset), gunakan baris di atas.
        // Jika modul Anda reset active HIGH, tukar logika ini.
        // Asumsi dari kode awal: rst=1 awal, lalu rst=0, lalu rst=1. 
        // Biasanya active low reset ditulis: initial rst=0; #10 rst=1;
        // Tapi saya ikuti pola kode asli Anda:
        #20 rst = 1; 
        #20;

        // --- Start ---
        $display("Starting Simulation with Size = %b...", size_upsample);
        start = 1;
        #10 start = 0; // Pulse start

        // --- LOOP TUNGGU ---
        // Timeout dinaikkan ke 5000 karena data lebih banyak
        while ((done == 0) && (cycle_count < 5000)) begin
            @(posedge clk); 
            cycle_count = cycle_count + 1;
        end

        // --- Cek Hasil ---
        if (done) begin
            $display("Status: DONE signal received at cycle %0d", cycle_count);
            #20; // Tunggu write terakhir selesai
        end else begin
            $display("Status: TIMEOUT reached (5000 cycles)!");
        end

        // --- Tampilkan Matrix Input (8x8) ---
        $display("\nMatrix Input (8x8):");
        for (i = 0; i < 8; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < 8; j = j + 1) begin
                // Menampilkan index i*8 + j
                $write("%4d ", data_input[i*8 + j]);
            end
            $write("\n");
        end

        // --- Tampilkan Matrix Output (16x16) ---
        $display("\nMatrix Output (16x16):");
        for (i = 0; i < 16; i = i + 1) begin
            $write("Row %02d: ", i);
            for (j = 0; j < 16; j = j + 1) begin
                // Menampilkan index i*16 + j
                $write("%4d ", data_output[i*16 + j]);
            end
            $write("\n"); 
        end

        $display("--------------------------------");
        $finish;
    end

endmodule