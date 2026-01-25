`timescale 1ns/1ps

module invsqrt_lin_lut #(
    parameter WIDTH      = 48,
    parameter FRAC_BITS  = 16
)(
    input  wire [2:0]       idx,
    output wire [WIDTH-1:0] A0,
    output wire [WIDTH-1:0] A1
);
    localparam [511:0] MASTER_A0_PACKED = {
        64'h2D8368E900489C00, 
        64'h29172F7242B5DC00, 
        64'h25C1C2A865665400, 
        64'h23203A67C51C9C00,
        64'h202ECA775B06C000, 
        64'h1D0E2FF1E0B6C900, 
        64'h1AB2B986B08CCF00, 
        64'h18D6772B01215000 
    };

    localparam [511:0] MASTER_A1_PACKED = {
        64'hC9F25C5BFEDD9000, 
        64'hD8197AA4C3E66000, 
        64'hE0FD4769BCBA7000, 
        64'hE700C7FD743E6000,
        64'hD9C74FBC90D43000, 
        64'hE3C93E347EA0E000, 
        64'hEA1279FCFF10D000, 
        64'hEE5311A9FDBD6000 
    };

    wire [WIDTH-1:0] LUT_A0 [0:7];
    wire [WIDTH-1:0] LUT_A1 [0:7];

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : GEN_LUT_WIRING
            assign LUT_A0[i] = MASTER_A0_PACKED[(7-i)*64 + 63 : (7-i)*64 + 64 - WIDTH];
            assign LUT_A1[i] = {
                {(WIDTH-FRAC_BITS){MASTER_A1_PACKED[(7-i)*64 + 63]}}, 
                MASTER_A1_PACKED[(7-i)*64 + 63 : (7-i)*64 + 64 - FRAC_BITS]
            };           
        end
    endgenerate

    assign A0 = LUT_A0[idx];
    assign A1 = LUT_A1[idx];
endmodule