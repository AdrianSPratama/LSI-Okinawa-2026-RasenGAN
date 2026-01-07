module reg_output #(parameter length = 16, number_of_row = 256)

(
    input wire clk,
    input wire rst,
    input wire en_write_out,
    input wire [3:0] write_mode,
    input wire [13:0] addr_output,

    input wire [2:0] size_upsample,

    input wire [length-1:0] data_in1,
    input wire [length-1:0] data_in2,
    input wire [length-1:0] data_in3,
    input wire [length-1:0] data_in4,

    input wire [length-1:0] data_in5,
    input wire [length-1:0] data_in6,
    input wire [length-1:0] data_in7,
    input wire [length-1:0] data_in8,
    input wire [length-1:0] data_in9,
    output reg [length*256 -1 :0] dout
);

    reg [length-1:0] memory [0:number_of_row-1];


    reg [7:0] offset_addr;

    reg [13:0] addr_write;

    
    integer i;
    always @(*) begin
        case (size_upsample)

                3'b000: offset_addr = 8'b00001000; // 4x4
                3'b001: offset_addr = 8'b00010000; // 8x8
                3'b010: offset_addr = 8'b00100000; // 16x16
                3'b011: offset_addr = 8'b01000000; // 32x32
                3'b100: offset_addr = 8'b10000000; // 64x64
                default: offset_addr = 8'b00000000;
        endcase

        addr_write = addr_output + offset_addr;

        for (i = 0; i < number_of_row; i = i + 1) begin
            dout[length*i +: length] = memory[i];
        end

    end

    

    always @(posedge clk) begin
        if (!rst) begin
            
            for (i = 0; i < number_of_row; i = i + 1) begin
                memory[i] <= {length{1'b0}};
            end
        end 
        else begin
            if (en_write_out) begin
                
                case (write_mode)

                    4'b0000 : begin
                        memory[0] <= data_in9; // pojok kiri atas
                        
                        memory[1] <= data_in5; // pojok atas kedua
                        memory[2] <= data_in6; // pojok atas ketiga
                
                        memory[offset_addr] <= data_in7; // pojok kiri satu
                        memory[((offset_addr<<1))] <= data_in8; // pojok kiri kedua


                        memory[addr_output ] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + (offset_addr)] <= data_in3;
                        memory[addr_output + (offset_addr) + 1] <= data_in4;

                    end

                    4'b0001 : begin
                        memory[addr_output] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + (offset_addr)] <= data_in3;
                        memory[addr_output + (offset_addr) + 1] <= data_in4;

                        memory[addr_output - offset_addr] <= data_in5;
                        memory[addr_output + 1 - offset_addr] <= data_in6;

                    end

                    4'b0010 : begin

                        memory[offset_addr - 1] <= data_in9; // pojok kanan atas

                        memory[addr_output - offset_addr] <= data_in5; // pojok atas kedua
                        memory[addr_output + 1 - offset_addr] <= data_in6; // pojok atas ketiga

                        memory[addr_output + 2] <= data_in7; // pojok kanan satu
                        memory[addr_output + (offset_addr) + 2] <= data_in8; // pojok kanan kedua


                        memory[addr_output ] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + (offset_addr)] <= data_in3;
                        memory[addr_output + (offset_addr) + 1] <= data_in4;
                        
                    end

                    4'b0011 : begin

                        memory[addr_output] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + offset_addr] <= data_in3;
                        memory[addr_output + offset_addr + 1] <= data_in4;

                        memory[addr_output - 1] <= data_in7;
                        memory[addr_output + offset_addr - 1] <= data_in8;
                    end

                    4'b0100 : begin
                        memory[addr_output] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + offset_addr] <= data_in3;
                        memory[addr_output + offset_addr + 1] <= data_in4;
                    end

                    4'b0101 : begin
                        memory[addr_output] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + offset_addr] <= data_in3;
                        memory[addr_output + offset_addr + 1] <= data_in4;

                        memory[addr_output + 2] <= data_in7;
                        memory[addr_output + offset_addr + 2] <= data_in8;
                    end


                    4'b0110 : begin
                        memory[addr_output] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + offset_addr] <= data_in3;
                        memory[addr_output + offset_addr + 1] <= data_in4;

                        memory[addr_output - 1] <= data_in7;
                        memory[addr_output + offset_addr - 1] <= data_in8;

                        memory[addr_output + offset_addr*2 - 1] <= data_in9;

                        memory[addr_output + 2*offset_addr] <= data_in5;
                        memory[addr_output + 2*offset_addr + 1] <= data_in6;
                    end


                    4'b0111 : begin
                        memory[addr_output] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + offset_addr] <= data_in3;
                        memory[addr_output + offset_addr + 1] <= data_in4;

                        memory[addr_output + 2*offset_addr] <= data_in5;
                        memory[addr_output + 2*offset_addr + 1] <= data_in6;
                    end

                    4'b1000 : begin
                        memory[addr_output] <= data_in1;
                        memory[addr_output + 1] <= data_in2;
                        memory[addr_output + offset_addr] <= data_in3;
                        memory[addr_output + offset_addr + 1] <= data_in4;

                        memory[addr_output + 2] <= data_in7;
                        memory[addr_output + offset_addr + 2] <= data_in8;

                        memory[addr_output + offset_addr*2 + 2] <= data_in9;

                        memory[addr_output + 2*offset_addr] <= data_in5;
                        memory[addr_output + 2*offset_addr + 1] <= data_in6;
                    end

                default : begin
                        // do nothing
                    end

                endcase;
            end
        end
    end

endmodule;