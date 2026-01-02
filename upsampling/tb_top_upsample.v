`timescale 1ns / 1ps

`include "top_upsample.v"

module tb_top_upsample;

    // --- Parameter (Sesuaikan dengan DUT) ---
    parameter NUMBER_OF_ROW = 4; // Input 4x4
    parameter LENGTH = 12;        // Lebar data 4-bit
    parameter FRAC = 8;          // Upscale factor (biasanya 2x -> jadi 8x8)

    // --- Sinyal Testbench ---
    reg clk;
    reg rst;
    reg start;
    
    // Input Data (4x4 = 16 elemen * 4 bit = 64 bit)
    reg [LENGTH*NUMBER_OF_ROW*NUMBER_OF_ROW-1:0] din;

    // Output Data (8x8 = 64 elemen * 4 bit = 256 bit)
    // PENTING: Output dari modul harus ditangkap oleh WIRE, bukan REG
    wire [LENGTH*64-1:0] dout; 

    // Optional: Jika nanti Anda menambahkan port done
    wire done; 

    // --- Instansiasi Unit Under Test (DUT) ---
    top_upsample #(
        .number_of_row(NUMBER_OF_ROW),
        .length(LENGTH),
        .frac(FRAC)
    ) uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .din(din),
        .dout(dout),
        .done(done) // Uncomment jika modul asli sudah punya port done
    );

    // --- Clock Generation (Periode 10ns) ---
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // --- Variable Loop ---
    integer i;

    // --- Task: Menampilkan Output sebagai Matriks 8x8 ---
    task display_matrix_8x8;
        integer r, c;
        integer idx;
        reg [LENGTH-1:0] val;
        begin
            $display("\n--- Hasil Output Upsampling (Matriks 8x8) ---");
            $display("   C: 0 1 2 3 4 5 6 7");
            for (r = 0; r < 8; r = r + 1) begin
                $write("R%0d:  ", r);
                for (c = 0; c < 8; c = c + 1) begin
                    // Menghitung index flat array untuk baris r, kolom c
                    idx = r * 8 + c;
                    
                    // Mengambil slice 4-bit dari vector panjang dout
                    val = dout[idx*LENGTH +: LENGTH];
                    
                    $write("%d ", val);
                end
                $write("\n");
            end
            $display("-------------------------------------------");
        end
    endtask

    // --- Task: Menampilkan Input sebagai Matriks 4x4 ---
    task display_input_matrix;
        integer r, c;
        integer idx;
        reg [LENGTH-1:0] val;
        begin
            $display("\n--- Matriks Input (4x4) [Nilai Decimal] ---");
            $display("       Col:    0    1    2    3");
            for (r = 0; r < 4; r = r + 1) begin
                $write("Row %0d:  ", r);
                for (c = 0; c < 4; c = c + 1) begin
                    // Hitung index flat array
                    idx = r * 4 + c;
                    
                    // Ambil slice data input
                    val = din[idx*LENGTH +: LENGTH];
                    
                    // Cetak dengan lebar 5 digit agar rapi (misal: "  300")
                    $write("%5d ", val);
                end
                $write("\n");
            end
            $display("-------------------------------------------");
        end
    endtask

    // --- Main Stimulus ---
    initial begin
        $dumpfile("tb_top_upsample.vcd");
        $dumpvars(0, tb_top_upsample);
        // 1. Inisialisasi Awal
        rst = 1;
        start = 0;
        din = 0;

        // 2. Reset Active Low
        $display("Melakukan Reset...");
        #10;
        rst = 0; // Masuk Reset
        #20;
        rst = 1; // Keluar Reset (Active Low logic selesai)
        #10;

        // 3. Mengisi Input Data (0 s.d F) secara berurutan
        // Matriks Input 4x4 (16 elemen)
        $display("Mengisi Data Input 0..F ...");
        for (i = 0; i < 16; i = i + 1) begin
            // Rumus: 300 + (i * 10)
            // i=0 -> 300
            // i=1 -> 310
            // ... dst
            din[i*LENGTH +: LENGTH] = 35 + (i * 10);
        end 
        // Opsional: Tampilkan apa yang kita masukkan
        $display("Data Input (Hex): %h", din);

        display_input_matrix();

        // 4. Mulai Proses (Start)
        $display("Start Processing...");
        start = 1;
        @(posedge clk);
        #10;
        start = 0; // Pulse start (tergantung desain FSM Anda, pulse biasanya cukup)

        // 5. Tunggu Sampai Selesai
        // Karena tidak ada port 'done' di interface yang Anda berikan,
        // kita tunggu delay yang cukup lama.
        
        // JIKA ADA PORT DONE: uncomment baris bawah
        wait(done == 1); 
        
        // JIKA TIDAK ADA PORT DONE: PaWSkai delay estimasi
        // #200; 

        // 6. Tampilkan Hasil
        display_matrix_8x8();

        #20;
        $display("Simulasi Selesai.");
        $finish;
    end

endmodule