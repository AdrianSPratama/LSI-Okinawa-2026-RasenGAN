module reg_input #(parameter length = 16)
(
    input wire clk,
    input wire rst,

    input wire [2:0] size_upsample,

    input wire [length-1:0] din,

    input wire en_write_in,

    output reg [length-1:0] dout1,
    output reg [length-1:0] dout2, // Sekarang menjadi output register BRAM
    output reg [length-1:0] dout3,
    output reg [length-1:0] dout4
);

    reg [7:0] kolom;
    reg [7:0] batas_kolom;
    reg x;

    reg [7:0] s_kolom;

    // Definisi BRAM
    (* ram_style = "block" *) reg [length - 1:0] prev_row [0:127];

    // Logic untuk batas_kolom (Combinational)
    always @(*) begin
        case (size_upsample)
            3'b000: batas_kolom = 8'b00000011; // 4x4
            3'b001: batas_kolom = 8'b00000111; // 8x8
            3'b010: batas_kolom = 8'b00001111; // 16x16
            3'b011: batas_kolom = 8'b00011111; // 32x32
            3'b100: batas_kolom = 8'b00111111; // 64x64
            default: batas_kolom = 8'b00000000;
        endcase
        
        // dout4 hanyalah pass-through dari din
        dout4 = din; 
    end

    // Logic Sequential (Clocked) - Termasuk Read/Write BRAM
    always @(posedge clk) begin
        
        // -----------------------------------------------------------
        // 1. BRAM READ OPERATION (Synchronous)
        // -----------------------------------------------------------
        // Kita membaca memori setiap cycle. 
        // Karena 'x' toggle, alamat 'kolom' stabil setidaknya 1 cycle sebelum 'x=1'.
        // Ini menjamin 'dout2' berisi data valid saat logic write (x=1) dijalankan.
        dout2 <= prev_row[s_kolom];

        // -----------------------------------------------------------
        // 2. MAIN LOGIC & BRAM WRITE
        // -----------------------------------------------------------
        if (!rst) begin
            dout1 <= 0; // Tambahan inisialisasi agar bersih
            dout3 <= 0;
            kolom <= 0;
            s_kolom <= 0;
            x <= 1'b1;
        end else begin
            
            x <= ~x; // Toggle setiap clock

            if ((x && en_write_in)) begin
                // Shift data logic
                dout3 <= din;
                
                // dout1 mengambil nilai dout2.
                // Karena dout2 sudah di-update di cycle sebelumnya (saat x=0),
                // nilainya valid dan sesuai dengan alamat 'kolom' saat ini.
                dout1 <= dout2; 

                // BRAM Write Operation
                // Menulis data baru (din) ke alamat kolom saat ini
                prev_row[kolom] <= din;

                // Increment Address
                kolom <= kolom + 1;
            end

            if (~x && en_write_in) begin
                // Hanya increment kolom saat x=0 dan en_write_in aktif
                s_kolom <= s_kolom + 1;
            end

            // Reset kolom jika melebihi batas (Logic wrap-around)
            // Cek dilakukan setelah increment
            if (kolom > batas_kolom) begin
                kolom <= 0;
            end

            if (s_kolom > batas_kolom) begin
                s_kolom <= 0;
            end
        end
    end

endmodule