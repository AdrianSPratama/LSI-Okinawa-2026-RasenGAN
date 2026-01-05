`timescale 1ns / 1ps

module lfsr_noise_gen #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 13,
    parameter SEED = 32'hACE1_2345 // Nilai awal acak 
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    output wire signed [DATA_WIDTH-1:0] noise_out,
    output reg valid_out
);

    // LFSR 32-bit  Feedback Galois
    // Polynomial: x^32 + x^22 + x^2 + x^1 + 1
    // Taps position untuk Galois: 32, 22, 2, 1
    reg [31:0] r_lfsr;
    
    wire feedback;

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_lfsr <= SEED; 
            valid_out <= 0;
        end else if (enable) begin
            valid_out <= 1;
            // Galois LFSR Implementation
            
            if (r_lfsr[0] == 1'b1) begin
                r_lfsr <= (r_lfsr >> 1) ^ 32'h80200003; 
            end else begin
                r_lfsr <= (r_lfsr >> 1);
            end
        end else begin
            valid_out <= 0;
        end
    end
    
    
    wire signed [DATA_WIDTH-1:0] raw_slice;
    assign raw_slice = r_lfsr[15:0]; 
    
    assign noise_out = raw_slice >>> 1;

endmodule