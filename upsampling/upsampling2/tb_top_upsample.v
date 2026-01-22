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
    
    // Wire untuk koneksi ke DUT
    wire [LENGTH - 1:0] t_data_in;
    wire done;
    wire [LENGTH - 1:0] t_data_out;
    wire [13:0] addr_input;
    wire [13:0] addr_output;

    // ==========================================
    // 2. Memori (Simulasi BRAM)
    // ==========================================
    // Input 8x8 = 64 elemen
    reg [LENGTH-1:0] bram_input_mem [0:63];
    // Output 16x16 = 256 elemen
    reg [LENGTH-1:0] bram_output_mem [0:255];

    // Register sementara untuk menampung hasil baca BRAM (karena ada latency)
    reg [LENGTH-1:0] r_data_in_bram;

    integer i, j;
    integer cycle_count;

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
        .t_data_in(t_data_in), // Terhubung ke output register BRAM
        .t_data_out(t_data_out), 
        .addr_input(addr_input), 
        .addr_output(addr_output)
    );

    // ==========================================
    // 4. Clock Generation
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // ==========================================
    // 5. Model BRAM (Synchronous Read & Write)
    // ==========================================
    
    // --- BRAM INPUT (Read Port) ---
    // Prilaku BRAM: Data keluar 1 clock setelah alamat diberikan.
    assign t_data_in = r_data_in_bram;

    always @(posedge clk) begin
        // Proteksi alamat agar tidak out of bound simulation error
        if (addr_input < 16) begin
            r_data_in_bram <= bram_input_mem[addr_input];
        end else begin
            r_data_in_bram <= 0;
        end
    end

    // --- BRAM OUTPUT (Write Port) ---
    // Prilaku BRAM: Data ditulis saat clock naik jika Write Enable aktif.
    always @(posedge clk) begin
        // Menggunakan sinyal write enable dari DUT (uut.en_write_out)
        if (uut.en_write_out) begin 
            if (addr_output < 64) begin
                bram_output_mem[addr_output] <= t_data_out;
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
        size_upsample = 3'b000; // Size 001 sesuai request
        cycle_count = 0;
        
        // Inisialisasi output register BRAM agar tidak X di awal
        r_data_in_bram = 0;

        // --- Isi BRAM Input (Initial Load) ---
        // Ini mensimulasikan file .coe atau memori yang sudah terisi sebelum start
        $display("--------------------------------");
        $display("Initializing BRAM Input (16 items)...");
        for (i = 0; i < 16; i = i + 1) begin
            bram_input_mem[i] = 100 + (i * 10);
        end

        // Bersihkan BRAM Output
        for (i = 0; i < 64; i = i + 1) begin
            bram_output_mem[i] = 0;
        end

        // --- Reset Sequence ---
        #20 rst = 0; 
        #20 rst = 1; 
        #20;

        // --- Start ---
        $display("Starting Simulation...");
        start = 1;
        #10 start = 0; 

        // --- LOOP TUNGGU ---
        while ((done == 0) && (cycle_count < 5000)) begin
            @(posedge clk); 
            cycle_count = cycle_count + 1;
        end

        // --- Cek Hasil ---
        if (done) begin
            $display("Status: DONE signal received at cycle %0d", cycle_count);
            #20; 
        end else begin
            $display("Status: TIMEOUT reached (5000 cycles)!");
        end

        // --- Tampilkan Matrix Input ---
        $display("\nMatrix Input (4x4) from BRAM:");
        for (i = 0; i < 4; i = i + 1) begin
            $write("Row %0d: ", i);
            for (j = 0; j < 4; j = j + 1) begin
                $write("%4d ", bram_input_mem[i*4 + j]);
            end
            $write("\n");
        end

        // --- Tampilkan Matrix Output ---
        $display("\nMatrix Output (8x8) in BRAM:");
        for (i = 0; i < 8; i = i + 1) begin
            $write("Row %02d: ", i);
            for (j = 0; j < 8; j = j + 1) begin
                $write("%4d ", bram_output_mem[i*8 + j]);
            end
            $write("\n"); 
        end

        $display("--------------------------------");
        $finish;
    end

endmodule