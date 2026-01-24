// TODO: Check if IMAGE_SIZE and CHANNEL_SIZE have to be 0 too in S_Reset
`timescale 1ns / 1ps

module top_level_conv_CU (
    input wire clk,
    // Control inputs
    input wire Reset_top,
    input wire Load_kernel_BRAM,
    input wire reg_last_chan,
    
    // CHANNEL_SIZE_choose: 2'd0 = 256, 2'd1 = 128, 2'd2 = 64 (from GPIO)
    input wire [1:0] CHANNEL_SIZE_choose,
    // IMAGE_SIZE_choose: 3'd0 = 4, 3'd1 = 8, 3'd2 = 16, 3'd3 = 32, 3'd4 = 64, 3'd5 = 128 (from GPIO)
    input wire [2:0] IMAGE_SIZE_choose,
    
    input wire last_loading_1ker,
    input wire last_channel,
    input wire Kernel_BRAM_IDLE,

    input wire Done_1row,
    input wire Input_line_buffer_IDLE,

    input wire PE_ready,
    input wire PE_with_buffers_IDLE,

    input wire [6:0] top_row_counter_out,

    input wire aresetn,

    // Control outputs
    output reg slave_select,
    output reg conv_DONE,
    output reg en_reg_last_chan,
    output reg rst_reg_last_chan,

    output reg Kernel_BRAM_Reset,
    output reg load_BRAM_dina,
    output reg update_BRAM_doutb,

    output reg Input_line_buffer_Reset,
    output reg Stream_first_row,
    output reg Stream_mid_row,
    output reg Stream_last_row,

    output reg PE_with_buffers_Reset,
    output reg Load_kernel_reg,

    output reg en_top_row_counter,
    output reg rst_top_row_counter,

    output reg [8:0] CHANNEL_SIZE,
    output reg [7:0] IMAGE_SIZE
);

    parameter state_size = 5;
    parameter S_Reset                           = 5'd0,
              S_Idle                            = 5'd1,
              S_Loading_kernel_BRAM             = 5'd2,
              S_Loading_kernel_reg              = 5'd3,
              S_Wait_idle                       = 5'd4,
              S_Stream_first_row                = 5'd5,
              S_Wait_stream_first_row_finish    = 5'd6,
              S_Wait_idle_mid_row               = 5'd7,
              S_Stream_mid_row                  = 5'd8,
              S_Wait_stream_mid_row_finish      = 5'd9,
              S_Wait_idle_last_row              = 5'd10,
              S_Stream_last_row                 = 5'd11,
              S_Wait_stream_last_row_finish     = 5'd12,
              S_Wait_idle_update_kernel_BRAM    = 5'd13,
              S_Update_BRAM_doutb               = 5'd14,
              S_Wait_update_BRAM_doutb          = 5'd15,
              S_En_reg_last_chan                = 5'd16,
              S_Done_conv                       = 5'd17;

    reg [state_size-1:0] current_state, next_state;

    // State transition block
    always @(posedge clk) begin
        if (!Reset_top || !aresetn) current_state <= S_Reset;
        else current_state <= next_state;
    end

    // State conditional block
    always @(*) begin
        next_state <= current_state;

        case (current_state)
            S_Reset: next_state <= S_Idle;
            
            S_Idle: begin
                if (Load_kernel_BRAM && Kernel_BRAM_IDLE) next_state <= S_Loading_kernel_BRAM;
                else next_state <= S_Idle;
            end

            S_Loading_kernel_BRAM: begin
                if (last_loading_1ker) next_state <= S_Loading_kernel_reg;
                else next_state <= S_Loading_kernel_BRAM;
            end

            S_Loading_kernel_reg: begin
                if (PE_ready) next_state <= S_Wait_idle;
                else next_state <= S_Loading_kernel_reg;
            end

            S_Wait_idle: begin
                if (Input_line_buffer_IDLE && PE_with_buffers_IDLE) next_state <= S_Stream_first_row;
                else next_state <= S_Wait_idle;
            end

            S_Stream_first_row: next_state <= S_Wait_stream_first_row_finish;

            S_Wait_stream_first_row_finish: begin
                if (Done_1row) next_state <= S_Wait_idle_mid_row;
                else next_state <= S_Wait_stream_first_row_finish;
            end

            S_Wait_idle_mid_row: begin
                if (Input_line_buffer_IDLE && PE_with_buffers_IDLE) next_state <= S_Stream_mid_row;
                else next_state <= S_Wait_idle_mid_row;
            end

            S_Stream_mid_row: next_state <= S_Wait_stream_mid_row_finish;

            S_Wait_stream_mid_row_finish: begin
                if (Done_1row) begin
                    if (top_row_counter_out == IMAGE_SIZE-2) next_state <= S_Wait_idle_last_row;
                    else next_state <= S_Wait_idle_mid_row;
                end
                else next_state <= S_Wait_stream_mid_row_finish;
            end

            S_Wait_idle_last_row: begin
                if (Input_line_buffer_IDLE && PE_with_buffers_IDLE) next_state <= S_Stream_last_row;
                else next_state <= S_Wait_idle_last_row;
            end

            S_Stream_last_row: next_state <= S_Wait_stream_last_row_finish;

            S_Wait_stream_last_row_finish: begin
                if (Done_1row) next_state <= S_Wait_idle_update_kernel_BRAM;
                else next_state <= S_Wait_stream_last_row_finish;
            end

            S_Wait_idle_update_kernel_BRAM: begin
                if (Input_line_buffer_IDLE && PE_with_buffers_IDLE) next_state <= S_Update_BRAM_doutb;
                else next_state <= S_Wait_idle_update_kernel_BRAM;
            end

            S_Update_BRAM_doutb: next_state <= S_Wait_update_BRAM_doutb;

            S_Wait_update_BRAM_doutb: begin
                if (reg_last_chan) next_state <= S_Done_conv;
                else if (last_channel) next_state <= S_En_reg_last_chan;
                else if (top_row_counter_out == 3) next_state <= S_Loading_kernel_reg;
                else next_state <= S_Wait_update_BRAM_doutb;
            end

            S_En_reg_last_chan: next_state <= S_Loading_kernel_reg;

            S_Done_conv: next_state <= S_Reset;

            default: next_state <= S_Idle;
        endcase
    end

    // State output
    always @(*) begin
        slave_select = 1;
        conv_DONE = 0;
        en_reg_last_chan = 0;
        rst_reg_last_chan = 1;
        
        Kernel_BRAM_Reset = 1;
        load_BRAM_dina = 0;
        update_BRAM_doutb = 0;
        
        Input_line_buffer_Reset = 1;
        Stream_first_row = 0;
        Stream_mid_row = 0;
        Stream_last_row = 0;

        PE_with_buffers_Reset = 1;
        Load_kernel_reg = 0;

        en_top_row_counter = 0;
        rst_top_row_counter = 1;

        case (CHANNEL_SIZE_choose)
            2'd0: CHANNEL_SIZE = 9'd256;
            2'd1: CHANNEL_SIZE = 9'd128;
            2'd2: CHANNEL_SIZE = 9'd64;
            default: CHANNEL_SIZE = 9'd256;
        endcase

        case (IMAGE_SIZE_choose)
            3'd0: IMAGE_SIZE = 8'd4;
            3'd1: IMAGE_SIZE = 8'd8;
            3'd2: IMAGE_SIZE = 8'd16;
            3'd3: IMAGE_SIZE = 8'd32;
            3'd4: IMAGE_SIZE = 8'd64;
            3'd5: IMAGE_SIZE = 8'd128;
            default: IMAGE_SIZE = 8'd4;
        endcase

        case (current_state)
            S_Reset: begin // Check if IMAGE_SIZE and CHANNEL_SIZE have to be 0 too in S_Reset
                slave_select = 0;
                conv_DONE = 0;
                en_reg_last_chan = 0;
                rst_reg_last_chan = 0;
                
                Kernel_BRAM_Reset = 0;
                load_BRAM_dina = 0;
                update_BRAM_doutb = 0;
                
                Input_line_buffer_Reset = 0;
                Stream_first_row = 0;
                Stream_mid_row = 0;
                Stream_last_row = 0;

                PE_with_buffers_Reset = 0;
                Load_kernel_reg = 0;

                en_top_row_counter = 0;
                rst_top_row_counter = 0;
            end

            S_Idle: begin
                slave_select = 1;
                Kernel_BRAM_Reset = 1;
                Input_line_buffer_Reset = 1;
                PE_with_buffers_Reset = 1;
                rst_top_row_counter = 1;
                rst_reg_last_chan = 1;
            end

            S_Loading_kernel_BRAM: begin
                slave_select = 0;
                load_BRAM_dina = 1;
            end

            S_Loading_kernel_reg: begin
                Load_kernel_reg = 1;
            end

            S_Wait_idle: ; // Same as Idle

            S_Stream_first_row: begin
                Stream_first_row = 1;
            end

            S_Wait_stream_first_row_finish: ; // Same as Idle

            S_Wait_idle_mid_row: ; // Same as Idle

            S_Stream_mid_row: begin
                Stream_mid_row = 1;
            end

            S_Wait_stream_mid_row_finish: begin
                if (Done_1row) begin
                    if (top_row_counter_out == IMAGE_SIZE-2) rst_top_row_counter = 0;
                    else en_top_row_counter = 1;
                end
            end

            S_Wait_idle_last_row: ; // Same as Idle

            S_Stream_last_row: begin
                 Stream_last_row = 1;
            end

            S_Wait_stream_last_row_finish: ; // Same as Idle

            S_Wait_idle_update_kernel_BRAM: ; // Same as Idle

            S_Update_BRAM_doutb: begin
                update_BRAM_doutb = 1;
                en_top_row_counter = 1;
            end

            S_Wait_update_BRAM_doutb: begin
                en_top_row_counter = 1;
                if (!reg_last_chan) begin
                    if (!last_channel) begin
                        if (top_row_counter_out == 3) begin
                            en_top_row_counter = 0;
                            rst_top_row_counter = 0;
                        end
                    end
                end     
            end

            S_En_reg_last_chan: begin
                en_reg_last_chan = 1;
                en_top_row_counter = 0;
                rst_top_row_counter = 0;
            end

            S_Done_conv: begin
                rst_reg_last_chan = 0;
                en_top_row_counter = 0;
                rst_top_row_counter = 0;
                conv_DONE = 1;
            end

            default: begin
                slave_select = 1;
                conv_DONE = 0;
                en_reg_last_chan = 0;
                rst_reg_last_chan = 1;
                
                Kernel_BRAM_Reset = 1;
                load_BRAM_dina = 0;
                update_BRAM_doutb = 0;
                
                Input_line_buffer_Reset = 1;
                Stream_first_row = 0;
                Stream_mid_row = 0;
                Stream_last_row = 0;

                PE_with_buffers_Reset = 1;
                Load_kernel_reg = 0;

                en_top_row_counter = 0;
                rst_top_row_counter = 1;
            end
        endcase
    end
    
endmodule