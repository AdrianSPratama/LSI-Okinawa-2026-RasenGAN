`timescale 1ns/1ps

module tb_axis_adain;

    // --- Parameter & Sinyal ---
    parameter WIDTH_IN  = 48;
    parameter WIDTH_OUT = 16;
    parameter N_MAX     = 128;
    
    reg clk, rstn;
    reg [2:0] gpio_N_sel;
    
    // Slave Interface (Input)
    reg [WIDTH_IN-1:0] s_axis_tdata;
    wire               s_axis_tvalid; // Pakai wire untuk logika toggle
    wire               s_axis_tready;
    reg                s_axis_tlast;
    
    // Master Interface (Output)
    wire [WIDTH_OUT-1:0] m_axis_tdata;
    wire                 m_axis_tvalid;
    reg                  m_axis_tready; 
    wire                 m_axis_tlast;

    // Logika Oscillator Internal
    reg data_ready_to_send;
    reg v_toggle;         // Toggle tiap 1 clock
    reg [1:0] r_counter;  // Toggle tiap 2 clock

    // Data Memori (16 piksel untuk 4x4)
    reg [WIDTH_IN-1:0] x_mem [0:15];
    integer i;

    // --- Instansiasi UUT ---
    axis_adain #(
        .WIDTH_IN(WIDTH_IN),
        .WIDTH_OUT(WIDTH_OUT),
        .N_MAX(N_MAX)
    ) uut (
        .clk(clk), .rstn(rstn), .gpio_N_sel(gpio_N_sel),
        .s_axis_tdata(s_axis_tdata), .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready), .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast)
    );

    // --- Clock Generation ---
    initial clk = 0;
    always #5 clk = ~clk;

    // --- LOGIKA TOGGLE ---
    // s_valid toggle tiap 1 clock
    always @(posedge clk) begin
        if (!rstn) v_toggle <= 1'b0;
        else       v_toggle <= ~v_toggle;
    end
    assign s_axis_tvalid = data_ready_to_send & v_toggle;

    // m_ready toggle tiap 2 clock
    always @(posedge clk) begin
        if (!rstn) begin
            m_axis_tready <= 1'b0;
            r_counter     <= 2'd0;
        end else begin
            if (r_counter == 2'd1) begin
                m_axis_tready <= ~m_axis_tready;
                r_counter     <= 2'd0;
            end else begin
                r_counter     <= r_counter + 2'd1;
            end
        end
    end

    // --- Stimulus ---
    initial begin
        // 1. Inisialisasi Data 1 s/d 16 (Format Q32.16)
        for (i = 0; i < 16; i = i + 1) begin
            x_mem[i] = (i + 1) << 16; 
        end
        
        // 2. Reset
        rstn               <= 0; 
        gpio_N_sel         <= 3'd0; // N=4
        data_ready_to_send <= 0;
        s_axis_tlast       <= 0;
        s_axis_tdata       <= 48'd0;
        
        repeat(10) @(posedge clk);
        rstn <= 1;
        repeat(5) @(posedge clk);

        // --- LANGKAH 1: Metadata ---
        $display("[%0t] Mengirim ys & yb...", $time);
        send_data(48'h0000_0001_0000, 0); // ys
        send_data(48'h0000_0000_0000, 0); // yb

        // --- LANGKAH 2: Fase SCAN (Pass 1 - 16 Data) ---
        $display("[%0t] Memulai Fase SCAN...", $time);
        for (i = 0; i < 16; i = i + 1) begin
            send_data(x_mem[i], (i == 15));
        end
        data_ready_to_send <= 0;

        // Tunggu transisi ke Normalisasi
        wait(uut.control_unit.state == 2'd3); 
        repeat(10) @(posedge clk);

        // --- LANGKAH 3: Fase NORMALISASI (Pass 2 - 16 Data) ---
        $display("[%0t] Memulai Fase NORMALISASI...", $time);
        for (i = 0; i < 16; i = i + 1) begin
            send_data(x_mem[i], (i == 15));
        end
        data_ready_to_send <= 0;

        // Tunggu handshake Master terakhir
        wait(m_axis_tlast && m_axis_tvalid && m_axis_tready);
        repeat(10) @(posedge clk);
        
        $display("[%0t] Simulasi Selesai.", $time);
        $finish;
    end

    // Task untuk sinkronisasi handshake yang berdenyut
    task send_data;
        input [WIDTH_IN-1:0] data;
        input last;
        begin
            s_axis_tdata       <= data;
            s_axis_tlast       <= last;
            data_ready_to_send <= 1;
            @(posedge clk);
            // Tunggu sampai handshake berhasil (Valid & Ready bertemu)
            while (!(s_axis_tvalid && s_axis_tready)) @(posedge clk);
            data_ready_to_send <= 0;
        end
    endtask

    always @(posedge clk)
        if (m_axis_tvalid && m_axis_tready)
            $display("[%0t] Master Out: %h", $time, m_axis_tdata);

endmodule