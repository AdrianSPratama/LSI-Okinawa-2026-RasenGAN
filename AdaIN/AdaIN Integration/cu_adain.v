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
    reg [3:0] l_cnt; 
    wire last_pixel = (cnt_col == N - 1 && cnt_row == N - 1);
    
    reg [3:0] pipe_in_en, pipe_first_px;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            {cnt_col, cnt_row, l_cnt, done} <= 0;
            {pipe_in_en, pipe_first_px} <= 0;
        end else begin
            pipe_in_en    <= {pipe_in_en[2:0], input_mac_en};
            pipe_first_px <= {pipe_first_px[2:0], (cnt_col == 0 && cnt_row == 0 && input_mac_en)};

            case (state)
                IDLE: begin
                    {cnt_col, cnt_row, l_cnt, done} <= 0;
                    if (start == 2'b01)      state <= CALC_MEAN;
                    else if (start == 2'b10) state <= CALC_VAR;
                    else if (start == 2'b11) state <= CALC_NORM;
                end

                CALC_MEAN, CALC_VAR: begin
                    if (input_mac_en) begin
                        if (last_pixel) l_cnt <= 1;
                        else begin
                            if (cnt_col == N - 1) begin cnt_col <= 0; cnt_row <= cnt_row + 1; end
                            else cnt_col <= cnt_col + 1;
                        end
                    end else if (l_cnt > 0) begin
                        if (l_cnt == 3) begin 
                            if (state == CALC_MEAN) done <= 2'b01;
                            state <= (state == CALC_VAR) ? CALC_ISIG : IDLE;
                            l_cnt <= 0;
                        end else l_cnt <= l_cnt + 1;
                    end
                end

                // --- PERBAIKAN TAHAP NORMALISASI ---
                CALC_NORM: begin
                    // Trigger done 3: Harus muncul tepat 1 clock sebelum data keluar.
                    // Data keluar di T5. Maka done 3 harus tinggi di T4.
                    // Untuk tinggi di T4, assignment dilakukan di T3 (saat pipe_in_en[1] == 1).
                    if (pipe_in_en[1] && !pipe_in_en[2]) begin
                        done <= 2'b11;
                    end

                    if (input_mac_en) begin
                        if (last_pixel) l_cnt <= 1;
                        else begin
                            if (cnt_col == N - 1) begin cnt_col <= 0; cnt_row <= cnt_row + 1; end
                            else cnt_col <= cnt_col + 1;
                        end
                    end else if (l_cnt > 0) begin
                        if (l_cnt == 3) begin 
                            state <= IDLE;
                            l_cnt <= 0;
                        end else l_cnt <= l_cnt + 1;
                    end
                end

                CALC_ISIG: begin
                    if (l_cnt == 4) begin l_cnt <= 0; state <= CALC_B1; end
                    else l_cnt <= l_cnt + 1;
                end

                CALC_B1, CALC_B0: begin
                    if (l_cnt == 3) begin
                        l_cnt <= 0;
                        if (state == CALC_B1) state <= CALC_B0;
                        else begin done <= 2'b10; state <= IDLE; end
                    end else l_cnt <= l_cnt + 1;
                end
            endcase
        end
    end

    // Logika Sinyal Kontrol (Tetap Sama)
    always @(*) begin
        {input_mac_en, rst_acc, mean_en, variance_en, inv_sigma_en, B1_en, B0_en, out_en} = 0;
        case (state)
            CALC_MEAN, CALC_VAR, CALC_NORM: begin
                input_mac_en = (state != IDLE && l_cnt == 0);
                rst_acc = (state == CALC_NORM) ? pipe_in_en[1] : pipe_first_px[1];
                if (state == CALC_MEAN) mean_en     = (l_cnt == 3);
                if (state == CALC_VAR)  variance_en = (l_cnt == 3);
                if (state == CALC_NORM) out_en      = pipe_in_en[2]; 
            end
            CALC_ISIG: begin
                input_mac_en = (l_cnt == 1); rst_acc = (l_cnt == 3); inv_sigma_en = (l_cnt == 4);
            end
            CALC_B1, CALC_B0: begin
                input_mac_en = (l_cnt == 0); rst_acc = (l_cnt == 2);
                if (state == CALC_B1) B1_en = (l_cnt == 3); else B0_en = (l_cnt == 3);
            end
        endcase
    end
endmodule