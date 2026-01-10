`timescale 1ns/1ps

module tb_adain;

    // =========================================================================
    // 1. PARAMETER & KONFIGURASI (EDIT DI SINI)
    // =========================================================================
    parameter WIDTH_IN  = 48; // Q32.16
    parameter WIDTH_OUT = 16; // Q8.8
    parameter N_MAX     = 256;
    
    // --- Bagian Konfigurasi Cepat ---
    parameter N_VAL     = 4;                      // N = 4 (16 Piksel)
    localparam TOTAL_PX = N_VAL * N_VAL;          // Otomatis N^2
    
    reg clk, rst;
    reg [1:0] start;
    reg [$clog2(N_MAX+1)-1:0] N;
    reg [WIDTH_IN-1:0] in, ys, yb;
    wire [WIDTH_OUT-1:0] out;
    wire [1:0]           done;

    initial begin
    // Parameter normalisasi hasil randomize
    ys = 48'hFFFF_FFFF_53C9; // Desimal: -0.672712
    yb = 48'h0000_0000_BD46; // Desimal: 0.739349

    // Deretan isi x_mem random (16 data)
    x_mem[0] = 48'hFFFF_FFF8_BA54; x_mem[1] = 48'hFFFF_FFFD_D0F8;
    x_mem[2] = 48'hFFFF_FFFA_F406; x_mem[3] = 48'h0000_0006_B67B;
    x_mem[4] = 48'hFFFF_FFF1_EC82; x_mem[5] = 48'h0000_0009_63C5;
    x_mem[6] = 48'h0000_0009_10B0; x_mem[7] = 48'hFFFF_FFF0_3143;
    x_mem[8] = 48'hFFFF_FFFF_C8F0; x_mem[9] = 48'hFFFF_FFFC_1A0E;
    x_mem[10] = 48'hFFFF_FFF2_8BEB; x_mem[11] = 48'hFFFF_FFFE_0144;
    x_mem[12] = 48'h0000_0005_48EB; x_mem[13] = 48'hFFFF_FFF3_449A;
    x_mem[14] = 48'h0000_000B_4607; x_mem[15] = 48'hFFFF_FFF8_5B3A;
    end

    // =========================================================================
    // 2. INTERNAL LOGIC & INSTANTIATION
    // =========================================================================
    reg [WIDTH_IN-1:0] x_mem [0:N_MAX*N_MAX-1]; 
    reg [WIDTH_IN-1:0] in_delay [0:4]; 
    integer i, file_h, capture_count;
    reg capture_active;

    top_adain #(.WIDTH_IN(WIDTH_IN), .WIDTH_OUT(WIDTH_OUT), .N_MAX(N_MAX)) uut (
        .clk(clk), .rst(rst), .start(start), .N(N), .in(in), .ys(ys), .yb(yb), .out(out), .done(done)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (rst) for (i=0; i<5; i=i+1) in_delay[i] <= 0;
        else begin
            in_delay[0] <= in;
            in_delay[1] <= in_delay[0];
            in_delay[2] <= in_delay[1];
            in_delay[3] <= in_delay[2];
            in_delay[4] <= in_delay[3];
        end
    end

    // Task Push Data yang menyesuaikan dengan TOTAL_PX
    task push_data;
        begin
            for (integer j = 0; j < TOTAL_PX; j = j + 1) begin
                in <= x_mem[j];
                @(posedge clk);
            end
            in <= 0;
        end
    endtask

    // Logika Capture CSV (Black-Box)
    always @(posedge clk) begin
        if (rst) begin
            capture_active <= 0;
            capture_count  <= 0;
        end else begin
            if (done == 2'b11 && !capture_active) begin
                capture_active <= 1;
                capture_count  <= 0;
            end 
            if (capture_active) begin
                if (capture_count < TOTAL_PX) begin 
                    $fdisplay(file_h, "%h,%h,%h,%h", in_delay[3], out, ys, yb);
                    capture_count <= capture_count + 1;
                end else capture_active <= 0;
            end
        end
    end

    // =========================================================================
    // 3. STIMULUS UTAMA
    // =========================================================================
    initial begin
        file_h = $fopen("adain_results.csv", "w");
        $fdisplay(file_h, "Input_Hex_Q32_16,Output_Hex_Q8_8,ys_Hex_Q32_16,yb_Hex_Q32_16");

        rst = 1; start = 0; N = N_VAL; in = 0;
        repeat(5) @(posedge clk);
        rst <= 0;
        repeat(2) @(posedge clk);

        // STEP 1: MEAN
        start <= 2'b01; @(posedge clk); push_data(); start <= 2'b00;
        wait(done == 2'b01);
        repeat(5) @(posedge clk);

        // STEP 2: VAR, B1, B0
        start <= 2'b10; @(posedge clk); push_data(); start <= 2'b00;
        wait(done == 2'b10);
        repeat(5) @(posedge clk);

        // STEP 3: NORM & CAPTURE
        $display(">>> Running Normalization for N=%0d (%0d pixels)", N_VAL, TOTAL_PX);
        start <= 2'b11; @(posedge clk); push_data(); start <= 2'b00;
        
        wait(capture_count == TOTAL_PX);
        repeat(10) @(posedge clk);
        $fclose(file_h);
        $display(">>> Done. CSV saved.");
        $finish;
    end

endmodule