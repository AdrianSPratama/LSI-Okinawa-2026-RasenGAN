`timescale 1ns/1ps

module tb_adain;

    // =========================================================================
    // 1. PARAMETER & KONFIGURASI
    // =========================================================================
    parameter WIDTH_IN  = 48; // Q32.16
    parameter WIDTH_OUT = 16; // Q8.8
    parameter N_MAX     = 128;
    
    parameter N_VAL     = 2;                       
    localparam TOTAL_PX = N_VAL * N_VAL;           
    
    reg clk, rst;
    reg [1:0] start;
    reg [$clog2(N_MAX+1)-1:0] N;
    reg [WIDTH_IN-1:0] in, ys, yb;
    wire [WIDTH_OUT-1:0] out;
    wire [1:0]           done;

    reg [WIDTH_IN-1:0] x_mem [0:TOTAL_PX-1]; 
    reg [WIDTH_IN-1:0] in_delay [0:4]; 
    integer i, file_h, capture_count; 
    reg record_csv; 

    initial begin
        ys = 48'h0000_0001_0000; 
        yb = 48'h0000_0000_0000; 
        x_mem[0] = 48'h0000_0001_0000; 
        x_mem[1] = 48'h0000_0002_0000;
        x_mem[2] = 48'h0000_0003_0000; 
        x_mem[3] = 48'h0000_0004_0000;

    end

    // =========================================================================
    // 2. INSTANTIATION
    // =========================================================================
    top_adain #(
        .WIDTH_IN(WIDTH_IN), .WIDTH_OUT(WIDTH_OUT), .N_MAX(N_MAX)
    ) uut (
        .clk(clk), .rst(rst), .start(start), .N(N), 
        .in(in), .ys(ys), .yb(yb), .out(out), .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    // Kompensasi latensi pipa agar input sinkron dengan output di CSV
    always @(posedge clk) begin
        if (rst) begin
            for (i=0; i<5; i=i+1) in_delay[i] <= 0;
        end else begin
            in_delay[0] <= in;
            in_delay[1] <= in_delay[0];
            in_delay[2] <= in_delay[1];
            in_delay[3] <= in_delay[2];
            in_delay[4] <= in_delay[3];
        end
    end

    // TASK: Sesuai permintaan, bus 'in' dibiarkan memegang data terakhir
    task push_data;
        integer j;
        begin
            for (j = 0; j < TOTAL_PX; j = j + 1) begin
                in <= x_mem[j];
                @(posedge clk);
            end
            // in <= 0; // DIHAPUS: Bus tetap memegang x_mem[3]
        end
    endtask

    // =========================================================================
    // 3. LOGIKA CAPTURE DATA (Trigger: done >= 2'b10)
    // =========================================================================
    always @(posedge clk) begin
        // Menangkap data piksel terakhir meskipun done sudah berpindah ke 3 (2'b11)
        if (record_csv && done >= 2'b10 && capture_count < TOTAL_PX) begin
            $fdisplay(file_h, "%h,%h,%h,%h", in_delay[4], out, ys, yb);
            $display("Time: %0t | Captured Px %0d | In: %h | Out: %h", 
                      $time, capture_count+1, in_delay[4], out);
            capture_count <= capture_count + 1;
        end
    end

    // =========================================================================
    // 4. STIMULUS UTAMA
    // =========================================================================
    initial begin
        file_h = $fopen("adain_results.csv", "w");
        $fdisplay(file_h, "Input_Hex_Q32_16,Output_Hex_Q8_8,ys_Hex_Q32_16,yb_Hex_Q32_16");
        
        $display(">>> Memulai Simulasi AdaIN 2x2");
        rst = 1; start = 0; N = N_VAL; in = 0; capture_count = 0; record_csv = 1;
        @(posedge clk);
        rst <= 0;
        
        // --- ITERASI 1: SCANNING + NORMALIZING (Simpan ke CSV) ---
        $display(">>> Iterasi 1 Dimulai (Recording)...");
        @(posedge clk); start <= 2'b01; push_data(); start <= 2'b00;
        wait(done == 2'b01);
        
        @(posedge clk); start <= 2'b10; push_data(); start <= 2'b00;
        
        // Tunggu semua piksel tertangkap sebelum menutup file
        wait(capture_count == TOTAL_PX); 
        
        $display(">>> Iterasi 1 Selesai. Menutup file CSV.");
        record_csv = 0; 
        $fclose(file_h);

        // --- ITERASI 2: HANYA UNTUK WAVEFORM (Tanpa CSV) ---
        $display(">>> Iterasi 2 Dimulai (Waveform Only)...");
        repeat(10) @(posedge clk);
        
        @(posedge clk); start <= 2'b01; push_data(); start <= 2'b00;
        wait(done == 2'b01);
        
        @(posedge clk); start <= 2'b10; push_data(); start <= 2'b00;
        wait(done == 2'b11);
        @(posedge clk);

        $display(">>> Simulasi Selesai.");
        $finish;
    end

endmodule