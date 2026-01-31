`timescale 1ns/1ps

module shift_amt_gen #(
    parameter N_MAX = 256,
    parameter WIDTH_MAC_IN  = 48,
    parameter FRAC_BITS_IN  = 16,
    parameter WIDTH_MAC_OUT_SHIFTED = 96
)(
    input  wire clk,
    input  wire rst,

    input  wire [$clog2($clog2(N_MAX+1))-1:0]   lead_zero_N,
    input  wire [$clog2(WIDTH_MAC_IN)-1:0]      lead_zero_var,

    input  wire [2:0] state,

    output reg  [$clog2(WIDTH_MAC_OUT_SHIFTED)-1:0] shift_ra_amt,
    output reg  [$clog2(WIDTH_MAC_IN)-1:0]          shift_l_amt
);
    localparam WIDTH_N = $clog2(N_MAX+1);
    localparam INVSQRT_SHIFT_IN   = WIDTH_MAC_IN - 2;
    localparam INVSQRT_SHIFT_OUT  = ((2*WIDTH_MAC_IN) - (3*FRAC_BITS_IN) - 6) >> 1;

    always @(posedge clk) begin
        if (rst) begin
            shift_ra_amt <= 0;
            shift_l_amt  <= 0;
        end else begin
            case (state)
                3'b001:
                    begin
                        shift_ra_amt <= {{($clog2(WIDTH_MAC_OUT_SHIFTED)-$clog2(WIDTH_N)-1){1'b0}}, lead_zero_N, 1'b0};
                        shift_l_amt  <= 0;
                    end
                3'b010:
                    begin
                        shift_ra_amt <= {{($clog2(WIDTH_MAC_OUT_SHIFTED)-$clog2(WIDTH_N)-1){1'b0}}, lead_zero_N, 1'b0};
                        shift_l_amt  <= 0;
                    end
                3'b011:
                    begin
                        shift_ra_amt <= INVSQRT_SHIFT_OUT + {1'b0, lead_zero_var[$clog2(WIDTH_MAC_IN)-1:1]};
                        shift_l_amt  <= INVSQRT_SHIFT_IN - lead_zero_var; 
                    end
                default:
                    begin
                        shift_ra_amt <= 0;
                        shift_l_amt  <= 0;
                    end
            endcase
        end
    end
endmodule