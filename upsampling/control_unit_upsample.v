module control_unit_upsample(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [2:0] size_upsample,
    output reg done,
    output reg [3:0] write_mode,
    output reg en_write_in,
    output reg en_write_out,
    output reg [13:0] addr_input,
    output reg [13:0] addr_output
);

    reg [5:0] STATE;
    reg [5:0] NEXT_STATE;

    reg [13:0] counter;
    reg en_counter;
    reg [13:0] offset_addr;
    reg [7:0] offset_change;
    reg [7:0] number_of_row;

    localparam IDLE      = 6'b000000;
    localparam LOAD      = 6'b000001;
    localparam MODE1     = 6'b000010;
    localparam MODE2     = 6'b000011;
    localparam MODE3     = 6'b000100;
    localparam DONE      = 6'b000101;

    reg [7:0] baris;
    reg [7:0] kolom;

    reg [7:0] batas_kolom;

    always @(posedge clk ) begin
        if (!rst) begin
            STATE <= 6'b0;
            counter <= 14'b0;
            baris <= 8'b0;
            kolom <= 8'b0;
            offset_addr <= (number_of_row<<1);


        end else begin
            STATE <= NEXT_STATE;
            if (en_counter) begin
                kolom <= kolom + 1;
            end 

            if (kolom == batas_kolom) begin
            offset_addr <= offset_addr + offset_change;
            baris <= baris + 1;
            kolom <= kolom + 1;
            kolom <= 8'b0;
            
            end

        end
    end

    always @(*) begin
    case (STATE) 

    IDLE : begin
        done <= 1'b0;
        en_write_in <= 1'b0;
        en_write_out <= 1'b0;
        addr_input <= 14'b0;
        addr_output <= 14'b0;
        write_mode <= 4'b0000;
        en_counter <= 1'b0;

        if (start) begin
            NEXT_STATE <= LOAD;
        end else begin
            NEXT_STATE <= IDLE;
        end
    end

    LOAD : begin

        en_write_in <= 1'b1;

        write_mode <= 4'b0000;

        addr_output = 14'b0;

        NEXT_STATE <= MODE1;

    end

    MODE1 : begin

        en_write_in <= 1'b0;
        en_write_out <= 1'b1;

        en_counter <= 1'b1;
        
        case (kolom) 
            0 : begin
                write_mode <= 4'b0000;
            end

            batas_kolom : begin
                write_mode <= 4'b0010;
                NEXT_STATE <= MODE2;
            end

            default : begin
                write_mode <= 4'b0001;
            end

        endcase

    end


    MODE2 : begin

        en_write_in <= 1'b0;
        en_write_out <= 1'b1;

        en_counter <= 1'b1;

        case (kolom) 
            0 : begin
                write_mode <= 4'b0011;
            end

            batas_kolom : begin
                write_mode <= 4'b0101;
                if (baris == number_of_row - 3) begin
                NEXT_STATE <= MODE3;
        end
            end

            default : begin
                write_mode <= 4'b0100;
            end

        endcase

        

    end


    MODE3 : begin

        en_write_in <= 1'b0;
        en_write_out <= 1'b1;

        en_counter <= 1'b1;
        case (kolom) 
            0 : begin
                write_mode <= 4'b0110;
            end

            batas_kolom : begin
                write_mode <= 4'b1000;
                NEXT_STATE <= DONE;
            end

            default : begin
                write_mode <= 4'b0111;
                
            end

        endcase


    end

    DONE : begin
        done <= 1'b1;
        en_write_out <= 1'b0;

        NEXT_STATE <= IDLE;

    end

    default : begin
            NEXT_STATE = IDLE;
        end


    endcase
    
    case (size_upsample)
        3'b000: begin
            batas_kolom = 8'b00000010; // 4x4
            offset_change = 8'b00001000;
            number_of_row = 8'b00000100;
        end
        3'b001: begin
            batas_kolom = 8'b00000110; // 8x8
            offset_change = 8'b00010000;
            number_of_row = 8'b00001000;
        end

        3'b010: begin
            batas_kolom = 8'b00001110; // 16x16
            offset_change = 8'b00100000;
            number_of_row = 8'b00010000;
        end

        3'b011: begin
            batas_kolom = 8'b00011110; // 32x32
            offset_change = 8'b01000000;
            number_of_row = 8'b00100000;
        end
        3'b100: begin
            batas_kolom = 8'b00111110; // 64x64
            offset_change = 8'b10000000;
            number_of_row = 8'b01000000;
        end
        default: begin
            batas_kolom = 8'b00000000;
            offset_change = 8'b00000000;
        end

        

    endcase

    addr_input = (number_of_row * baris) + kolom;
    counter = (baris * number_of_row) + kolom;
    addr_output = (counter << 1) + offset_addr + 1;

    end

endmodule