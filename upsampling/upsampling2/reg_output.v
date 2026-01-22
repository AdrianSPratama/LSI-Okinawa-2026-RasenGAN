module reg_output #(parameter length = 16)
(
    input wire clk,
    input wire rst,
    input wire [3:0] write_mode,
    
    input wire row_even,
    input wire coloumn_even,
    input wire [7:0] kolom,
    input wire [7:0] s_kolom,

    input wire [length-1:0] data_in1,
    input wire [length-1:0] data_in2,
    input wire [length-1:0] data_in3,
    input wire [length-1:0] data_in4,

    input wire [length-1:0] data_in5,
    input wire [length-1:0] data_in6,
    input wire [length-1:0] data_in7,
    input wire [length-1:0] data_in8,
    input wire [length-1:0] data_in9,

    output reg [length-1:0] dout
);

    // reg [7:0] s_kolom;

    // ==========================================
    // DEFINISI BRAM
    // ==========================================
    // Atribut ini memberi tahu tool synthesis untuk menggunakan Block RAM
    (* ram_style = "block" *) reg [length-1:0] temp_dout [0:127];
    
    // Variabel penampung hasil bacaan BRAM (Synchronous output)
    reg [length-1:0] bram_read_data;

    // ==========================================
    // SYNCHRONOUS PROCESS (Read & Write BRAM)
    // ==========================================
    always @(posedge clk) begin
        // 1. MEMORY READ OPERATION
        // Data akan tersedia di 'bram_read_data' pada clock edge berikutnya.
        // Ini menciptakan Latency 1 Clock Cycle.
        bram_read_data <= temp_dout[s_kolom];

        // 2. MEMORY WRITE OPERATION
        // Catatan: Reset array memori dihapus agar valid menjadi BRAM.
        if (rst) begin
            // Logic Write sesuai kode asli Anda
            case (write_mode) 
                4'b0100 : begin
                    if (coloumn_even == 1'b0) begin
                        temp_dout[kolom] <= data_in3;
                    end else begin
                        temp_dout[kolom] <= data_in4;
                    end
                end

                default : begin
                    // Pada kode asli, semua mode selain 0100 menulis data_in8
                    // Pastikan ini memang logic yang diinginkan
                    temp_dout[kolom] <= data_in8;
                end
            endcase
        end
    end

    // ==========================================
    // COMBINATIONAL OUTPUT LOGIC
    // ==========================================
    always @(*) begin
        case (write_mode)

            4'b0000 : begin
                dout = data_in9;
            end

            4'b0001 : begin
                dout = coloumn_even ? data_in6 : data_in5;
            end

            4'b0010 : begin
                dout = data_in9;
            end

            4'b0011 : begin
                // Menggunakan bram_read_data (hasil bacaan sync)
                dout = row_even ? data_in7 : bram_read_data; 
            end

            4'b0100 : begin
                if (coloumn_even == 1'b0) begin
                    if (row_even == 1'b1) begin
                        dout = data_in1;
                    end else begin
                        // Menggunakan bram_read_data
                        dout = bram_read_data;
                    end
                end else begin
                    if (row_even == 1'b1) begin
                        dout = data_in2;
                    end else begin
                        // Menggunakan bram_read_data
                        dout = bram_read_data;
                    end
                end
            end

            4'b0101 : begin
                // Menggunakan bram_read_data
                dout = row_even ? data_in7 : bram_read_data;
            end

            4'b0110 : begin
                dout = data_in9;
            end

            4'b0111 : begin
                dout = coloumn_even ? data_in6 : data_in5;
            end

            4'b1000 : begin
                dout = data_in9;
            end

            default : begin
                // Good practice: assign default value to prevent latches
                dout = {length{1'b0}}; 
            end

        endcase
    end

endmodule