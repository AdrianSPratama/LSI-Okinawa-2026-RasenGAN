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
    output reg [13:0] addr_output,
    output reg [7:0] kolom,
    output reg [7:0] s_kolom,

    output wire row_even,
    output wire coloumn_even
);

    reg [5:0] STATE;
    reg [5:0] NEXT_STATE;
    reg en_counter;
    reg [13:0] offset_addr;
    reg [7:0] number_of_row;

    reg en_s_kolom;

    localparam IDLE      = 6'b000000;
    localparam LOAD      = 6'b000001;
    localparam MODE1     = 6'b000010;
    localparam MODE2     = 6'b000011;
    localparam MODE3     = 6'b000100;
    localparam DONE      = 6'b000101;

    reg [7:0] baris;
    // reg [7:0] kolom;

    reg [7:0] batas_kolom;

    assign row_even = ~ baris[0];
    assign coloumn_even = ~ kolom[0];


    reg x;

    always @(posedge clk ) begin 
        if (!rst) begin
            STATE <= 6'b0;
            baris <= 8'b00000001;
            kolom <= 8'b0;
            addr_input <= 14'b0;
            addr_output <= 14'b0;
            s_kolom <= 8'b0;
            en_s_kolom <= 1'b0;
            x <= 1'b1;

        end else begin
            STATE <= NEXT_STATE;
            if (en_counter) begin
                kolom <= kolom + 1;
                addr_output <= addr_output + 1'b1;
                
            end 

            if (kolom == batas_kolom) begin
                baris <= baris + 1;
                kolom <= kolom + 1;
                kolom <= 8'b0;
                // if (baris > 1) en_write_in <= ~ en_write_in;
            end

            if (kolom == (batas_kolom - 1) && baris > 1 ) en_write_in <= ~ en_write_in;

            x <= ~x;

            if (~x && en_write_in) begin
                addr_input <= addr_input + 1'b1;
            end


            if (en_s_kolom == 1'b1) s_kolom <= s_kolom + 1'b1;
            if (s_kolom == batas_kolom) s_kolom <= 8'b0;

        end
    end

    always @(*) begin

    // addr_input = (addr_output >> 1);

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


        write_mode <= 4'b0000;
        

        addr_output = 14'b0;
        

        NEXT_STATE <= MODE1;
        en_write_in <= 1'b1;
        en_s_kolom <= 1'b1;
        
        



    end

    MODE1 : begin

        // en_write_in <= 1'b0;
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

        // en_write_in <= 1'b0;
        // en_write_out <= 1'b1;

        en_counter <= 1'b1;

        case (kolom) 
            0 : begin
                write_mode <= 4'b0011;
            end

            batas_kolom : begin
                write_mode <= 4'b0101;
                if (baris == batas_kolom) 
                begin
                NEXT_STATE <= MODE3;
                end
            end

            default : begin
                write_mode <= 4'b0100;
            end

        endcase

        

    end


    MODE3 : begin

        // en_write_in <= 1'b0;
        // en_write_out <= 1'b1;

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
            batas_kolom = 8'b00000111; // 4x4
        end
        3'b001: begin
            batas_kolom = 8'b00001111; // 8x8
        end

        3'b010: begin
            batas_kolom = 8'b00011111; // 16x16
        end

        3'b011: begin
            batas_kolom = 8'b00111111; // 32x32
        end
        3'b100: begin
            batas_kolom = 8'b01111111; // 64x64
        end
        default: begin
            batas_kolom = 8'b00000000;
        end

        

    endcase

    
    end

endmodule