`timescale 1ns / 1ps

module pe_with_buffers_CU (
    input wire clk,
    input wire Reset,

    // Input interface from other submodules
    input wire [7:0] b_counter_output,
    input wire Load_kernel_reg,
    input wire Stream_mid_row,
    input wire Stream_last_row,
    input wire Output_valid,
    input wire Done_1row,
    input wire last_channel,
    input wire [14:0] a_output_BRAM_counter_out, // Add one bit for extending
    input wire m_axis_tready,

    // Control outputs
    // Interface outputs
    // AXI signals
    output reg m_axis_tvalid,
    output reg m_axis_tlast,

    output reg PE_ready,
    output reg PE_with_buffers_IDLE,

    // Internal outputs
    output reg ena_bias_BRAM_addr_counter,
    output reg rst_bias_BRAM_addr_counter,
    output reg add_bias,

    output reg Wr_kernel,
    output reg Rst_kernel,

    output reg ena_output_BRAM,
    output reg wea_output_BRAM,
    output reg enb_output_BRAM,

    output reg ena_output_BRAM_counter,
    output reg rsta_output_BRAM_counter
);
    
    parameter state_size = 5;
    parameter S_Reset                                           = 5'd0,
              S_Idle                                            = 5'd1,
              S_Load_kernel_reg                                 = 5'd2,
              S_PE_ready                                        = 5'd3,
              S_Wait_output_valid_mid_row                       = 5'd4,
              S_Writing_porta_output_BRAM_mid_row               = 5'd5,
              S_Wait_output_valid_last_row                      = 5'd6,
              S_Writing_porta_output_BRAM_last_row              = 5'd7,
              S_Reset_porta_counter                             = 5'd8,
              S_Idle_last_chan                                  = 5'd9,
              S_PE_ready_last_chan                              = 5'd10,
              S_Wait_output_valid_mid_row_last_chan             = 5'd11,
              S_Writing_porta_output_BRAM_mid_row_last_chan     = 5'd12,
              S_Wait_handshake_last_pixel_mid_row               = 5'd13,
              S_Wait_output_valid__last_row_last_chan           = 5'd14,
              S_Writing_porta_output_BRAM__last_row_last_chan   = 5'd15,
              S_Wait_handshake_last_pixel_last_row              = 5'd16;

    reg [state_size-1:0] current_state, next_state;

    // State transition block
    always @(posedge clk) begin
        if (!Reset) current_state <= S_Reset;
        else current_state <= next_state;
    end

    // State conditional block
    always @(*) begin
        next_state <= current_state;

        case (current_state)
            S_Reset: next_state <= S_Idle;

            S_Idle: begin
                if (Load_kernel_reg) next_state <= S_Load_kernel_reg;
                else if (Stream_mid_row) next_state <= S_Wait_output_valid_mid_row;
                else if (Stream_last_row) next_state <= S_Wait_output_valid_last_row;
                else if (last_channel) next_state <= S_Idle_last_chan;
                else next_state <= S_Idle;
            end

            S_Load_kernel_reg: next_state <= S_PE_ready;

            S_PE_ready: next_state <= S_Idle;

            S_Wait_output_valid_mid_row: begin
                if (Output_valid) next_state <= S_Writing_porta_output_BRAM_mid_row;
                else next_state <= S_Wait_output_valid_mid_row;
            end

            S_Writing_porta_output_BRAM_mid_row: begin
                if (Done_1row) next_state <= S_Idle;
                else begin
                    if (Output_valid) next_state <= S_Writing_porta_output_BRAM_mid_row;
                    else next_state <= S_Wait_output_valid_mid_row;
                end
            end

            S_Wait_output_valid_last_row: begin
                if (Output_valid) next_state <= S_Writing_porta_output_BRAM_last_row;
                else next_state <= S_Wait_output_valid_last_row;
            end

            S_Writing_porta_output_BRAM_last_row: begin
                if (Done_1row) next_state <= S_Reset_porta_counter;
                else begin
                    if (Output_valid) next_state <= S_Writing_porta_output_BRAM_last_row;
                    else next_state <= S_Wait_output_valid_last_row;
                end
            end

            S_Reset_porta_counter: next_state <= S_Idle;

            S_Idle_last_chan: begin
                if (Load_kernel_reg) next_state <= S_PE_ready_last_chan;
                else if (Stream_mid_row) next_state <= S_Wait_output_valid_mid_row_last_chan;
                else if (Stream_last_row) next_state <= S_Wait_output_valid__last_row_last_chan;
                else next_state <= S_Idle_last_chan;
            end

            S_PE_ready_last_chan: next_state <= S_Idle_last_chan;

            S_Wait_output_valid_mid_row_last_chan: begin
                if (Output_valid) begin
                    if (Done_1row && m_axis_tready) next_state <= S_Idle_last_chan;
                    else if (Done_1row) next_state <= S_Wait_handshake_last_pixel_mid_row;
                    else if (m_axis_tready) next_state <= S_Wait_output_valid_mid_row_last_chan;
                    else next_state <= S_Writing_porta_output_BRAM_mid_row_last_chan;
                end
                else next_state <= S_Wait_output_valid_mid_row_last_chan;
            end

            S_Writing_porta_output_BRAM_mid_row_last_chan: begin
                if (Done_1row && m_axis_tready) next_state <= S_Idle_last_chan;
                else if (Done_1row) next_state <= S_Wait_handshake_last_pixel_mid_row;
                else if (m_axis_tready) next_state <= S_Wait_output_valid_mid_row_last_chan;
                else next_state <= S_Writing_porta_output_BRAM_mid_row_last_chan;
            end

            S_Wait_handshake_last_pixel_mid_row: begin
                if (m_axis_tready) next_state <= S_Idle_last_chan;
                else next_state <= S_Wait_handshake_last_pixel_mid_row;
            end

            S_Wait_output_valid__last_row_last_chan: begin
                if (Output_valid) begin
                    if (Done_1row && m_axis_tready) next_state <= S_Idle;
                    else if (Done_1row) next_state <= S_Wait_handshake_last_pixel_last_row;
                    else if (m_axis_tready) next_state <= S_Wait_output_valid__last_row_last_chan;
                    else next_state <= S_Writing_porta_output_BRAM__last_row_last_chan;
                end
                else next_state <= S_Wait_output_valid__last_row_last_chan;
            end

            S_Writing_porta_output_BRAM__last_row_last_chan: begin
                if (Done_1row && m_axis_tready) next_state <= S_Idle;
                else if (Done_1row) next_state <= S_Wait_handshake_last_pixel_last_row;
                else if (m_axis_tready) next_state <= S_Wait_output_valid__last_row_last_chan;
                else next_state <= S_Writing_porta_output_BRAM__last_row_last_chan;
            end

            S_Wait_handshake_last_pixel_last_row: begin
                if (m_axis_tready) next_state <= S_Idle;
                else next_state <= S_Wait_handshake_last_pixel_last_row;
            end

            default: next_state <= S_Idle; 
        endcase
    end

    // State outputs
    always @(*) begin
        // Control outputs
        // Interface outputs
        // AXI signals
        m_axis_tvalid = 0;
        m_axis_tlast = 0;

        PE_ready = 0;
        PE_with_buffers_IDLE = 0;

        // Internal outputs
        ena_bias_BRAM_addr_counter = 0;
        rst_bias_BRAM_addr_counter = 1;
        add_bias = 0;

        Wr_kernel = 0;
        Rst_kernel = 1;

        ena_output_BRAM = 1;
        wea_output_BRAM = 0;
        enb_output_BRAM = 1;

        ena_output_BRAM_counter = 0;
        rsta_output_BRAM_counter = 1;

        case (current_state)
            S_Reset: begin
                m_axis_tvalid = 0;
                m_axis_tlast = 0;

                PE_ready = 0;
                PE_with_buffers_IDLE = 0;

                // Internal outputs
                ena_bias_BRAM_addr_counter = 0;
                rst_bias_BRAM_addr_counter = 0;
                add_bias = 0;

                Wr_kernel = 0;
                Rst_kernel = 0;

                ena_output_BRAM = 0;
                wea_output_BRAM = 0;
                enb_output_BRAM = 0;

                ena_output_BRAM_counter = 0;
                rsta_output_BRAM_counter = 0;
            end

            S_Idle: begin
                Rst_kernel = 1;
                ena_output_BRAM = 1;
                enb_output_BRAM = 1;
                rsta_output_BRAM_counter = 1;
                PE_with_buffers_IDLE = 1;
            end 

            S_Load_kernel_reg: Wr_kernel = 1;

            S_PE_ready: PE_ready = 1;

            S_Wait_output_valid_mid_row: begin
                add_bias = (b_counter_output == 0);
                if (Output_valid) begin
                    wea_output_BRAM = 1;
                    ena_output_BRAM_counter = 1;
                    add_bias = (b_counter_output == 0);
                end
            end

            S_Writing_porta_output_BRAM_mid_row: begin
                wea_output_BRAM = 1;
                ena_output_BRAM_counter = 1;
                add_bias = (b_counter_output == 0);
                if (!Done_1row) begin
                    if (!Output_valid) begin
                        wea_output_BRAM = 0;
                        ena_output_BRAM_counter = 0;
                        add_bias = (b_counter_output == 0);
                    end 
                end
            end

            S_Wait_output_valid_last_row: begin
                add_bias = (b_counter_output == 0);
                if (Output_valid) begin
                    wea_output_BRAM = 1;
                    ena_output_BRAM_counter = 1;
                    add_bias = (b_counter_output == 0);
                end
            end

            S_Writing_porta_output_BRAM_last_row: begin
                wea_output_BRAM = 1;
                ena_output_BRAM_counter = 1;
                add_bias = (b_counter_output == 0);
                if (!Done_1row) begin
                    if (!Output_valid) begin
                        wea_output_BRAM = 0;
                        ena_output_BRAM_counter = 0;
                        add_bias = (b_counter_output == 0);
                    end
                end
            end

            S_Reset_porta_counter: rsta_output_BRAM_counter = 0;

            S_Idle_last_chan: begin
                Rst_kernel = 1;
                ena_output_BRAM = 1;
                enb_output_BRAM = 1;
                rsta_output_BRAM_counter = 1;
                PE_with_buffers_IDLE = 1;
                if (Load_kernel_reg) Wr_kernel = 1;
            end

            S_PE_ready_last_chan: PE_ready = 1;

            S_Wait_output_valid_mid_row_last_chan: begin
                if (Output_valid) begin
                    m_axis_tvalid = 1;
                    if (Done_1row && m_axis_tready) begin
                        ena_output_BRAM_counter = 1;
                    end
                    else if (m_axis_tready) begin
                        ena_output_BRAM_counter = 1;
                    end
                end
            end

            S_Writing_porta_output_BRAM_mid_row_last_chan: begin
                m_axis_tvalid = 1;
                if (Done_1row && m_axis_tready) begin
                    ena_output_BRAM_counter = 1;
                end
                else if (m_axis_tready) begin
                    ena_output_BRAM_counter = 1;
                end
            end

            S_Wait_handshake_last_pixel_mid_row: begin
                m_axis_tvalid = 1;
                if (m_axis_tready) begin
                    ena_output_BRAM_counter = 1;
                end
            end

            S_Wait_output_valid__last_row_last_chan: begin
                if (Output_valid) begin
                    m_axis_tvalid = 1;
                    if (Done_1row && m_axis_tready) begin
                        m_axis_tvalid = 1;
                        m_axis_tlast = 1;
                        rsta_output_BRAM_counter = 0;
                    end
                    else if (m_axis_tready) begin
                        ena_output_BRAM_counter = 1;
                    end
                end
            end

            S_Writing_porta_output_BRAM__last_row_last_chan: begin
                m_axis_tvalid = 1;
                if (Done_1row && m_axis_tready) begin
                    m_axis_tvalid = 1;
                    m_axis_tlast = 1;
                    rsta_output_BRAM_counter = 0;
                end
                else if (m_axis_tready) begin
                    ena_output_BRAM_counter = 1;
                end
            end

            S_Wait_handshake_last_pixel_last_row: begin
                m_axis_tvalid = 1;
                m_axis_tlast = 1;
                if (m_axis_tready) begin
                    rsta_output_BRAM_counter = 0;
                    ena_bias_BRAM_addr_counter = 1;
                end
            end

            default: begin
                m_axis_tvalid = 0;
                m_axis_tlast = 0;

                PE_ready = 0;
                PE_with_buffers_IDLE = 0;

                // Internal outputs
                ena_bias_BRAM_addr_counter = 0;
                add_bias = 0;

                Wr_kernel = 0;
                Rst_kernel = 1;

                ena_output_BRAM = 1;
                wea_output_BRAM = 0;
                enb_output_BRAM = 1;

                ena_output_BRAM_counter = 0;
                rsta_output_BRAM_counter = 1;
            end
        endcase
    end

endmodule