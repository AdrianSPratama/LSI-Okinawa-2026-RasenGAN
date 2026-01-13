`timescale 1ns / 1ps

module kernel_BRAM_datapath #(
    parameter KERNEL_WIDTH = 16 
) (
    // Controls
    input wire clk,
    input wire ena_kernel_BRAM, wea_kernel_BRAM,
    input wire enb_kernel_BRAM,

    // Address input
    input wire [7:0] kernel_BRAM_addra,
    input wire [7:0] kernel_BRAM_addrb,
    
    // Data
    input wire [143:0] kernel_BRAM_dina,
    output wire [143:0] kernel_BRAM_doutb
);

true_dual_port_bram #(
    .RAM_WIDTH(KERNEL_WIDTH*9),
    .RAM_DEPTH(256) // Max 256 channel
) kernel_BRAM (
    // Port A
    .clka(clk),   // Clock A
    .ena(ena_kernel_BRAM),    // Enable A (Active High)
    .wea(wea_kernel_BRAM),    // Write Enable A (Active High)
    .addra(kernel_BRAM_addra),  // Address A
    .dina(kernel_BRAM_dina),   // Data In A 
    .douta(),  // Data Out A not used

    // Port B
    .clkb(clk),   // Clock B
    .enb(enb_kernel_BRAM),    // Enable B (Active High)
    .web(1'b0),    // Write Enable B (Active High) not used
    .addrb(kernel_BRAM_addrb),  // Address B
    .dinb(),   // Data In B not used
    .doutb(kernel_BRAM_doutb)   // Data Out B
);

endmodule