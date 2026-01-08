`timescale 1ns / 1ps

module tb_true_dual_port_bram_sync;

    // 1. Parameters
    parameter RAM_WIDTH = 32;
    parameter RAM_DEPTH = 16; 
    parameter ADDR_WIDTH = 4;

    // 2. Inputs (Regs driven by Testbench)
    reg clk; // Single clock for simplicity
    reg ena, wea, enb, web;
    reg [ADDR_WIDTH-1:0] addra, addrb;
    reg [RAM_WIDTH-1:0]  dina, dinb;

    // 3. Outputs
    wire [RAM_WIDTH-1:0] douta;
    wire [RAM_WIDTH-1:0] doutb;

    // 4. Instantiate DUT
    true_dual_port_bram #(
        .RAM_WIDTH(RAM_WIDTH), .RAM_DEPTH(RAM_DEPTH)
    ) dut (
        .clka(clk), .ena(ena), .wea(wea), .addra(addra), .dina(dina), .douta(douta),
        .clkb(clk), .enb(enb), .web(web), .addrb(addrb), .dinb(dinb), .doutb(doutb)
    );

    // 5. Clock Gen (100MHz)
    initial clk = 0;
    always #5 clk = ~clk;

    // 6. Synchronous Stimulus
    initial begin
        $display("--- Synchronous BRAM Test Start ---");
        
        // Initialize everything to 0 using Non-Blocking
        ena <= 0; wea <= 0; addra <= 0; dina <= 0;
        enb <= 0; web <= 0; addrb <= 0; dinb <= 0;
        
        // Wait for global reset/startup
        repeat (5) @(posedge clk);


        // --- TEST CASE 1: WRITE (Port A) ---
        // We drive the signals at Edge T. 
        // The BRAM sees them at Edge T+1.
        $display("[%0t] Driving Write Command (Addr 3, Data 0xA5A5)", $time);
        
        @(posedge clk); 
        ena   <= 1;          // Enable A
        wea   <= 1;          // Write Mode
        addra <= 4'd3;       // Address 3
        dina  <= 32'hA5A5;   // Data
        
        // --- IDLE CYCLE ---
        // We must clear the signals at the next edge, 
        // otherwise we will write to Addr 3 again (or whatever Addr becomes).
        @(posedge clk);
        $display("[%0t] Write Command Captured by BRAM", $time);
        ena   <= 0;          // Turn off
        wea   <= 0;
        dina  <= 0;


        // --- TEST CASE 2: READ (Port B) ---
        repeat (2) @(posedge clk); // Gap
        $display("[%0t] Driving Read Command (Addr 3)", $time);

        @(posedge clk);
        enb   <= 1;          // Enable B
        web   <= 0;          // Read Mode
        addrb <= 4'd3;       // Address 3
        
        // Wait for BRAM to capture the command (1 cycle)
        @(posedge clk);
        $display("[%0t] Read Command Captured by BRAM", $time);
        enb   <= 0; // Turn off signals (optional, BRAM holds output)

        // Wait for Data to be stable on output (Register delay)
        // Since BRAM output is registered, it appears just after the capture edge.
        @(posedge clk); 
        $display("[%0t] CHECKING OUTPUT: %h", $time, doutb);
        
        if (doutb == 32'hA5A5) $display("--> PASS: Read Success");
        else                   $display("--> FAIL: Read Mismatch");


        // --- TEST CASE 3: Simultaneous Read/Write (Read-First Collision) ---
        // Same Address (Addr 3), Same Port (A)
        // Current value is A5A5. We write FFFF. Expect to read A5A5 (Old value).
        
        repeat (2) @(posedge clk);
        $display("[%0t] Driving Collision: Write 0xFFFF to Addr 3 (Read-First Check)", $time);

        @(posedge clk);
        ena   <= 1;
        wea   <= 1;          // Write
        addra <= 4'd3;       // Same Address
        dina  <= 32'hFFFF;   // New Data

        // The BRAM captures this at the NEXT edge.
        // The output 'douta' should update at that same NEXT edge.
        @(posedge clk); 
        
        // We need to wait a tiny bit to check the result *after* the edge update
        // but before the next clock edge.
        #1; 
        $display("[%0t] Immediate Output during Write: %h", $time, douta);
        
        if (douta == 32'hA5A5)      $display("--> PASS: Read-First Behavior Confirmed");
        else if (douta == 32'hFFFF) $display("--> FAIL: Write-First Behavior Detected");
        
        // Clean up
        ena <= 0;
        
        $display("--- Test End ---");
        $finish;
    end

endmodule