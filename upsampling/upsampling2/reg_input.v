module reg_input #(parameter length = 16)
(
    input wire clk,
    input wire rst,

    input wire [2:0] size_upsample,

    input wire [length-1:0] din,

    input wire en_write_in,

    output reg [length-1:0] dout1,
    output reg [length-1:0] dout2,
    output reg [length-1:0] dout3,
    output reg [length-1:0] dout4
);

reg [7:0] kolom;
reg [7:0] batas_kolom;
reg x;

(* ram_style = "block" *) reg [length - 1:0] prev_row [0:127]; // assuming max 128 elements per row

    always @(posedge clk) begin
        if (!rst) begin
            dout3 <= 0;
            kolom <= 0;
            x <= 1'b1;
        end else begin

            x <= ~x;

            if ((x && en_write_in )) begin
            dout3 <= din;
            dout1 <= dout2;
            kolom <= kolom + 1;
            prev_row[kolom] <= din;
            end

            // if ((~x && en_write_in )) begin
            
            
            // end

            
            
            
            
            


            if (kolom > batas_kolom) begin
                kolom <= 0;
            end

        end
    end
    
    always @(*) begin
        dout2 = prev_row[kolom];
        dout4 = din;

        case (size_upsample)
        3'b000: begin
            batas_kolom = 8'b00000011; // 4x4
        end
        3'b001: begin
            batas_kolom = 8'b00000111; // 8x8
        end

        3'b010: begin
            batas_kolom = 8'b00001111; // 16x16
        end

        3'b011: begin
            batas_kolom = 8'b00011111; // 32x32
        end
        3'b100: begin
            batas_kolom = 8'b00111111; // 64x64
        end
        default: begin
            batas_kolom = 8'b00000000;
        end

        endcase

    end
endmodule;