`timescale 1ns/1ps

module top_adain #(
    parameter WIDTH_IN      = 48,
    parameter FRAC_BITS_IN  = 16,

    parameter WIDTH_OUT     = 16,
    parameter FRAC_BITS_OUT = 8,

    parameter N_MAX         = 256
)(
    input  wire clk,
    input  wire rst,
    input  wire [1:0] start,      
    input  wire [$clog2(N_MAX+1)-1:0] N,      

    input  wire [WIDTH_IN-1:0]  in,
    input  wire [WIDTH_IN-1:0]  ys,
    input  wire [WIDTH_IN-1:0]  yb,

    output wire [WIDTH_OUT-1:0] out,
    output wire [1:0]           done
);
    localparam WIDTH_N = $clog2(N_MAX+1);

    localparam WIDTH_MAC_IN  = WIDTH_IN;
    localparam WIDTH_MAC_OUT = 2 * (WIDTH_MAC_IN + $clog2(N_MAX));
    localparam WIDTH_MAC_OUT_SHIFTED = WIDTH_MAC_OUT - FRAC_BITS_IN;

    localparam [WIDTH_MAC_IN-1:0] ONE_IN = ({{(WIDTH_MAC_IN-1){1'b0}}, 1'b1} << FRAC_BITS_IN);

// Wires
    // MAC Wires
    wire [WIDTH_MAC_IN-1:0] multiplicand_selected;
    wire [WIDTH_MAC_IN-1:0] multiplier_selected;
    wire [WIDTH_MAC_IN-1:0] offset_selected;

    wire [WIDTH_MAC_IN-1:0] multiplicand;
    wire [WIDTH_MAC_IN-1:0] multiplier;
    wire [WIDTH_MAC_IN-1:0] offset;

    wire [WIDTH_MAC_OUT-1:0] acc;

    // Shifter Wires
    wire [$clog2(WIDTH_N)-1:0]      lead_zero_N;
    wire [$clog2(WIDTH_MAC_IN)-1:0] lead_zero_var;

    wire [$clog2(WIDTH_MAC_OUT_SHIFTED)-1:0] shift_ra_amt;
    wire [WIDTH_MAC_OUT_SHIFTED-1:0]         shift_ra_out;

    wire [$clog2(WIDTH_MAC_IN)-1:0] shift_l_amt;
    wire [WIDTH_MAC_IN-1:0]         shifted_var;

    // Output Wires
    wire [WIDTH_MAC_IN-1:0] mean;
    wire [WIDTH_MAC_IN-1:0] deviance = in - mean;
    wire [WIDTH_MAC_IN-1:0] variance;
    wire [WIDTH_MAC_IN-1:0] inv_sigma;
    wire [WIDTH_MAC_IN-1:0] A1; 
    wire [WIDTH_MAC_IN-1:0] A0; 
    wire [WIDTH_MAC_IN-1:0] B1;
    wire [WIDTH_MAC_IN-1:0] min_B1 = -B1;
    wire [WIDTH_MAC_IN-1:0] B0;
    
    
    // Control signals
    wire [2:0] state;
    wire input_mac_en;
    wire mean_en;
    wire variance_en;
    wire inv_sigma_en;
    wire B1_en;
    wire B0_en;
    wire out_en;
    wire rst_acc;


// Control Unit

// MAC
    mux_8to1 #(
        .WIDTH(WIDTH_MAC_IN)
    ) mux_multiplicand (                                        
        .sel(state),
        .in0({(WIDTH_MAC_IN){1'b0}}),
        .in1(in),
        .in2(deviance),
        .in3(shifted_var),
        .in4(ys),
        .in5(mean),
        .in6(in),
        .in7({(WIDTH_MAC_IN){1'b0}}),
        .out(multiplicand_selected)
    );

    mux_8to1 #(
        .WIDTH(WIDTH_MAC_IN)
    ) mux_multiplier (
        .sel(state),
        .in0({(WIDTH_MAC_IN){1'b0}}),
        .in1(ONE_IN),
        .in2(deviance),
        .in3(A1),
        .in4(inv_sigma),
        .in5(min_B1),
        .in6(B1),
        .in7({(WIDTH_MAC_IN){1'b0}}),
        .out(multiplier_selected)
    );

    mux_8to1 #(
        .WIDTH(WIDTH_MAC_IN)
    ) mux_offset (
        .sel(state),
        .in0({(WIDTH_MAC_IN){1'b0}}),
        .in1({(WIDTH_MAC_IN){1'b0}}),
        .in2({(WIDTH_MAC_IN){1'b0}}),
        .in3(A0),
        .in4({(WIDTH_MAC_IN){1'b0}}),
        .in5(yb),
        .in6(B0),
        .in7({(WIDTH_MAC_IN){1'b0}}),
        .out(offset_selected)
    );

    mac_adain #(
        .WIDTH_IN(WIDTH_MAC_IN),
        .WIDTH_OUT(WIDTH_MAC_OUT)
    ) mac_unit (
        .clk(clk),
        .rst(rst),
        .rst_acc(rst_acc),

        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .offset(offset),
        .acc(acc)
    );

// Inv sqrt LUT
    invsqrt_lin_lut #(
        .WIDTH(WIDTH_MAC_IN),
        .FRAC_BITS(FRAC_BITS_IN)
    ) invsqrt_linearization_lut (
        .idx({lead_zero_var[0], shifted_var[WIDTH_MAC_IN-3:WIDTH_MAC_IN-4]}),
        .A0(A0),
        .A1(A1)
    );

// Shifters
    priority_encoder #(
        .WIDTH(WIDTH_N)
    ) priority_encoder_N (
        .in(N),
        .out(lead_zero_N)
    );

    priority_encoder #(
        .WIDTH(WIDTH_MAC_IN)
    ) priority_encoder_var (
        .in(variance),
        .out(lead_zero_var)
    );

    shift_amt_gen #(
        .N_MAX(N_MAX),
        .WIDTH_MAC_IN(WIDTH_MAC_IN),
        .FRAC_BITS_IN(FRAC_BITS_IN),
        .WIDTH_MAC_OUT_SHIFTED(WIDTH_MAC_OUT_SHIFTED)
    ) shift_amt_generator (
        .clk(clk),
        .rst(rst),
        .lead_zero_N(lead_zero_N),
        .lead_zero_var(lead_zero_var),
        .state(state),
        .shift_ra_amt(shift_ra_amt),
        .shift_l_amt(shift_l_amt)
    );

    shift_ra #(
        .WIDTH(WIDTH_MAC_OUT_SHIFTED)
    ) shifter_ra (
        .in(acc[WIDTH_MAC_OUT-1:FRAC_BITS_IN]),
        .shift_amt(shift_ra_amt),
        .out(shift_ra_out)
    );

    shift_l #(
        .WIDTH(WIDTH_MAC_IN)
    ) shifter_l (
        .in(variance),
        .shift_amt(shift_l_amt),
        .out(shifted_var)
    );

// Registers
    // Input MAC
    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) multiplicand_reg (
        .clk(clk),
        .rst(rst),
        .en(input_mac_en),
        .in(multiplicand_selected),
        .out(multiplicand)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) multiplier_reg (
        .clk(clk),
        .rst(rst),
        .en(input_mac_en),
        .in(multiplier_selected),
        .out(multiplier)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) offset_reg (
        .clk(clk),
        .rst(rst),
        .en(input_mac_en),
        .in(offset_selected),
        .out(offset)
    );

    // Output MAC
    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) mean_reg (
        .clk(clk),
        .rst(rst),
        .en(mean_en),
        .in(shift_ra_out[WIDTH_MAC_IN-1:0]),
        .out(mean)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) variance_reg (
        .clk(clk),
        .rst(rst),
        .en(variance_en),
        .in(shift_ra_out[WIDTH_MAC_IN-1:0]),
        .out(variance)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) inv_sigma_reg (
        .clk(clk),
        .rst(rst),
        .en(inv_sigma_en),
        .in(shift_ra_out[WIDTH_MAC_IN-1:0]),
        .out(inv_sigma)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) B1_reg (
        .clk(clk),
        .rst(rst),
        .en(B1_en),
        .in(shift_ra_out[WIDTH_MAC_IN-1:0]),
        .out(B1)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) B0_reg (
        .clk(clk),
        .rst(rst),
        .en(B0_en),
        .in(shift_ra_out[WIDTH_MAC_IN-1:0]),
        .out(B0)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_OUT)
    ) out_reg (
        .clk(clk),
        .rst(rst),
        .en(out_en),
        .in(shift_ra_out[WIDTH_OUT+(FRAC_BITS_IN-FRAC_BITS_OUT)-1:FRAC_BITS_IN-FRAC_BITS_OUT]),
        .out(out)
    );
endmodule