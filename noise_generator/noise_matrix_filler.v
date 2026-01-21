`include "lfsr_noise_gen.v"

module noise_matrix_filler #(
    parameter DATA_WIDTH = 16, // Ubah default ke 16 sesuai spesifikasi [-2, 2]
    parameter ADDR_WIDTH = 14 
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] size,
    
    output reg [ADDR_WIDTH-1:0] bram_addr,
    output wire [DATA_WIDTH-1:0] bram_wdata,
    output wire bram_we,           
    
    output reg done
);

    // Internal Signals
    wire noise_valid;
    wire [DATA_WIDTH-1:0] noise_val;
    reg enable_lfsr;
    
    reg [ADDR_WIDTH-1:0] addr_limit; 
    
    // Generator Noise
    // Pastikan parameter DATA_WIDTH diteruskan dengan benar
    lfsr_noise_gen #(
        .DATA_WIDTH(DATA_WIDTH)
    ) noise_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_lfsr),
        .noise_out(noise_val),
        .valid_out(noise_valid)
    );
    
    reg [ADDR_WIDTH-1:0] decoded_limit;
    
    // Decoder ukuran matriks
    always @(*) begin
        case (size)
            3'b000: decoded_limit = 14'd15;    // 4x4
            3'b001: decoded_limit = 14'd63;    // 8x8
            3'b010: decoded_limit = 14'd255;   // 16x16
            3'b011: decoded_limit = 14'd1023;  // 32x32
            3'b100: decoded_limit = 14'd4095;  // 64x64
            3'b101: decoded_limit = 14'd16383; // 128x128
            default: decoded_limit = 14'd16383;
        endcase
    end

    // Handling Range [-2, 2]
    /* CATATAN IMPLEMENTASI:
       Jika format data adalah Fixed Point Q3.13 (1 bit sign, 2 bit integer, 13 bit frac),
       Maka full 16-bit random akan menghasilkan range [-4, 4) secara matematis.
       
       Jika Anda ingin STRICTLY [-2, 2], Anda bisa melakukan right shift (div 2)
       pada output noise, atau memastikan bit MSB ke-2 (integer bit tertinggi) selalu sama dengan bit sign.
       
       Di bawah ini adalah implementasi raw (full range). 
       Jika ingin memperkecil range menjadi setengahnya, ubah assign di bawah:
       assign bram_wdata = {noise_val[DATA_WIDTH-1], noise_val[DATA_WIDTH-1:1]}; // Arithmetic Shift Right
    */
    assign bram_wdata = noise_val; 
    assign bram_we = enable_lfsr && noise_valid; 

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bram_addr   <= 0;
            enable_lfsr <= 0;
            done        <= 0;
            addr_limit  <= 0;
        end else begin
            // Start logic
            if (start && !enable_lfsr && !done) begin
                enable_lfsr <= 1;
                bram_addr   <= 0;
                done        <= 0;
                addr_limit  <= decoded_limit; 
            end 
            
            if (enable_lfsr) begin
                if (noise_valid) begin
                    if (bram_addr == addr_limit) begin
                        enable_lfsr <= 0;
                        done        <= 1;
                    end else begin
                        bram_addr   <= bram_addr + 1;
                    end
                end
            end else begin
                if (!start) done <= 0; // Handshake reset
            end
        end
    end

endmodule