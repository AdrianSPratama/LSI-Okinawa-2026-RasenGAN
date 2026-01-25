`timescale 1ns/1ps

module tb_mux_nto1;

    // Parameter pengetesan
    parameter N = 5;          
    parameter WIDTH = 48;     

    // Sinyal Testbench
    reg [$clog2(N)-1:0] sel;
    reg [N*WIDTH-1:0] in_bus;
    wire [WIDTH-1:0] out;

    // Deklarasi variabel loop di luar blok initial/for
    integer i;

    // Instansiasi Unit Under Test (UUT)
    // Nama modul diubah menjadi mux_nto1 sesuai permintaan
    mux_nto1 #(
        .N(N),
        .WIDTH(WIDTH)
    ) uut (
        .sel(sel),
        .in(in_bus),
        .out(out)
    );

    // Prosedur Stimulus
    initial begin
        // 1. Inisialisasi input: in0=0 s/d in4=4
        // Disusun secara concatenation {in4, in3, in2, in1, in0}
        in_bus = { 
            48'd4, // in4
            48'd3, // in3
            48'd2, // in2
            48'd1, // in1
            48'd0  // in0
        };

        $display("--- Memulai Simulasi MUX N-to-1 ---");
        $display("Time | Sel | Output (Hex) | Output (Dec)");
        $display("-------------------------------------------");

        // 2. Iterasi Selector 0 hingga 5
        // Menggunakan variabel 'i' yang sudah dideklarasikan sebelumnya
        for (i = 0; i <= 5; i = i + 1) begin
            sel = i;
            #10; // Tunggu delay propagasi
            
            $display("%4t |  %d  | %h | %d", 
                     $time, sel, out, out);
            
            // Verifikasi Logika
            if (i < N) begin
                if (out !== i) $display("Error: Sel %d harusnya %d", i, i);
            end else begin
                // Cek apakah padding ke 0 berfungsi untuk sel > N
                if (out !== 48'd0) $display("Error: Sel %d (Default) harusnya 0", i);
            end
        end

        #20;
        $display("-------------------------------------------");
        $display("Simulasi Selesai.");
        $finish;
    end

endmodule