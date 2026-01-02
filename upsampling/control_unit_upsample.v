module control_unit_upsample(
    input wire clk,
    input wire rst,
    input wire start,
    output reg done,
    output reg [3:0] write_mode,
    output reg en_write_in,
    output reg en_write_out,
    output reg [5:0] addr_input,
    output reg [5:0] addr_output
);

    reg [5:0] STATE;
    reg [5:0] NEXT_STATE;

    reg [5:0] counter;
    reg en_counter;
    reg [5:0] start_offset;

    reg [5:0] offset_addr;

    localparam IDLE      = 6'b000000;
    localparam LOAD      = 6'b000001;
    localparam MODE1     = 6'b000010;
    localparam MODE2     = 6'b000011;
    localparam MODE3     = 6'b000100;
    localparam DONE      = 6'b000101;

    always @(posedge clk ) begin
        if (!rst) begin
            STATE <= 6'b0;
            counter <= 6'b0;
            offset_addr <= 6'b001000;
            start_offset <= 6'b0;

            // addr_input <= 6'b0;
            // addr_output <= 6'b0;
            // done <= 1'b0;
            // en_write_in <= 1'b0;
            // en_write_out <= 1'b0;
            // write_mode <= 2'b00;
            // en_counter <= 1'b0;

        end else begin
            STATE <= NEXT_STATE;
            if (en_counter) begin
                counter <= counter + 1;
            end 

            if (counter[1:0] == 2'b10) begin
            offset_addr <= offset_addr + 5'b01000;
            counter <= counter + 2'b10;
            
            end

        end
    end

    always @(*) begin
    case (STATE) 

    IDLE : begin
        done <= 1'b0;
        en_write_in <= 1'b0;
        en_write_out <= 1'b0;
        addr_input <= 6'b0;
        addr_output <= 6'b0;
        write_mode <= 2'b00;
        en_counter <= 1'b0;

        start_offset <= 6'b1000;

        if (start) begin
            NEXT_STATE <= LOAD;
        end else begin
            NEXT_STATE <= IDLE;
        end
    end

    LOAD : begin

        en_write_in <= 1'b1;

        write_mode <= 4'b0000;

        addr_input <= counter;
        addr_output <= counter;

        NEXT_STATE <= MODE1;

    end

    MODE1 : begin

        en_write_in <= 1'b0;
        en_write_out <= 1'b1;

        en_counter <= 1'b1;

        addr_input <= counter;
        addr_output <= counter * 2 + 1;

        case (counter[1:0]) 
            2'b00 : begin
                write_mode <= 4'b0000;
            end

            2'b10 : begin
                write_mode <= 4'b0010;
            end

            default : begin
                write_mode <= 4'b0001;
            end

        endcase

        if (counter[1:0] == 2'b10) begin
            NEXT_STATE <= MODE2;
        end

    end


    MODE2 : begin

        en_write_in <= 1'b0;
        en_write_out <= 1'b1;

        en_counter <= 1'b1;

        addr_input <= counter;
        addr_output <= counter * 2 + offset_addr + 1;

        case (counter[1:0]) 
            2'b00 : begin
                write_mode <= 4'b0011;
            end

            2'b10 : begin
                write_mode <= 4'b0101;
            end

            default : begin
                write_mode <= 4'b0100;
            end

        endcase

        if (counter[1:0] == 2'b10) begin
            NEXT_STATE <= MODE3;
        end

    end


    MODE3 : begin

        en_write_in <= 1'b0;
        en_write_out <= 1'b1;

        en_counter <= 1'b1;

        addr_input <= counter;
        addr_output <= counter * 2 + offset_addr + 1;

        case (counter[1:0]) 
            2'b00 : begin
                write_mode <= 4'b0110;
            end

            2'b10 : begin
                write_mode <= 4'b1000;
            end

            default : begin
                write_mode <= 4'b0111;
            end

        endcase

        if (counter[1:0] == 2'b10) begin
            NEXT_STATE <= DONE;
        end

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
    end


endmodule