`timescale 1ns/1ps

module shift_amt_gen #(
    parameter N_MAX = 128,
    parameter MAX_SHIFT_RA1 = 14,
    parameter MAX_SHIFT_RA2 = 45,
    parameter MAX_SHIFT_L   = 46,

    parameter WIDTH_MAC_IN  = 48,
    parameter FRAC_BITS_IN  = 16
)(
    input  wire clk,
    input  wire rst,

    input  wire [$clog2($clog2(N_MAX+1))-1:0]   lead_zero_N,
    input  wire [$clog2(WIDTH_MAC_IN)-1:0]      lead_zero_var,

    input  wire [2:0] state,
    input  wire [1:0] l_count,

    output reg  [$clog2(MAX_SHIFT_RA1+1)-1:0] shift_ra1_amt,
    output reg  [$clog2(MAX_SHIFT_RA2+1)-1:0] shift_ra2_amt,
    output reg  [$clog2(MAX_SHIFT_L+1)-1:0]   shift_l_amt
);
    localparam WIDTH_N = $clog2(N_MAX+1);
    localparam INVSQRT_SHIFT_IN   = WIDTH_MAC_IN - 2;
    localparam INVSQRT_SHIFT_OUT  = ((2*WIDTH_MAC_IN) - (3*FRAC_BITS_IN) - 6) >> 1;

    always @(*) begin
        shift_l_amt   <= INVSQRT_SHIFT_IN - lead_zero_var;
    end
    
    always @(posedge clk) begin
        if (rst) begin
            shift_ra1_amt <= 0;
            shift_ra2_amt <= 0;
        end else begin
            shift_ra1_amt <= {lead_zero_N, 1'b0};
            shift_ra2_amt <= 0;
            case (state)
                3'b010: begin
                    if (l_count == 2) begin
                        shift_ra2_amt <= {{($clog2(MAX_SHIFT_RA2+1)-$clog2(WIDTH_N)-1){1'b0}}, lead_zero_N, 1'b0};
                    end 
                end
                
                3'b011: begin
                    shift_ra2_amt <= INVSQRT_SHIFT_OUT + {1'b0, lead_zero_var[$clog2(WIDTH_MAC_IN)-1:1]};
                end
            endcase
        end
    end
endmodule