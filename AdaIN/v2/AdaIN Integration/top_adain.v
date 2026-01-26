`timescale 1ns/1ps

module top_adain #(
    parameter WIDTH_IN      = 48,
    parameter FRAC_BITS_IN  = 16,

    parameter WIDTH_OUT     = 16,
    parameter FRAC_BITS_OUT = 8,

    parameter N_MAX         = 128
)(
    input  wire clk,
    input  wire rst, 
    input  wire en,
    
    input  wire [1:0] start,     
     
    input  wire [$clog2(N_MAX+1)-1:0] N,       

    input  wire [WIDTH_IN-1:0]  in,
    input  wire [WIDTH_IN-1:0]  ys,
    input  wire [WIDTH_IN-1:0]  yb,

    output wire [WIDTH_OUT-1:0] out,
    output wire [1:0]           done
);

    // --- Localparams ---
    localparam WIDTH_N       = $clog2(N_MAX+1);
    localparam WIDTH_ACC     = WIDTH_IN + 2*$clog2(N_MAX);
    localparam WIDTH_MAC_IN  = WIDTH_IN;
    localparam WIDTH_MAC_OUT = 2 * (WIDTH_MAC_IN + $clog2(N_MAX));

    localparam MAX_SHIFT_L   = WIDTH_MAC_IN - 2;
    localparam MAX_SHIFT_RA1 = 2 * $clog2(N_MAX);
    localparam MAX_SHIFT_RA2 = ((3*WIDTH_MAC_IN) - (3*FRAC_BITS_IN) - 6) >> 1;

    // --- Wires ---
    // Control & Selectors
    wire [2:0] state;
    wire [1:0] l_count;
    wire [1:0] multiplicand_sel, offset_sel;
    wire [2:0] multiplier_sel;
    wire       in_sel, add2_sel;
    wire       rst_acc1;
    wire       variance_en, inv_sigma_en, B1_en, B0_en, out_en;

    // Data Path Wires
    wire [WIDTH_IN-1:0]      in_selected, in_registered;
    wire [WIDTH_ACC-1:0]     acc1, acc1_shifted;
    wire [WIDTH_MAC_OUT-1:0] acc2, acc2_shifted, add2_selected;
    
    wire [WIDTH_MAC_IN-1:0]  multiplicand, multiplier, offset;
    wire [WIDTH_MAC_IN-1:0]  multiplicand_selected, multiplier_selected, offset_selected;

    // Intermediate Logic Wires
    wire [WIDTH_MAC_IN-1:0]  mean = acc1_shifted[WIDTH_MAC_IN-1:0];
    wire [WIDTH_MAC_IN-1:0]  min_mean = -mean;
    wire [WIDTH_MAC_IN-1:0]  var, inv_sigma, A1, A0, B1, B0, var_shifted;

    // Shifter Amts
    wire [$clog2(WIDTH_N)-1:0]         lead_zero_N;
    wire [$clog2(WIDTH_MAC_IN)-1:0]    lead_zero_var;
    wire [$clog2(MAX_SHIFT_RA1+1)-1:0] shift_ra1_amt;
    wire [$clog2(MAX_SHIFT_RA2+1)-1:0] shift_ra2_amt;
    wire [$clog2(MAX_SHIFT_L+1)-1:0]   shift_l_amt;

    // --- Concatenations (Sel 0 = LSB/Paling Kanan) ---
    wire [2*WIDTH_IN-1:0]       in_mux_input        = {in, {WIDTH_IN{1'b0}}};
    wire [4*WIDTH_MAC_IN-1:0]   in_mux_multiplicand = {inv_sigma, var_shifted, min_mean, in_registered};
    wire [5*WIDTH_MAC_IN-1:0]   in_mux_multiplier   = {B1, ys, A1, mean, in_registered};
    wire [3*WIDTH_MAC_IN-1:0]   in_mux_offset       = {B0, yb, A0};
    wire [2*WIDTH_MAC_OUT-1:0]  in_mux_add2         = { 
        acc2_shifted,
        {{(WIDTH_MAC_OUT-WIDTH_MAC_IN-FRAC_BITS_IN){offset[WIDTH_MAC_IN-1]}}, 
         offset, 
         {FRAC_BITS_IN{1'b0}}}
    };

// Instances
// Control Unit
    cu_adain #(
        .N_MAX(N_MAX)
    ) control_unit (
        .clk(clk),
        .rst(rst),
        .en(en),
        .start(start),
        .N(N),
        .state(state),
        .l_count(l_count),
        .in_sel(in_sel),
        .multiplicand_sel(multiplicand_sel),
        .multiplier_sel(multiplier_sel),
        .offset_sel(offset_sel),
        .add2_sel(add2_sel),
        .rst_acc1(rst_acc1),
        .variance_en(variance_en),
        .inv_sigma_en(inv_sigma_en),
        .B1_en(B1_en),
        .B0_en(B0_en),
        .out_en(out_en),
        .done(done)
    );

// Arithmetic Units
    seq_adder #(
        .WIDTH(WIDTH_ACC)
    ) accumulator (
        .clk(clk),
        .rst(rst_acc1), 
        .en(en),
        .in1({{(WIDTH_ACC-WIDTH_MAC_IN){in_registered[WIDTH_MAC_IN-1]}}, in_registered}),
        .in2(acc1),
        .out(acc1)
    );

    seq_mult_add #(
        .WIDTH_IN(WIDTH_MAC_IN),
        .WIDTH_OUT(WIDTH_MAC_OUT)
    ) mac_unit (
        .clk(clk),
        .rst(rst),
        .en(en),
        .multiplicand(multiplicand),
        .multiplier(multiplier),
        .offset(add2_selected),
        .out(acc2)
    );

// MUXes
    mux_nto1 #(
        .N(2),
        .WIDTH(WIDTH_IN)
    ) mux_input (
        .sel(in_sel),
        .in(in_mux_input),
        .out(in_selected)
    );
    
    mux_nto1 #(
        .N(4),
        .WIDTH(WIDTH_MAC_IN)
    ) mux_multiplicand (
        .sel(multiplicand_sel),
        .in(in_mux_multiplicand),
        .out(multiplicand_selected)
    );

    mux_nto1 #(
        .N(5),
        .WIDTH(WIDTH_MAC_IN)
    ) mux_multiplier (
        .sel(multiplier_sel),
        .in(in_mux_multiplier),
        .out(multiplier_selected)
    );

    mux_nto1 #(
        .N(3),
        .WIDTH(WIDTH_MAC_IN)
    ) mux_offset (
        .sel(offset_sel),
        .in(in_mux_offset),
        .out(offset_selected)
    );

    mux_nto1 #(
        .N(2),
        .WIDTH(WIDTH_MAC_OUT)
    ) mux_add2 (
        .sel(add2_sel),
        .in(in_mux_add2),
        .out(add2_selected)
    );

// Priority Encoders
    priority_encoder_lin #(
        .WIDTH(WIDTH_N)
    ) priority_encoder_N (
        .in(N),
        .out(lead_zero_N)
    );

    priority_encoder_lin #(
        .WIDTH(WIDTH_MAC_IN)
    ) priority_encoder_var (
        .in(var),
        .out(lead_zero_var)
    );

// Shift Amount Generator
    shift_amt_gen #(
        .N_MAX(N_MAX),
        .WIDTH_MAC_IN(WIDTH_MAC_IN),
        .FRAC_BITS_IN(FRAC_BITS_IN)
    ) shift_amt_generator (
        .clk(clk),
        .rst(rst),
        .en(en),
        .lead_zero_N(lead_zero_N),
        .lead_zero_var(lead_zero_var),
        .state(state),
        .l_count(l_count),
        .shift_ra1_amt(shift_ra1_amt),
        .shift_ra2_amt(shift_ra2_amt),
        .shift_l_amt(shift_l_amt)
    );

// Shifters
    shifter_ra #(
        .WIDTH(WIDTH_ACC),
        .MAX_SHIFT(MAX_SHIFT_RA1)
    ) shifter_ra1 (
        .in(acc1),
        .shift_amt(shift_ra1_amt),
        .out(acc1_shifted)
    );

    shifter_ra #(
        .WIDTH(WIDTH_MAC_OUT),
        .MAX_SHIFT(MAX_SHIFT_RA2)
    ) shifter_ra2 (
        .in(acc2),
        .shift_amt(shift_ra2_amt),
        .out(acc2_shifted)
    );

    shifter_l_tree #(
        .WIDTH(WIDTH_MAC_IN),
        .MAX_SHIFT(MAX_SHIFT_L)
    ) shifter_l_unit (
        .in(var),
        .shift_amt(shift_l_amt),
        .out(var_shifted)
    );

// Inverse Square Root LUT
    invsqrt_lin_lut #(
        .WIDTH(WIDTH_MAC_IN),
        .FRAC_BITS(FRAC_BITS_IN)
    ) invsqrt_linearization_lut (
        .idx({lead_zero_var[0], var_shifted[WIDTH_MAC_IN-3:WIDTH_MAC_IN-4]}),
        .A0(A0),
        .A1(A1)
    );

// Registers
    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) in_reg (
        .clk(clk),
        .rst(rst),
        .en(en),
        .in(in_selected),
        .out(in_registered)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) multiplicand_reg (
        .clk(clk),
        .rst(rst),
        .en(en),
        .in(multiplicand_selected),
        .out(multiplicand)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) multiplier_reg (
        .clk(clk),
        .rst(rst),
        .en(en),
        .in(multiplier_selected),
        .out(multiplier)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) offset_reg (
        .clk(clk),
        .rst(rst),
        .en(en),
        .in(offset_selected),
        .out(offset)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) variance_reg (
        .clk(clk),
        .rst(rst),
        .en(variance_en & en),
        .in(acc2_shifted[WIDTH_MAC_IN+FRAC_BITS_IN-1:FRAC_BITS_IN]),
        .out(var)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) inv_sigma_reg (
        .clk(clk),
        .rst(rst),
        .en(inv_sigma_en & en),
        .in(acc2_shifted[WIDTH_MAC_IN+FRAC_BITS_IN-1:FRAC_BITS_IN]),
        .out(inv_sigma)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) B1_reg (
        .clk(clk),
        .rst(rst),
        .en(B1_en & en),
        .in(acc2_shifted[WIDTH_MAC_IN+FRAC_BITS_IN-1:FRAC_BITS_IN]),
        .out(B1)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_MAC_IN)
    ) B0_reg (
        .clk(clk),
        .rst(rst),
        .en(B0_en & en),
        .in(acc2_shifted[WIDTH_MAC_IN+FRAC_BITS_IN-1:FRAC_BITS_IN]),
        .out(B0)
    );

    reg_sync_rst #(
        .WIDTH(WIDTH_OUT)
    ) out_reg (
        .clk(clk),
        .rst(rst),
        .en(out_en & en),
        .in(acc2_shifted[WIDTH_OUT+((2*FRAC_BITS_IN)-FRAC_BITS_OUT)-1:((2*FRAC_BITS_IN)-FRAC_BITS_OUT)]),
        .out(out)
    );
endmodule