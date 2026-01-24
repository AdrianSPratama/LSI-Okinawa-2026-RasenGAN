`timescale 1ns / 1ps

module input_line_buffer_CU (
    // Inputs
    input wire clk,
    input wire Reset,
    input wire Stream_first_row, Stream_mid_row, Stream_last_row,
    input wire [7:0] IMAGE_SIZE,
    input wire last_channel,
    input wire [7:0] linebuff_BRAM_counter_out,

    // AXI input signals
    input wire m_axis_tready,
    input wire s_axis_tvalid,
    input wire s_axis_tlast,

    // Control signal outputs
    // Interface for other blocks
    output reg Done_1row,
    output reg Output_valid,
    output reg s_axis_tready,
    output reg Input_line_buffer_IDLE,

    // Internal output control signals
    output reg Rst_window,
    output reg Wr_window,
    output reg Shift_window,

    output reg window_row_n_2_mux,
    output reg window_row_n_1_mux,
    output reg window_row_n_mux,

    output reg ena_linebuff_BRAM,
    output reg wea_linebuff_BRAM,
    output reg enb_linebuff_BRAM,

    output reg en_linebuff_BRAM_counter,
    output reg rst_linebuff_BRAM_counter
);
    
    parameter state_size = 5; // State size in bits, approx 24 total states (use 5 bits)
    // State reg
    reg [state_size-1:0] current_state, next_state;

    // State parameters
    parameter S_Reset                                       = 5'd0,
              S_Idle                                        = 5'd1,
              S_Wait_saxis_tvalid_first_row                 = 5'd2,
              S_Stream_first_row                            = 5'd3,
              S_Zero_padding_edge_first                     = 5'd4,
              S_Wait_saxis_tvalid_mid_row                   = 5'd5,
              S_Stream_mid_row                              = 5'd6,
              S_Finish_mid_row                              = 5'd7,
              S_Zero_padding_edge_first_last_row            = 5'd8,
              S_Streaming_last_row                          = 5'd9,
              S_Idle_last_chan                              = 5'd10,
              S_Wait_saxis_tvalid_first_row_last_chan       = 5'd11,
              S_Stream_first_row_last_chan                  = 5'd12,
              S_Zero_padding_edge_first_last_chan           = 5'd13,
              S_Wait_saxis_tvalid_mid_row_last_chan         = 5'd14,
              S_Stream_mid_row_last_chan                    = 5'd15,
              S_Finish_mid_row_last_chan                    = 5'd16,
              S_Zero_padding_edge_first_last_row_last_chan  = 5'd17,
              S_Wait_saxis_tvalid_last_row_last_chan        = 5'd18,
              S_Streaming_last_row_last_chan                = 5'd19;

    // State transition block
    always @(posedge clk) begin
        if (!Reset) current_state <= S_Reset;
        else current_state <= next_state;
    end

    // State transition block
    always @(*) begin
        next_state <= current_state;

        case (current_state)
            S_Reset: next_state <= S_Idle; 
            
            S_Idle: begin
                if (Stream_first_row) next_state <= S_Wait_saxis_tvalid_first_row;
                else if (Stream_mid_row) next_state <= S_Zero_padding_edge_first;
                else if (Stream_last_row) next_state <= S_Zero_padding_edge_first_last_row;
                else if (last_channel) next_state <= S_Idle_last_chan;
                else next_state <= S_Idle; 
            end

            S_Wait_saxis_tvalid_first_row: begin
                if (s_axis_tvalid) next_state <= S_Stream_first_row;
                else next_state <= S_Wait_saxis_tvalid_first_row;
            end

            S_Stream_first_row: begin
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) next_state <= S_Idle;
                else begin
                    if (s_axis_tvalid) next_state <= S_Stream_first_row;
                    else next_state <= S_Wait_saxis_tvalid_first_row;
                end
            end

            S_Zero_padding_edge_first: next_state <= S_Wait_saxis_tvalid_mid_row;

            S_Wait_saxis_tvalid_mid_row: begin
                if (s_axis_tvalid) next_state <= S_Stream_mid_row;
                else next_state <= S_Wait_saxis_tvalid_mid_row;
            end

            S_Stream_mid_row: begin
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) next_state <= S_Finish_mid_row;
                else begin
                    if (s_axis_tvalid) next_state <= S_Stream_mid_row;
                    else next_state <= S_Wait_saxis_tvalid_mid_row;
                end
            end

            S_Finish_mid_row: next_state <= S_Idle;

            S_Zero_padding_edge_first_last_row: next_state <= S_Streaming_last_row;

            S_Streaming_last_row: begin
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) next_state <= S_Finish_mid_row;
                else next_state <= S_Streaming_last_row;
            end

            S_Idle_last_chan: begin
                if (Stream_first_row) next_state <= S_Wait_saxis_tvalid_first_row_last_chan;
                else if (Stream_mid_row) next_state <= S_Zero_padding_edge_first_last_chan;
                else if (Stream_last_row) next_state <= S_Zero_padding_edge_first_last_row_last_chan;
                else next_state <= S_Idle_last_chan;
            end

            S_Wait_saxis_tvalid_first_row_last_chan: begin
                if (s_axis_tvalid && m_axis_tready) next_state <= S_Stream_first_row_last_chan;
                else next_state <= S_Wait_saxis_tvalid_first_row_last_chan;
            end

            S_Stream_first_row_last_chan: begin
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) next_state <= S_Idle_last_chan;
                else begin
                    if (s_axis_tvalid && m_axis_tready) next_state <= S_Stream_first_row_last_chan;
                    else next_state <= S_Wait_saxis_tvalid_first_row_last_chan;
                end
            end

            S_Zero_padding_edge_first_last_chan: next_state <= S_Wait_saxis_tvalid_mid_row_last_chan;

            S_Wait_saxis_tvalid_mid_row_last_chan: begin
                if (s_axis_tvalid && m_axis_tready) next_state <= S_Stream_mid_row_last_chan;
                else next_state <= S_Wait_saxis_tvalid_mid_row_last_chan;
            end

            S_Stream_mid_row_last_chan: begin
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) next_state <= S_Finish_mid_row_last_chan;
                else begin
                    if (s_axis_tvalid && m_axis_tready) next_state <= S_Stream_mid_row_last_chan;
                    else next_state <= S_Wait_saxis_tvalid_mid_row_last_chan;
                end
            end

            S_Finish_mid_row_last_chan: next_state <= S_Idle_last_chan;

            S_Zero_padding_edge_first_last_row_last_chan: next_state <= S_Wait_saxis_tvalid_last_row_last_chan;

            S_Wait_saxis_tvalid_last_row_last_chan: begin
                if (m_axis_tready) next_state <= S_Streaming_last_row_last_chan;
                else next_state <= S_Wait_saxis_tvalid_last_row_last_chan;
            end

            S_Streaming_last_row_last_chan: begin
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) next_state <= S_Finish_mid_row_last_chan;
                else begin
                    if (m_axis_tready) next_state <= S_Streaming_last_row_last_chan;
                    else next_state <= S_Wait_saxis_tvalid_last_row_last_chan;
                end
            end

            default: next_state <= S_Reset;
        endcase
    end

    // State output
    always @(*) begin
        // Defaults, so we don't need to write all of the combination in if else branch (if it's not found then go back to default)
        Done_1row = 0;
        Output_valid = 0;
        Rst_window = 1;
        Wr_window = 0;
        Shift_window = 0;
        window_row_n_2_mux = 0;
        window_row_n_1_mux = 0;
        window_row_n_mux = 0;
        ena_linebuff_BRAM = 1;
        wea_linebuff_BRAM = 0;
        enb_linebuff_BRAM = 1;
        en_linebuff_BRAM_counter = 0;
        rst_linebuff_BRAM_counter = 1;
        s_axis_tready = 0;
        Input_line_buffer_IDLE = 0;

        case (current_state)
            S_Reset: begin
                Done_1row = 0;
                Output_valid = 0;
                Rst_window = 0;
                Wr_window = 0;
                Shift_window = 0;
                window_row_n_2_mux = 0;
                window_row_n_1_mux = 0;
                window_row_n_mux = 0;
                ena_linebuff_BRAM = 0;
                wea_linebuff_BRAM = 0;
                enb_linebuff_BRAM = 0;
                en_linebuff_BRAM_counter = 0;
                rst_linebuff_BRAM_counter = 0;
                s_axis_tready = 0;
            end

            S_Idle: begin
                Rst_window = 1;
                ena_linebuff_BRAM = 1;
                enb_linebuff_BRAM = 1;
                rst_linebuff_BRAM_counter = 1;
                Input_line_buffer_IDLE = 1;
            end

            S_Wait_saxis_tvalid_first_row: begin
                window_row_n_mux = 1;
                s_axis_tready = 1;
                if (s_axis_tvalid) begin
                    Wr_window = 1;
                    Shift_window = 1;
                    wea_linebuff_BRAM = 1;
                    en_linebuff_BRAM_counter = 1;
                end
            end

            S_Stream_first_row: begin
                window_row_n_mux = 1;
                Wr_window = 1;
                Shift_window = 1;
                wea_linebuff_BRAM = 1;
                en_linebuff_BRAM_counter = 1;
                s_axis_tready = 1;
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) begin
                    // Pengganti S_Finish_first_row
                    Wr_window = 0;
                    Shift_window = 0;
                    wea_linebuff_BRAM = 0;
                    en_linebuff_BRAM_counter = 0;
                    rst_linebuff_BRAM_counter = 0;
                    Done_1row = 1;
                    s_axis_tready = 0;
                end
                else begin
                    if (!s_axis_tvalid) begin
                        Wr_window = 0;
                        Shift_window = 0;
                        wea_linebuff_BRAM = 0;
                        en_linebuff_BRAM_counter = 0;
                    end 
                end
            end

            S_Zero_padding_edge_first: begin
                Wr_window = 1;
                Shift_window = 1;
            end

            S_Wait_saxis_tvalid_mid_row: begin
                window_row_n_2_mux = 1;
                window_row_n_1_mux = 1;
                window_row_n_mux = 1;
                s_axis_tready = 1;
                Output_valid = 0;
                if (s_axis_tvalid) begin
                    Wr_window = 1;
                    Shift_window = 1;
                    wea_linebuff_BRAM = 1;
                    en_linebuff_BRAM_counter = 1;
                end
            end

            S_Stream_mid_row: begin
                window_row_n_2_mux = 1;
                window_row_n_1_mux = 1;
                window_row_n_mux = 1;
                s_axis_tready = 1;
                Wr_window = 1;
                Shift_window = 1;
                wea_linebuff_BRAM = 1;
                en_linebuff_BRAM_counter = 1;
                Output_valid = linebuff_BRAM_counter_out >= 2;
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) begin
                    // For zero padding
                    Wr_window = 1;
                    Shift_window = 1;
                    Output_valid = 1;
                    wea_linebuff_BRAM = 0;
                    rst_linebuff_BRAM_counter = 0;
                    en_linebuff_BRAM_counter = 0;
                    window_row_n_2_mux = 0;
                    window_row_n_1_mux = 0;
                    window_row_n_mux = 0;
                    s_axis_tready = 0;
                end
                else begin
                    if (!s_axis_tvalid) begin
                        Wr_window = 0;
                        Shift_window = 0;
                        wea_linebuff_BRAM = 0;
                        en_linebuff_BRAM_counter = 0;
                    end 
                end
            end

            S_Finish_mid_row: begin
               Done_1row = 1;
               Output_valid = 1; 
            end

            S_Zero_padding_edge_first_last_row: begin
                Wr_window = 1;
                Shift_window = 1;
            end

            S_Streaming_last_row: begin
                Wr_window = 1;
                Shift_window = 1;
                window_row_n_2_mux = 1;
                window_row_n_1_mux = 1;
                en_linebuff_BRAM_counter = 1;
                Output_valid = linebuff_BRAM_counter_out >= 2;
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) begin
                    Wr_window = 1;
                    Shift_window = 1;
                    Output_valid = 1;
                    wea_linebuff_BRAM = 0;
                    rst_linebuff_BRAM_counter = 0;
                    en_linebuff_BRAM_counter = 0;
                    window_row_n_2_mux = 0;
                    window_row_n_1_mux = 0;
                    window_row_n_mux = 0;
                    s_axis_tready = 0;
                end
            end

            S_Idle_last_chan: begin
                Rst_window = 1;
                ena_linebuff_BRAM = 1;
                enb_linebuff_BRAM = 1;
                rst_linebuff_BRAM_counter = 1;
                Input_line_buffer_IDLE = 1;
            end

            S_Wait_saxis_tvalid_first_row_last_chan: begin
                window_row_n_mux = 1;
                s_axis_tready = 1;
                if (s_axis_tvalid && m_axis_tready) begin
                    Wr_window = 1;
                    Shift_window = 1;
                    wea_linebuff_BRAM = 1;
                    en_linebuff_BRAM_counter = 1;
                end
            end

            S_Stream_first_row_last_chan: begin
                window_row_n_mux = 1;
                Wr_window = 1;
                Shift_window = 1;
                wea_linebuff_BRAM = 1;
                en_linebuff_BRAM_counter = 1;
                s_axis_tready = 1;
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) begin
                    Wr_window = 0;
                    Shift_window = 0;
                    wea_linebuff_BRAM = 0;
                    en_linebuff_BRAM_counter = 0;
                    rst_linebuff_BRAM_counter = 0;
                    Done_1row = 1;
                    s_axis_tready = 0;
                end
                else begin
                    if (!(s_axis_tvalid && m_axis_tready)) begin
                        Wr_window = 0;
                        Shift_window = 0;
                        wea_linebuff_BRAM = 0;
                        en_linebuff_BRAM_counter = 0;
                    end
                end
            end

            S_Zero_padding_edge_first_last_chan: begin
                Wr_window = 1;
                Shift_window = 1;
            end

            S_Wait_saxis_tvalid_mid_row_last_chan: begin
                window_row_n_2_mux = 1;
                window_row_n_1_mux = 1;
                window_row_n_mux = 1;
                s_axis_tready = 1;
                Output_valid = 0;
                if (s_axis_tvalid && m_axis_tready) begin
                    Wr_window = 1;
                    Shift_window = 1;
                    wea_linebuff_BRAM = 1;
                    en_linebuff_BRAM_counter = 1;
                end
            end

            S_Stream_mid_row_last_chan: begin
                window_row_n_2_mux = 1;
                window_row_n_1_mux = 1;
                window_row_n_mux = 1;
                s_axis_tready = 1;
                Wr_window = 1;
                Shift_window = 1;
                wea_linebuff_BRAM = 1;
                en_linebuff_BRAM_counter = 1;
                Output_valid = linebuff_BRAM_counter_out >= 2;
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) begin
                    // For zero padding
                    Wr_window = 1;
                    Shift_window = 1;
                    Output_valid = 1;
                    wea_linebuff_BRAM = 0;
                    rst_linebuff_BRAM_counter = 0;
                    en_linebuff_BRAM_counter = 0;
                    window_row_n_2_mux = 0;
                    window_row_n_1_mux = 0;
                    window_row_n_mux = 0;
                    s_axis_tready = 0;
                end
                else begin
                    if (!(s_axis_tvalid && m_axis_tready)) begin
                        Wr_window = 0;
                        Shift_window = 0;
                        wea_linebuff_BRAM = 0;
                        en_linebuff_BRAM_counter = 0;
                    end
                end
            end

            S_Finish_mid_row_last_chan: begin
               Done_1row = 1;
               Output_valid = 1; 
            end

            S_Zero_padding_edge_first_last_row_last_chan: begin
                Wr_window = 1;
                Shift_window = 1;
            end

            S_Wait_saxis_tvalid_last_row_last_chan: begin
                window_row_n_2_mux = 1;
                window_row_n_1_mux = 1;
                Output_valid = 0;
                if (m_axis_tready) begin
                    Wr_window = 1;
                    Shift_window = 1;
                    window_row_n_2_mux = 1;
                    window_row_n_1_mux = 1;
                    en_linebuff_BRAM_counter = 1;
                    Output_valid = linebuff_BRAM_counter_out >= 2;
                end
            end

            S_Streaming_last_row_last_chan: begin
                Wr_window = 1;
                Shift_window = 1;
                window_row_n_2_mux = 1;
                window_row_n_1_mux = 1;
                en_linebuff_BRAM_counter = 1;
                Output_valid = linebuff_BRAM_counter_out >= 2;
                if (linebuff_BRAM_counter_out > IMAGE_SIZE - 1) begin
                    // For zero padding
                    Wr_window = 1;
                    Shift_window = 1;
                    Output_valid = 1;
                    wea_linebuff_BRAM = 0;
                    rst_linebuff_BRAM_counter = 0;
                    en_linebuff_BRAM_counter = 0;
                    window_row_n_2_mux = 0;
                    window_row_n_1_mux = 0;
                    window_row_n_mux = 0;
                    s_axis_tready = 0;
                end
                else begin
                    if (!m_axis_tready) begin
                        Wr_window = 0;
                        Shift_window = 0;
                        wea_linebuff_BRAM = 0;
                        en_linebuff_BRAM_counter = 0;
                    end 
                end
            end

            default: begin
                Done_1row = 0;
                Output_valid = 0;
                Rst_window = 1;
                Wr_window = 0;
                Shift_window = 0;
                window_row_n_2_mux = 0;
                window_row_n_1_mux = 0;
                window_row_n_mux = 0;
                ena_linebuff_BRAM = 1;
                wea_linebuff_BRAM = 0;
                enb_linebuff_BRAM = 1;
                en_linebuff_BRAM_counter = 0;
                rst_linebuff_BRAM_counter = 1;
                s_axis_tready = 0;
            end 
        endcase
    end

endmodule