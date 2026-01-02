module reg_output #(parameter length = 12, number_of_row = 64)

(
    input wire clk,
    input wire rst,
    input wire en_write_out,
    input wire [3:0] write_mode,
    input wire [5:0] addr_output,

    input wire [length-1:0] data_in1,
    input wire [length-1:0] data_in2,
    input wire [length-1:0] data_in3,
    input wire [length-1:0] data_in4,

    input wire [length-1:0] data_in5,
    input wire [length-1:0] data_in6,
    input wire [length-1:0] data_in7,
    input wire [length-1:0] data_in8,
    input wire [length-1:0] data_in9,
    output reg [length*64 -1 :0] dout
);

    reg [length-1:0] memory [0:number_of_row-1];


    reg [5:0] offset_addr;

    reg [5:0] addr_write;


    always @(*) begin
        offset_addr = 6'b001000;
        addr_write = addr_output + offset_addr;

        dout = {memory[63], memory[62], memory[61], memory[60],
                memory[59], memory[58], memory[57], memory[56],
                memory[55], memory[54], memory[53], memory[52],
                memory[51], memory[50], memory[49], memory[48],
                memory[47], memory[46], memory[45], memory[44],
                memory[43], memory[42], memory[41], memory[40],
                memory[39], memory[38], memory[37], memory[36],
                memory[35], memory[34], memory[33], memory[32],
                memory[31], memory[30], memory[29], memory[28],
                memory[27], memory[26], memory[25], memory[24],
                memory[23], memory[22], memory[21], memory[20],
                memory[19], memory[18], memory[17], memory[16],
                memory[15], memory[14], memory[13], memory[12],
                memory[11], memory[10], memory[9],  memory[8],
                memory[7],  memory[6],  memory[5],  memory[4],
                memory[3],  memory[2],  memory[1],  memory[0]};
    end

    integer i;

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
                        memory[(offset_addr*2)] <= data_in8; // pojok kiri kedua


                        memory[addr_output + offset_addr] <= data_in1;
                        memory[addr_output + offset_addr + 1] <= data_in2;
                        memory[addr_output + offset_addr*2] <= data_in3;
                        memory[addr_output + offset_addr*2 + 1] <= data_in4;

                    end

                    4'b0001 : begin
                        memory[addr_output + offset_addr] <= data_in1;
                        memory[addr_output + offset_addr + 1] <= data_in2;
                        memory[addr_output + offset_addr*2] <= data_in3;
                        memory[addr_output + offset_addr*2 + 1] <= data_in4;

                        memory[addr_output] <= data_in5;
                        memory[addr_output + 1] <= data_in6;

                    end

                    4'b0010 : begin

                        memory[offset_addr - 1] <= data_in9; // pojok kanan atas

                        memory[addr_output] <= data_in5; // pojok atas kedua
                        memory[addr_output + 1] <= data_in6; // pojok atas ketiga

                        memory[addr_output + offset_addr + 2] <= data_in7; // pojok kanan satu
                        memory[addr_output + (offset_addr*2) + 2] <= data_in8; // pojok kanan kedua


                        memory[addr_output + offset_addr] <= data_in1;
                        memory[addr_output + offset_addr + 1] <= data_in2;
                        memory[addr_output + offset_addr*2] <= data_in3;
                        memory[addr_output + offset_addr*2 + 1] <= data_in4;
                        
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