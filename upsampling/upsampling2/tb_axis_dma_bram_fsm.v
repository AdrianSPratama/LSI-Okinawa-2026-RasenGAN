`timescale 1ns / 1ps

`include "axis_dma_bram_fsm.v"

module tb_axis_dma_bram_fsm;

    // ==========================================
    // 1. Parameter & Sinyal
    // ==========================================
    parameter DATA_WIDTH = 32;
    parameter LENGTH = 16;

    reg clk;
    reg aresetn;
    reg start_process;

    // AXI Slave (Input dari Testbench ke DUT)
    reg [DATA_WIDTH-1:0] s_axis_tdata;
    reg s_axis_tlast;
    reg s_axis_tvalid;
    wire s_axis_tready;

    // AXI Master (Output dari DUT ke Testbench)
    wire [DATA_WIDTH-1:0] m_axis_tdata;
    wire m_axis_tlast;
    wire m_axis_tvalid;
    reg m_axis_tready;

    // Sinyal kontrol simulasi
    reg proc_done;
    wire proc_start;

    integer i;
    integer data_value;

    // ==========================================
    // 2. Instansiasi DUT (Device Under Test)
    // ==========================================
    axis_dma_bram_fsm #(
        .DATA_WIDTH(DATA_WIDTH),
        .length(LENGTH)
    ) uut (
        .clk(clk),
        .aresetn(aresetn),
        .start_process(start_process),
        
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tlast(m_axis_tlast),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        
        .proc_start(proc_start),
        .proc_done(proc_done)
    );

    // ==========================================
    // 3. Clock Generation (100 MHz)
    // ==========================================
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    // ==========================================
    // 4. Stimulus Utama (DMA Emulator)
    // ==========================================
    initial begin
        // --- Setup Waveform ---
        $dumpfile("tb_dma_wave.vcd");
        $dumpvars(0, tb_axis_dma_bram_fsm);

        // --- Inisialisasi Awal ---
        aresetn = 0;       // Reset aktif (low)
        start_process = 0;
        s_axis_tdata = 0;
        s_axis_tlast = 0;
        s_axis_tvalid = 0;
        m_axis_tready = 1; // Testbench selalu siap terima hasil
        proc_done = 0;
        data_value = 50;   // Nilai awal sesuai request

        // [HACK] Memaksa konfigurasi internal DUT karena port tidak tersedia
        // Kita set size_upsample ke mode yang cukup besar, 
        // tapi kita paksa num_pixels_in jadi 48 agar FSM trigger di data ke-48.
        #1; 

        $display("---------------------------------------------");
        $display("SIMULATION START");
        $display("---------------------------------------------");

        // --- Reset Release ---
        #20 aresetn = 1;   // Lepas reset
        #20;

        // --- Trigger Start Process ---
        $display("[t=%0t] Sending Start Signal...", $time);
        start_process = 1;
        #10 start_process = 0;

        // Tunggu sampai DUT siap (State pindah ke S_RX)
        wait(s_axis_tready);
        $display("[t=%0t] DUT Ready to Receive (S_RX)", $time);

        // --- LOOP PENGIRIMAN DATA (DMA EMULATION) ---
        // Kirim 48 data: 50, 60, 70, ..., 520
        for (i = 0; i < 48; i = i + 1) begin
            
            // 1. Setup Data di Bus
            s_axis_tvalid = 1;
            s_axis_tdata  = data_value;
            
            // Optional: Set TLAST di data terakhir
            if (i == 47) s_axis_tlast = 1;
            else s_axis_tlast = 0;

            // 2. Handshake Mechanism (AXI Stream Standard)
            // Data hanya dianggap masuk jika (Valid=1 AND Ready=1) pada rising edge clk
            // Kita tunggu sampai s_axis_tready bernilai 1
            wait(s_axis_tready);
            
            // 3. Sinkronisasi dengan Clock
            @(posedge clk); 
            
            // Log untuk debug
            // $display("[t=%0t] DMA Sent: %d (Item %0d/48)", $time, data_value, i+1);

            // 4. Update nilai untuk loop berikutnya
            data_value = data_value + 10;

            // 5. Idle sebentar (Optional: meniru gap antar data DMA)
            // Hilangkan baris di bawah jika ingin burst full speed
            #1; 
            s_axis_tvalid = 0; 
            s_axis_tlast = 0;
        end
        
        // Matikan valid setelah loop selesai
        s_axis_tvalid = 0;
        $display("[t=%0t] All 48 data transferred to BRAM.", $time);

        // --- Tunggu Fase Processing ---
        // DUT akan masuk ke S_PROCESS. Kita tunggu sampai output valid muncul.
        // Karena logic internal_done terhubung ke modul upsample, kita tunggu hasil keluarnya.
        
        $display("[t=%0t] Waiting for processing to finish...", $time);
        
        // // Timeout check agar simulasi tidak hang selamanya
        // fork : wait_output
        //     begin
        //         wait(m_axis_tvalid);
        //         $display("[t=%0t] Output detected! Receiving data...", $time);
        //     end
        //     begin
        //         #50000; // Timeout setelah 50us
        //         $display("[t=%0t] Timeout waiting for output!", $time);
        //         $finish;
        //     end
        // join_any
        // disable wait_output;

        // --- Terima Output (Monitor) ---
        while (m_axis_tvalid) begin
            @(posedge clk);
            if (m_axis_tready && m_axis_tvalid) begin
                $write("%d ", m_axis_tdata);
            end
        end

        $display("\n---------------------------------------------");
        $display("SIMULATION DONE");
        $display("---------------------------------------------");
        #100;
        $finish;
    end

endmodule