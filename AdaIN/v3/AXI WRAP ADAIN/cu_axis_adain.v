`timescale 1ns/1ps

module cu_axis_adain (
    input  wire        clk,
    input  wire        rst,

    // Interface AXI-Stream Slave
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire        s_axis_tlast,

    // Interface AXI-Stream Master
    input  wire        m_axis_tready,
    output wire        m_axis_tvalid,
    output wire        m_axis_tlast,

    // Interface ke Core (top_adain)
    input  wire        core_ready,
    input  wire        core_valid,
    input  wire        core_last,
    input  wire        core_scan_done,
    output reg  [1:0]  core_start,
    output wire        core_en,
    
    // Kontrol Metadata
    output wire        en_ys,
    output wire        en_yb
);
    // Definisi State
    localparam S_STORE_YS  = 2'd0; // Menunggu data pertama (ys)
    localparam S_STORE_YB  = 2'd1; // Menunggu data kedua (yb)
    localparam S_RUN_SCAN  = 2'd2; // Proses akumulasi statistik
    localparam S_RUN_NORM  = 2'd3; // Proses normalisasi & output

    reg [1:0] state;
    wire handshake = s_axis_tvalid & s_axis_tready;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_STORE_YS;
            core_start <= 2'b00;
        end else begin
            case (state)
                S_STORE_YS: begin
                    core_start <= 2'b00;
                    if (handshake) begin
                        state <= S_STORE_YB;
                    end
                end

                S_STORE_YB: begin
                    if (handshake) begin
                        state <= S_RUN_SCAN;

                        core_start <= 2'b01;
                    end
                end

                S_RUN_SCAN: begin
                    if (core_scan_done) begin
                        state <= S_RUN_NORM;

                        core_start <= 2'b10;
                    end else begin
                        if (handshake) begin
                            core_start  <= 2'b00;
                        end
                    end
                end

                S_RUN_NORM: begin
                    if (m_axis_tlast) begin
                        state <= S_STORE_YS;
                    end else begin
                        if (handshake) begin
                            core_start  <= 2'b00;
                        end
                    end
                end

                default: state <= S_STORE_YS;
            endcase
        end
    end

    // Logika kontrol register metadata
    assign en_ys = (state == S_STORE_YS);
    assign en_yb = (state == S_STORE_YB);

    // Logika Stall (Flow Control)
    wire stall_in     = core_ready & !s_axis_tvalid;
    wire stall_out    = core_valid & !m_axis_tready;
    
    assign core_en = !(stall_in | stall_out);

    // Pemetaan Handshaking AXIS
    assign s_axis_tready = core_ready & !stall_out;
    assign m_axis_tvalid = core_valid & !stall_in;
    assign m_axis_tlast  = core_last;
endmodule