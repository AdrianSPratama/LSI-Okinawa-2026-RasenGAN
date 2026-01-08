module convolution_top_CU (
    // Input signals
    input wire aresetn,
    input wire clk,
    input wire Load_kernel_BRAM,
    input wire [7:0] Image_size, // (4, 8, 16, 32, 64, or 128)
    input wire [8:0] Channel_size, // (256, 128, or 64)
    input wire [7:0] kernel_BRAM_counter_out,
    input wire [6:0] window_BRAM_counter_out,
    input wire [13:0] a_output_BRAM_counter_out,
    input wire [13:0] b_output_BRAM_counter_out,
    input wire [7:0] in_row_counter,
    input wire [7:0] in_col_counter,
    input wire s_axis_tvalid,
    input wire s_axis_tlast,
    input wire m_axis_tready,

    // Output control signals
    // Kernel controls
    output wire Wr_kernel,
    output wire Rst_kernel,

    // Convolution window controls
    output wire Rst_window,
    output wire Wr_window,
    output wire Shift_window,
    output wire window_row_n_2_mux,
    output wire window_row_n_1_mux,
    output wire window_row_n_mux,

    // Kernel BRAM controls
    output wire enb_kernel_BRAM,
    output wire enb_kernel_BRAM_addr_counter,
    output wire rstb_kernel_BRAM_addr_counter,

    // Window BRAM controls
    output wire enb_window_BRAM,
    output wire wea_window_BRAM,
    output wire enb_window_BRAM_addr_counter,
    output wire rstb_window_BRAM_addr_counter,

    // Bias controls
    output wire add_bias,
    output wire ena_bias_BRAM_addr_counter,
    output wire rsta_bias_BRAM_addr_counter,

    // Output BRAM controls port a
    output wire ena_output_BRAM,
    output wire wea_output_BRAM,
    output wire ena_output_BRAM_addr_counter,
    output wire rsta_output_BRAM_addr_counter,

    // Output BRAM controls port b
    output wire enb_output_BRAM,
    output wire enb_output_BRAM_addr_counter,
    output wire rstb_output_BRAM_addr_counter,

    // Col and row counters
    output wire en_in_row_counter,
    output wire en_in_col_counter,
    output wire rst_in_row_counter,
    output wire rst_in_col_counter,

    // AXI-Stream Output controls
    output wire s_axis_tready,
    output wire m_axis_tvalid,
    output wire m_axis_tlast
);

parameter state_size = 5;
parameter S_Reset = 5'b00000,
          S_Idle = 5'b00001,
          S_Loading_kernel_bram = 5'b00010,
          S_Write_kernel_reg = 5'b00011,
          S_Waiting_saxis_valid_maxis_ready_first_row = 5'b00100,
          S_Start_shifting_first_row = 5'b00101,
          S_Inc_row_res_coln = 5'b00110,
          S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya = 5'b00111,
          S_Start_shifting_baris2selanjutnya = 5'b01000,
          S_Add_last_zero_padding = 5'b01001,
          S_Start_shifting_last_row = 5'b01010,
          S_Add_last_zero_padding_last_row = 5'b01011,
          S_Increment_kernel_BRAM_addr_b = 5'b01100,
          S_Write_kernel_reg_last_chan = 5'b01101,
          S_Waiting_saxis_valid_maxis_ready_first_row_last_chan = 5'b01110,
          S_Start_shifting_first_row_last_chan = 5'b01111,
          S_Inc_row_res_col_last_chan = 5'b10000,
          S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya_last_chan = 5'b10001,
          S_Start_streaming_baris2_selanjutnya_last_chan = 5'b10010,
          S_Add_last_zero_padding_last_chan = 5'b10011,
          S_Start_shifting_last_row_last_chan = 5'b10100,
          S_M_axis_tlast_high = 5'b10101;

// State register
reg [state_size-1:0] current_state;

// State transition block
always @(posedge clk) begin
    if (!aresetn) begin
        current_state <= S_Reset;
    end
    else begin
        case (current_state)
            S_Reset: begin
                current_state <= S_Idle;
            end

            S_Idle: begin
                if (Load_kernel_BRAM) begin
                    current_state <= S_Loading_kernel_bram;
                end
                else begin
                    current_state <= S_Idle;
                end
            end

            S_Loading_kernel_bram: begin
                if (!Load_kernel_BRAM) begin
                    current_state <= S_Write_kernel_reg;
                end
                else begin
                    current_state <= S_Loading_kernel_bram;
                end
            end

            S_Write_kernel_reg: current_state <= S_Waiting_saxis_valid_maxis_ready_first_row;

            S_Waiting_saxis_valid_maxis_ready_first_row: begin
                if (s_axis_tvalid && m_axis_tready) begin
                    current_state <= S_Start_shifting_first_row;
                end
                else begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_first_row;
                end
            end

            S_Start_shifting_first_row: begin
                if (!s_axis_tvalid || !m_axis_tready) begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_first_row;
                end
                else begin
                    if (in_col_counter == Image_size) begin
                        current_state <= S_Inc_row_res_coln;
                    end
                    else begin
                        current_state <= S_Start_shifting_first_row;
                    end
                end
            end

            S_Inc_row_res_coln: current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya;

            S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya: begin
                if (s_axis_tvalid && m_axis_tready) begin
                    current_state <= S_Start_shifting_baris2selanjutnya;
                end
                else begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya;
                end
            end

            S_Start_shifting_baris2selanjutnya: begin
                if (!s_axis_tvalid || !m_axis_tready) begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya;
                end
                else begin
                    if(in_col_counter == Image_size) begin
                        current_state <= S_Add_last_zero_padding;
                    end
                    else begin
                        current_state <= S_Start_shifting_baris2selanjutnya;
                    end
                end
            end

            S_Add_last_zero_padding: begin
                if (in_row_counter == Image_size) begin
                    current_state <= S_Start_shifting_last_row;
                end
                else begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya;
                end
            end

            S_Start_shifting_last_row: begin
                if (in_col_counter == Image_size) begin
                    current_state <= S_Add_last_zero_padding_last_row;
                end
                else begin
                    current_state <= S_Start_shifting_last_row;
                end
            end

            S_Add_last_zero_padding_last_row: current_state <= S_Increment_kernel_BRAM_addr_b;

            S_Increment_kernel_BRAM_addr_b: begin
                if(kernel_BRAM_counter_out == Channel_size-2) begin
                    current_state <= S_Write_kernel_reg_last_chan;
                end
                else begin
                    current_state <= S_Write_kernel_reg;
                end
            end
            
            S_Write_kernel_reg_last_chan: current_state <= S_Waiting_saxis_valid_maxis_ready_first_row_last_chan;

            S_Waiting_saxis_valid_maxis_ready_first_row_last_chan: begin
                if(s_axis_tvalid && m_axis_tready) begin
                    current_state <= S_Start_shifting_first_row_last_chan;
                end
                else begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_first_row_last_chan;
                end
            end

            S_Start_shifting_first_row_last_chan: begin
                if(!s_axis_tvalid || !m_axis_tready) begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_first_row_last_chan;
                end
                else begin
                    if (in_col_counter == Image_size) begin
                        current_state <= S_Inc_row_res_col_last_chan;
                    end
                    else begin
                        current_state <= S_Start_shifting_first_row_last_chan;
                    end
                end
            end

            S_Inc_row_res_col_last_chan: current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya_last_chan;

            S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya_last_chan: begin
                if (s_axis_tvalid && m_axis_tready) begin
                    current_state <= S_Start_streaming_baris2_selanjutnya_last_chan;
                end
                else begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya_last_chan;
                end
            end

            S_Start_streaming_baris2_selanjutnya_last_chan: begin
                if (!s_axis_tvalid || !m_axis_tready) begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya_last_chan;
                end
                else begin
                    if (in_col_counter == Image_size) begin
                        current_state <= S_Add_last_zero_padding_last_chan;
                    end
                    else begin
                        current_state <= S_Start_streaming_baris2_selanjutnya_last_chan;
                    end
                end
            end

            S_Add_last_zero_padding_last_chan: begin
                if (in_row_counter == Image_size) begin
                    current_state <= S_Start_shifting_last_row_last_chan;
                end
                else begin
                    current_state <= S_Waiting_saxis_valid_maxis_ready_baris2selanjutnya_last_chan;
                end
            end

            S_Start_shifting_last_row_last_chan: begin
                if (in_col_counter == Image_size+1) begin
                    current_state <= S_M_axis_tlast_high;
                end
                else begin
                    current_state <= S_Start_shifting_last_row_last_chan;
                end
            end

            S_M_axis_tlast_high: current_state <= S_Idle;

            default: current_state <= S_Reset;
        endcase
    end
end



endmodule