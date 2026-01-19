`timescale 1ns / 1ps

module kernel_BRAM_CU (
    // Control inputs
    input wire clk,
    input wire Reset,
    input wire load_BRAM_dina,
    input wire update_BRAM_doutb,
    input wire [8:0] CHANNEL_SIZE,
    input wire [8:0] a_counter_output,
    input wire [7:0] b_counter_output,
    input wire s_axis_tvalid,
    input wire s_axis_tlast, // Not used

    // Control outputs
    output reg last_loading_1ker,
    output reg last_channel,
    output reg ena_ker_BRAM,
    output reg wea_ker_BRAM,
    output reg enb_ker_BRAM,
    output reg enb_ker_BRAM_counter,
    output reg rstb_ker_BRAM_counter,
    output reg ena_ker_BRAM_counter,
    output reg rsta_ker_BRAM_counter,
    output reg s_axis_tready
);

    parameter state_size = 3;
    parameter S_Reset = 3'd0,
            S_Idle = 3'd1,
            S_Wait_saxis_tvalid = 3'd2,
            S_Loading_ker_BRAM = 3'd3,
            S_Inc_addrb = 3'd4,
            S_Check_counter_b = 3'd5,
            S_Reset_counter_b = 3'd6;

    // State register
    reg [state_size-1:0] current_state;

    // State transition block
    always @(posedge clk) begin
        if (!Reset) current_state <= S_Reset;
        else begin
            case (current_state)
                S_Reset: current_state <= S_Idle;

                S_Idle: begin
                    if (load_BRAM_dina) current_state <= S_Wait_saxis_tvalid;
                    else if (update_BRAM_doutb) current_state <= S_Inc_addrb;
                    else current_state <= S_Idle;
                end

                S_Wait_saxis_tvalid: begin
                    if (s_axis_tvalid) current_state <= S_Loading_ker_BRAM;
                    else current_state <= S_Wait_saxis_tvalid;
                end

                S_Loading_ker_BRAM: begin
                    if (a_counter_output > CHANNEL_SIZE-1) current_state <= S_Idle;
                    else begin
                        if (s_axis_tvalid) current_state <= S_Loading_ker_BRAM;
                        else current_state <= S_Wait_saxis_tvalid;
                    end
                end

                S_Inc_addrb: current_state <= S_Check_counter_b;

                S_Check_counter_b: begin
                    if(b_counter_output == CHANNEL_SIZE - 1) begin
                        current_state <= S_Reset_counter_b;
                    end
                    else begin
                        current_state <= S_Idle;    
                    end
                end

                S_Reset_counter_b: current_state <= S_Idle;

                default: current_state <= S_Reset;
            endcase
        end
    end

    // State output block
    always @(*) begin
        // Defaults
        last_loading_1ker = 0;
        last_channel = 0;
        ena_ker_BRAM = 1;
        wea_ker_BRAM = 0;
        enb_ker_BRAM = 1;
        enb_ker_BRAM_counter = 0;
        rstb_ker_BRAM_counter = 1;
        ena_ker_BRAM_counter = 0;
        rsta_ker_BRAM_counter = 1;
        s_axis_tready = 0;

        case (current_state)
            S_Reset: begin
                last_loading_1ker = 0;
                last_channel = 0;
                ena_ker_BRAM = 0;
                wea_ker_BRAM = 0;
                enb_ker_BRAM = 0;
                rstb_ker_BRAM_counter = 0;
                ena_ker_BRAM_counter = 0;
                rsta_ker_BRAM_counter = 0;
                s_axis_tready = 0;
            end

            S_Idle: begin
                ena_ker_BRAM = 1;
                enb_ker_BRAM = 1;
                rsta_ker_BRAM_counter = 1;
                rstb_ker_BRAM_counter = 1;
            end

            S_Wait_saxis_tvalid: begin
                s_axis_tready = 1;
                if (s_axis_tvalid) begin
                    wea_ker_BRAM = 1;
                    ena_ker_BRAM_counter = 1;
                end
                else begin
                    wea_ker_BRAM = 0;
                    ena_ker_BRAM_counter = 0;
                end
            end

            S_Loading_ker_BRAM: begin
                s_axis_tready = 1;
                wea_ker_BRAM = 1;
                ena_ker_BRAM_counter = 1;
                if (a_counter_output > CHANNEL_SIZE-1) begin
                    last_loading_1ker = 1;
                    rsta_ker_BRAM_counter = 0;
                end
                else begin
                    if (!s_axis_tvalid) begin
                        wea_ker_BRAM = 0;
                        ena_ker_BRAM_counter = 0;
                    end
                end
            end

            S_Inc_addrb: enb_ker_BRAM_counter = 1;

            S_Check_counter_b: begin
                enb_ker_BRAM_counter = 0;
                if (b_counter_output == CHANNEL_SIZE - 1) last_channel = 1;
                else last_channel = 0;
            end

            S_Reset_counter_b: begin
                rstb_ker_BRAM_counter = 0;
            end

            default: begin
                last_loading_1ker = 0;
                last_channel = 0;
                ena_ker_BRAM = 1;
                wea_ker_BRAM = 0;
                enb_ker_BRAM = 1;
                enb_ker_BRAM_counter = 0;
                rstb_ker_BRAM_counter = 1;
                ena_ker_BRAM_counter = 0;
                rsta_ker_BRAM_counter = 1;
                s_axis_tready = 0;
            end
        endcase
    end

endmodule