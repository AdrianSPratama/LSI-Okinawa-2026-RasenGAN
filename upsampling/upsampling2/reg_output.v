module reg_output #(parameter length = 16)

(
    input wire clk,
    input wire rst,
    input wire [3:0] write_mode,
    
    input wire row_even,
    input wire coloumn_even,
    input wire [7:0] kolom,

    input wire [length-1:0] data_in1,
    input wire [length-1:0] data_in2,
    input wire [length-1:0] data_in3,
    input wire [length-1:0] data_in4,

    input wire [length-1:0] data_in5,
    input wire [length-1:0] data_in6,
    input wire [length-1:0] data_in7,
    input wire [length-1:0] data_in8,
    input wire [length-1:0] data_in9,

    output reg [length-1:0] dout
);
    reg [length-1:0] temp_dout [0:127];

    always @(*) begin

        case (write_mode)

                    4'b0000 : begin
                        dout = data_in9;
                    end

                    4'b0001 : begin
                        // if coloumn_even, dout = data_in5 else data_in6
                        dout = coloumn_even ? data_in6 : data_in5;
                    end

                    4'b0010 : begin
                        dout = data_in9;
                    end

                    4'b0011 : begin
                        dout = row_even ? data_in7 : temp_dout[kolom];
                        
                    end

                    4'b0100 : begin

                        if (coloumn_even == 1'b0) begin
                            if (row_even == 1'b1) begin
                                dout = data_in1;
                            end else begin
                                dout = temp_dout[kolom];
                            end
                        end else begin
                            if (row_even == 1'b1) begin
                                dout = data_in2;
                            end else begin
                                dout = temp_dout[kolom];
                            end
                        end
                        
                    end

                    4'b0101 : begin
                        dout = row_even ? data_in7 : temp_dout[kolom];

                    end

                    4'b0110 : begin
                        dout = data_in9;
                    end


                    4'b0111 : begin
                        dout = coloumn_even ? data_in6 : data_in5;
                    end

                    4'b1000 : begin
                        dout = data_in9;
                    end

                default : begin
                        // do nothing
                    end

                endcase;
        

    end

    always @(posedge clk) begin
        if (!rst) begin
            temp_dout[0] <= 0;
        end else begin
            case (write_mode) 

            4'b0100 : begin
            if (coloumn_even == 1'b0) begin
                    temp_dout[kolom] <= data_in3;
                    end

            else begin
                    temp_dout[kolom] <= data_in4;
                end
            end

            default : begin
                temp_dout[kolom] <= data_in8;

            end

            endcase
        end

    end


endmodule;