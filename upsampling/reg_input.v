module reg_input #(parameter length = 12, number_of_row = 16)
(
    input wire clk,
    input wire rst,
    input wire [5:0] addr_input,
    input wire en_write_in,
    input wire [length*16-1:0] din,
    output reg [length-1:0] dout1,
    output reg [length-1:0] dout2,
    output reg [length-1:0] dout3,
    output reg [length-1:0] dout4
);

    reg [length-1:0] memory [0:15];

    reg [3:0] offset_addr;

    integer i;

    always @(posedge clk or negedge clk) begin
        if (!rst) begin
            for (i = 0; i < number_of_row; i = i + 1) begin
                memory[i] <= {length{1'b0}};
            end
            
        end else begin
            if (en_write_in) begin
                for (i = 0; i < 16; i = i + 1) begin
                    memory[i] <= din[length*i +: length];
                end
            end

            offset_addr = 4'b0100;

            dout1 <= memory[addr_input];
            dout2 <= memory[addr_input + 1];
            dout3 <= memory[addr_input + offset_addr];
            dout4 <= memory[addr_input + offset_addr + 1];
            
        end
    end
endmodule;