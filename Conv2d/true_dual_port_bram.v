`timescale 1ns / 1ps

module true_dual_port_bram #(
    parameter RAM_WIDTH = 32,                       // Data width (e.g., 32-bit)
    parameter RAM_DEPTH = 1024,                     // Memory depth
    parameter ADDR_WIDTH = $clog2(RAM_DEPTH),       // Auto-calculate Address Width
    parameter INIT_FILE = ""                        // Optional .mem file for initialization
)(
    // Port A
    input wire                    clka,   // Clock A
    input wire                    ena,    // Enable A (Active High)
    input wire                    wea,    // Write Enable A (Active High)
    input wire [ADDR_WIDTH-1:0]   addra,  // Address A
    input wire [RAM_WIDTH-1:0]    dina,   // Data In A 
    output reg [RAM_WIDTH-1:0]    douta,  // Data Out A

    // Port B
    input wire                    clkb,   // Clock B
    input wire                    enb,    // Enable B (Active High)
    input wire                    web,    // Write Enable B (Active High)
    input wire [ADDR_WIDTH-1:0]   addrb,  // Address B
    input wire [RAM_WIDTH-1:0]    dinb,   // Data In B
    output reg [RAM_WIDTH-1:0]    doutb   // Data Out B
);

    // 1. Declare the RAM Array
    // "(* ram_style = "block" *)" hints Vivado to strictly use Block RAM
    (* ram_style = "block" *) reg [RAM_WIDTH-1:0] BRAM [0:RAM_DEPTH-1];

    // 2. Optional: Initialization from file
    // Useful for loading weights or initial data in PYNQ
    generate
        if (INIT_FILE != "") begin: init_bram
            initial begin
                $readmemh(INIT_FILE, BRAM);
            end
        end
    endgenerate

    // 3. Port A Logic
    always @(posedge clka) begin
        if (ena) begin
            if (wea) begin
                BRAM[addra] <= dina;
            end
            // Read-First Mode:
            // If wea is high, douta outputs the OLD data at that address.
            // If wea is low, douta outputs the CURRENT data.
            douta <= BRAM[addra]; 
        end
    end

    // 4. Port B Logic
    always @(posedge clkb) begin
        if (enb) begin
            if (web) begin
                BRAM[addrb] <= dinb;
            end
            doutb <= BRAM[addrb];
        end
    end

endmodule