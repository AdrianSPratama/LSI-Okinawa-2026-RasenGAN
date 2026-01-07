module reg_input #(parameter length = 16, number_of_row = 64)
(
    input wire clk,
    input wire rst,
    input wire [13:0] addr_input,
    input wire en_write_in,
    input wire [2:0] size_upsample,
    input wire [length*64-1:0] din,
    output reg [length-1:0] dout1,
    output reg [length-1:0] dout2,
    output reg [length-1:0] dout3,
    output reg [length-1:0] dout4
);

    reg [13:0] x;

    reg [length-1:0] memory [0:63];

    reg [7:0] offset_addr;

    integer i;

    always @(posedge clk or negedge clk) begin
        if (!rst) begin
            for (i = 0; i < number_of_row; i = i + 1) begin
                memory[i] <= {length{1'b0}};
            end
            
        end else begin
            if (en_write_in) begin
                for (i = 0; i < number_of_row; i = i + 1) begin
                    memory[i] <= din[length*i +: length];
                end
            end

            case (size_upsample)

                3'b000: offset_addr = 8'b00000100; // 4x4
                3'b001: offset_addr = 8'b00001000; // 8x8
                3'b010: offset_addr = 8'b00010000; // 16x16
                3'b011: offset_addr = 8'b00100000; // 32x32
                3'b100: offset_addr = 8'b01000000; // 64x64
                default: offset_addr = 8'b00000000;
            endcase

            dout1 <= memory[addr_input];
            dout2 <= memory[addr_input + 1];
            dout3 <= memory[addr_input + offset_addr];
            dout4 <= memory[addr_input + offset_addr + 1];
            
        end
    end
endmodule;