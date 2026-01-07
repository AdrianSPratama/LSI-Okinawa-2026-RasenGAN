`timescale 1ns / 1ps

module lfsr_noise_gen #(
    parameter DATA_WIDTH = 16,
    parameter FRAC_WIDTH = 13,
    parameter SEED = 64'hACE1_2345_DEAD_BEEF // Nilai awal acak 
)(
    input wire clk,
    input wire rst_n,
    input wire enable,
    output wire [DATA_WIDTH-1:0] noise_out,
    output reg valid_out
);

    reg [DATA_WIDTH-1:0] r_lfsr;
    
    wire feedback;

    localparam [DATA_WIDTH-1:0] GALOIS_MASK = 64'hD800_0000_0000_0000;

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_lfsr <= SEED; 
            valid_out <= 0;
        end else if (enable) begin
            valid_out <= 1;
            // Galois LFSR Implementation
            
            if (r_lfsr[0] == 1'b1) begin
                r_lfsr <= (r_lfsr >> 1) ^ GALOIS_MASK; 
            end else begin
                r_lfsr <= (r_lfsr >> 1);
            end
        end else begin
            valid_out <= 0;
        end
    end
    
    assign noise_out = r_lfsr;

endmodule