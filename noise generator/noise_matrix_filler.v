`include "lfsr_noise_gen.v"

module noise_matrix_filler #(
    parameter DATA_WIDTH = 16,
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
    
    // Register untuk menyimpan batas alamat
    reg [ADDR_WIDTH-1:0] addr_limit; 
    
    // Generator Noise
    lfsr_noise_gen #(
        .DATA_WIDTH(16), 
        .FRAC_WIDTH(13)
    ) noise_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable_lfsr),
        .noise_out(noise_val),
        .valid_out(noise_valid)
    );
    
    reg [ADDR_WIDTH-1:0] decoded_limit;
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

    assign bram_wdata = noise_val;
    assign bram_we = enable_lfsr && noise_valid; 

    
    // State Machine & Address Counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bram_addr <= 0;
            enable_lfsr <= 0;
            done <= 0;
            addr_limit <= 0;
        end else begin
            // Trigger Start
            if (start && !enable_lfsr && !done) begin
                enable_lfsr <= 1;
                bram_addr <= 0;
                done <= 0;
                addr_limit <= decoded_limit; 
            end 
            
            if (enable_lfsr) begin
                if (noise_valid) begin
                    if (bram_addr == addr_limit) begin
                        enable_lfsr <= 0;
                        done <= 1;
                    end else begin
                        bram_addr <= bram_addr + 1;
                    end
                end
            end else begin
                if (!start) done <= 0; // Reset done handshake
            end
        end
    end

endmodule

/*
Generator Noise LFSR :
noise sepanjang 16-bit, range [-2, 2] dihasilkan satu per cycle.
untuk 4x4, diperlukan 16 cycle.
Untuk 128x128, diperlukan 16384 cycle.
*/