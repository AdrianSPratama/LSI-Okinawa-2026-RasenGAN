`timescale 1ns/1ps

module cu_adain #(
    parameter N_MAX = 256
)(
    input  wire clk,
    input  wire rst,
    input  wire [1:0] start,
    input  wire [$clog2(N_MAX+1)-1:0] N,

    output reg [2:0]  state,
    output reg        input_mac_en,
    output reg        mean_en,
    output reg        variance_en,
    output reg        inv_sigma_en,
    output reg        B1_en,
    output reg        B0_en,
    output reg        out_en,
    output reg        rst_acc,
    output reg [1:0]  done
);

    localparam IDLE      = 3'b000;
    localparam CALC_MEAN = 3'b001;
    localparam CALC_VAR  = 3'b010;
    localparam CALC_ISIG = 3'b011;
    localparam CALC_B1   = 3'b100;
    localparam CALC_B0   = 3'b101;
    localparam CALC_NORM = 3'b110;

    reg [$clog2(N_MAX)-1:0] cnt_col, cnt_row;
    reg [2:0] l_cnt; // Counter latensi (flush pipeline)
    
    wire last_pixel = (cnt_col == N - 1 && cnt_row == N - 1);
    
    // Pipeline shift registers untuk delay sinyal kontrol (MAC latency 3 cycles)
    reg [3:0] pipe_in_en;
    reg [3:0] pipe_rst;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            {cnt_col, cnt_row, l_cnt} <= 0;
            done <= 2'b00;
            {pipe_in_en, pipe_rst} <= 0;
        end else begin
            pipe_in_en <= {pipe_in_en[2:0], input_mac_en};
            pipe_rst   <= {pipe_rst[2:0], rst_acc};

            case (state)
                IDLE: begin
                    {cnt_col, cnt_row, l_cnt} <= 0;
                    case (start)
                        2'b01   : begin
                            state <= CALC_MEAN;
                        end
                        2'b10   : begin
                            state <= CALC_VAR;
                        end
                        2'b11   : begin
                            state <= CALC_NORM;
                        end
                        default : begin
                            state <= IDLE
                        end
                    endcase
                end

                CALC_MEAN: begin
                    if (last_pixel) begin
                        if (l_cnt == 3) begin 
                            l_cnt <= 0; 
                            done <= 2'b01; 
                            state <= IDLE;
                        end else begin
                            l_cnt <= l_cnt + 1;
                        end
                    end else begin
                        if (cnt_col == N - 1) begin 
                            cnt_col <= 0; 
                            cnt_row <= cnt_row + 1; 
                        end else begin 
                            cnt_col <= cnt_col + 1;
                        end
                    end
                end

                CALC_VAR: begin
                    if (last_pixel) begin
                        if (l_cnt == 3) begin 
                            l_cnt <= 0; 
                            state <= CALC_ISIG; 
                        end else begin
                            l_cnt <= l_cnt + 1;
                        end
                    end else begin
                        if (cnt_col == N - 1) begin 
                            cnt_col <= 0; 
                            cnt_row <= cnt_row + 1; 
                        end else begin
                            cnt_col <= cnt_col + 1;
                        end
                    end
                end

                CALC_ISIG: begin
                    if (l_cnt == 5) begin 
                        l_cnt <= 0; 
                        state <= CALC_B1; 
                    end else begin 
                        l_cnt <= l_cnt + 1;
                end

                CALC_B1: begin
                    if (l_cnt == 3) begin 
                        l_cnt <= 0; 
                        state <= CALC_B0; 
                    end else begin
                        l_cnt <= l_cnt + 1;
                    end
                end

                CALC_B0: begin
                    if (l_cnt == 3) begin
                        l_cnt   <= 0; 
                        done    <= 2'b10; 
                        state   <= IDLE;
                    end else begin 
                        l_cnt   <= l_cnt + 1;
                    end
                end

                CALC_NORM: begin
                    if (last_pixel) begin
                        if (l_cnt == 3) begin
                            l_cnt <= 0; 
                            done <= 2'b11; 
                            state <= IDLE;
                        end else l_cnt <= l_cnt + 1;
                    end else begin
                        if (cnt_col == N - 1) begin 
                            cnt_col <= 0; 
                            cnt_row <= cnt_row + 1; 
                        end else cnt_col <= cnt_col + 1;
                    end
                end
            endcase
        end
    end

    // Logika Sinyal Aktif
    always @(*) begin
        {input_mac_en, rst_acc, mean_en, variance_en, inv_sigma_en, B1_en, B0_en, out_en} = 0;
        case (state)
            CALC_MEAN, CALC_VAR, CALC_NORM: begin
                input_mac_en = !last_pixel || (l_cnt == 0);
                rst_acc = (state == CALC_NORM) ? pipe_in_en[0] : (cnt_col == 0 && cnt_row == 0 && l_cnt == 0);
                
                if (state == CALC_MEAN) mean_en     = (last_pixel && l_cnt == 3);
                if (state == CALC_VAR)  variance_en = (last_pixel && l_cnt == 3);
                if (state == CALC_NORM) out_en      = pipe_in_en[2]; // Delay 3 siklus
            end
            CALC_ISIG: begin
                input_mac_en = (l_cnt == 1); rst_acc = (l_cnt == 2); inv_sigma_en = (l_cnt == 5);
            end
            CALC_B1, CALC_B0: begin
                input_mac_en = (l_cnt == 0); rst_acc = (l_cnt == 1);
                if (state == CALC_B1) B1_en = (l_cnt == 3); else B0_en = (l_cnt == 3);
            end
        endcase
    end
endmodule