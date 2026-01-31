`timescale 1ns / 1ps
`include "top_upsample.v"
module top_upsample_axi #(
    parameter DATA_WIDTH = 16,
    parameter length = 16
)(
    input  wire                   clk,
    input  wire                   reset,
    input  wire start_process,

    // --- Slave Interface (Input dari DDR/DMA) ---
    input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
    input  wire                   s_axis_tlast, // (Opsional digunakan untuk double check)
    input  wire                   s_axis_tvalid,
    output reg                    s_axis_tready,

    // --- Master Interface (Output ke DDR/DMA) ---
    output wire [DATA_WIDTH-1:0]  m_axis_tdata,
    output wire                   m_axis_tlast,
    output reg                    m_axis_tvalid,
    input  wire                   m_axis_tready,

    // --- Interface Kontrol Eksternal (Opsional untuk Hardware Lain) ---
    output reg                    proc_start, // Sinyal memulai operasi
    input  wire                   proc_done   // Sinyal operasi selesai (bisa di-hardcode jika simulasi)
);

    // Definisi State FSM
    localparam [2:0] S_IDLE    = 3'b000;
    localparam [2:0] S_RX      = 3'b001; // Menerima data ke BRAM 1
    localparam [2:0] S_PROCESS = 3'b010; // Menunggu proses selesai
    localparam [2:0] S_TX      = 3'b011; // Mengirim data dari BRAM 2
    localparam [2:0] S_chose_layer = 3'b010;

    reg [2:0] current_state;

    reg [2:0] upsampling_order;
    reg [11:0] num_pixels_in;
    reg [13:0] num_pixels_out;
    reg [8:0] num_of_channels;
    reg [8:0] layer;
    reg [2:0] size_upsample;

    reg rst_upsample;

    // Definisi BRAM (Inferred Memory)
    // Menggunakan integer untuk index agar mudah dibaca
    reg [DATA_WIDTH-1:0] bram_input  [0:4095];
    reg [DATA_WIDTH-1:0] bram_output [0:16383];

    // Pointer/Counter
    reg [11:0] rx_ptr;
    reg [13:0] tx_ptr;

    // Sinyal Internal untuk Simulasi Proses (Jika tidak ada modul eksternal)
    wire internal_done;
    reg [3:0] process_timer; // Timer sederhana untuk simulasi delay proses

    // -------------------------------------------------------------------------
    // 1. FSM UTAMA                                                              
    // -------------------------------------------------------------------------



    always @(posedge clk) begin
        if (!reset) begin
            current_state <= S_IDLE;
            rx_ptr <= 0;
            tx_ptr <= 0;
            proc_start <= 0;
            upsampling_order <= 0;
            s_axis_tready <= 0;
            m_axis_tvalid <= 0;
            layer <= 0;
            rst_upsample <= 1;
        end else begin
            case (current_state)
                // --- STATE IDLE ---
                S_IDLE: begin
                    rx_ptr <= 0;
                    tx_ptr <= 0;
                    m_axis_tvalid <= 0;

                    // Siap menerima data, pindah ke RX
                    if (start_process) begin
                    s_axis_tready <= 1;
                    current_state <= S_chose_layer;
                    end
                end


                S_chose_layer : begin

                    if (layer == num_of_channels - 1) begin
                        upsampling_order <= upsampling_order + 1;
                        current_state <= S_IDLE;
                    end
                    else begin
                        layer <= layer + 1;
                        current_state <= S_RX;
                        rst_upsample <= 1;
                    end
                end

                // --- STATE RX: Isi BRAM 1 ---
                S_RX: begin
                    if (s_axis_tvalid && s_axis_tready) begin
                        // Tulis ke BRAM 1
                        bram_input[rx_ptr] <= s_axis_tdata;
                        // Cek apakah kuota sudah penuh
                        if (rx_ptr == num_pixels_in - 1) begin
                            s_axis_tready <= 0; // Stop terima data
                            rst_upsample <= 0;
                            proc_start    <= 1; // Trigger operasi
                            current_state <= S_PROCESS;
                        end else begin
                            rx_ptr <= rx_ptr + 1;
                        end
                    end
                end

                // --- STATE PROCESS: Tunggu Sinyal Done ---
                S_PROCESS: begin
                    proc_start <= 0; // Pulse start cukup 1 cycle (opsional)
                    // Gunakan "internal_done" (logika simulasi di bawah) 
                    // atau "proc_done" (input port)
                    if (internal_done) begin
                        current_state <= S_TX;
                        m_axis_tvalid <= 1; // Mulai request kirim
                    end
                end

                // --- STATE TX: Kirim BRAM 2 ke DMA ---
                S_TX: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        // Data terbaca, geser pointer
                        if (tx_ptr == num_pixels_out - 1) begin
                            m_axis_tvalid <= 0; // Selesai kirim
                            current_state <= S_chose_layer;
                        end else begin
                            tx_ptr <= tx_ptr + 1;
                        end
                    end
                end
            endcase
        end
    end


    always @(*) begin
        case (size_upsample)
            3'b000: num_pixels_in = 16; // 4x4 upsample
            3'b001: num_pixels_in = 64; // 8x8 upsample
            3'b010: num_pixels_in = 256; // 16x16 upsample
            3'b011: num_pixels_in = 1024; // 32x32 upsample
            3'b100: num_pixels_in = 4096; // 64x64 upsample
            default: num_pixels_in = 16;
        endcase

        num_pixels_out = num_pixels_in << 2;


        case (upsampling_order)
            3'b000: begin
                num_of_channels = 256; // Layer 1
                size_upsample = 3'b000;
            end

            3'b001: begin
                num_of_channels = 256; // Layer 2
                size_upsample = 3'b001;
            end
            3'b010: begin
                num_of_channels = 256; // Layer 3
                size_upsample = 3'b010;
            end
            3'b011: begin
                num_of_channels = 256; // Layer 4
                size_upsample = 3'b011;
            end
            3'b100: begin
                num_of_channels = 128; // Layer 5
                size_upsample = 3'b100;
            end
            3'b101: begin
                num_of_channels = 64; // Layer 6
                size_upsample = 3'b101;
            end
            default: begin
                num_of_channels = 0;
                size_upsample = 3'b000;
            end
        endcase
    end


    // -------------------------------------------------------------------------
    // 2. LOGIKA OUTPUT DATA (TX)
    // -------------------------------------------------------------------------
    // Ambil data dari BRAM 2 berdasarkan pointer TX
    assign m_axis_tdata = bram_output[tx_ptr];
    
    // TLast aktif hanya pada kata terakhir
    assign m_axis_tlast = (tx_ptr == num_pixels_out - 1) && (current_state == S_TX);


    // -------------------------------------------------------------------------
    // 3. SIMULASI LOGIKA PROSES (INTERNAL)
    // -------------------------------------------------------------------------
    wire [length-1:0] t_data_in;
    wire [length-1:0] t_data_out;

    reg [length-1:0] r_data_in_bram;

    wire [13:0] addr_input;
    wire [13:0] addr_output;

    wire en_write_out;

    assign t_data_in = r_data_in_bram;


    // baca tulis bram
    always @(posedge clk) begin
        r_data_in_bram <= bram_input[addr_input];
    end

    // --- BRAM OUTPUT (Write Port) ---
    // Prilaku BRAM: Data ditulis saat clock naik jika Write Enable aktif.
    always @(posedge clk) begin
        // Menggunakan sinyal write enable dari DUT (uut.en_write_out)
        if (en_write_out) begin 
                bram_output[addr_output] <= t_data_out;
        end
    end

    

    top_upsample top_upsample_inst (
        .clk(clk),
        .rst(rst_upsample),
        .start(proc_start),
        .size_upsample(size_upsample),
        .done(internal_done),
        .t_data_in(t_data_in),
        .t_data_out(t_data_out),
        .en_write_out(en_write_out),
        .addr_input(addr_input),
        .addr_output(addr_output)
    );

    

endmodule