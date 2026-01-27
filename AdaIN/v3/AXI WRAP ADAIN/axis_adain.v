`timescale 1ns/1ps

module axis_adain #(
    parameter WIDTH_IN  = 48,
    parameter WIDTH_OUT = 16,
    parameter N_MAX     = 128
)(
    // Global Signals
    input  wire                    clk,
    input  wire                    rstn,

    input  wire [2:0]              gpio_N_sel,

    // AXI-Stream Slave Interface (Input)
    input  wire [WIDTH_IN-1:0]     s_axis_tdata,
    input  wire                    s_axis_tvalid,
    output wire                    s_axis_tready,
    input  wire                    s_axis_tlast,

    // AXI-Stream Master Interface (Output)
    output wire [WIDTH_OUT-1:0]    m_axis_tdata,
    output wire                    m_axis_tvalid,
    input  wire                    m_axis_tready,
    output wire                    m_axis_tlast
);

    // --- Localparams & Wires ---
    localparam WIDTH_N = $clog2(N_MAX+1);
    
    wire [WIDTH_N-1:0]  N;
    wire [WIDTH_IN-1:0] ys, yb;
    wire [1:0]          core_start;
    wire                core_en, en_ys, en_yb;
    wire                core_ready, core_valid, core_last, core_scan_done;
    
    wire [6*WIDTH_N-1:0] N_mux_option = {
        8'b10000000, // sel 5: 128
        8'b01000000, // sel 4: 64
        8'b00100000, // sel 3: 32
        8'b00010000, // sel 2: 16
        8'b00001000, // sel 1: 8
        8'b00000100  // sel 0: 4
    };

    // --- Instances ---

    // 1. MUX untuk Pemilihan Nilai N
    mux_nto1 #(
        .N(6),
        .WIDTH(WIDTH_N)
    ) mux_n (
        .sel(gpio_N_sel),
        .in(N_mux_option),
        .out(N)
    );

    // 2. Register Sinkron untuk Menyimpan ys
    reg_sync_rst #(
        .WIDTH(WIDTH_IN)
    ) reg_ys (
        .clk(clk),
        .rst(!rstn),
        .en(en_ys),
        .in(s_axis_tdata),
        .out(ys)
    );

    // 3. Register Sinkron untuk Menyimpan yb
    reg_sync_rst #(
        .WIDTH(WIDTH_IN)
    ) reg_yb (
        .clk(clk),
        .rst(!rstn),
        .en(en_yb),
        .in(s_axis_tdata),
        .out(yb)
    );

    // 4. Unit Kontrol AXI-Stream
    cu_axis_adain control_unit (
        .clk(clk),
        .rst(!rstn),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tready(m_axis_tready),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast),
        .core_ready(core_ready),
        .core_valid(core_valid),
        .core_last(core_last),
        .core_scan_done(core_scan_done),
        .core_start(core_start),
        .core_en(core_en),
        .en_ys(en_ys),
        .en_yb(en_yb)
    );

    // 5. Modul Inti AdaIN
    top_adain #(
        .WIDTH_IN(WIDTH_IN),
        .WIDTH_OUT(WIDTH_OUT),
        .N_MAX(N_MAX)
    ) core_adain (
        .clk(clk),
        .rst(!rstn),
        .en(core_en),
        .start(core_start),
        .N(N),
        .in(s_axis_tdata),
        .ys(ys),
        .yb(yb),
        .out(m_axis_tdata),
        .scan_done(core_scan_done),
        .ready(core_ready),
        .valid(core_valid),
        .last(core_last)
    );
endmodule