`timescale 1ns / 1ps

module lfsr_noise_gen #(
    parameter DATA_WIDTH = 16,     // Output width (misal 16-bit)
    parameter SEED       = 32'hACE1_2345 // Seed tidak boleh 0
)(
    input  wire clk,
    input  wire rst_n,
    input  wire enable,
    output wire [DATA_WIDTH-1:0] noise_out,
    output reg  valid_out
);

    // Gunakan internal register 32-bit agar periode randomness sangat panjang
    // (2^32 - 1 cycles sebelum berulang), meskipun outputnya cuma 16-bit.
    reg [31:0] r_lfsr;
    
    // Polinomial Galois untuk 32-bit: x^32 + x^22 + x^2 + x^1 + 1
    // Taps hex: 0x80200003
    localparam [31:0] POLY_MASK = 32'h80200003;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_lfsr    <= SEED; 
            valid_out <= 0;
        end else if (enable) begin
            valid_out <= 1;
            
            // Galois LFSR Implementation
            // Jika LSB adalah 1, shift dan XOR dengan mask.
            // Jika LSB adalah 0, cukup shift.
            if (r_lfsr[0] == 1'b1) begin
                r_lfsr <= (r_lfsr >> 1) ^ POLY_MASK; 
            end else begin
                r_lfsr <= (r_lfsr >> 1);
            end
        end else begin
            valid_out <= 0;
        end
    end
    
    // OUTPUT MAPPING
    // Ambil bit-bit teratas (MSB) untuk kualitas randomness terbaik.
    // Jika DATA_WIDTH = 16, kita ambil r_lfsr[31:16]
    generate
        if (DATA_WIDTH < 32) begin
            assign noise_out = r_lfsr[31 : 32-DATA_WIDTH];
        end else begin
            // Jika output butuh > 32 bit, padding dengan 0 atau duplikasi (jarang terjadi)
            assign noise_out = { {(DATA_WIDTH-32){1'b0}}, r_lfsr };
        end
    endgenerate

endmodule