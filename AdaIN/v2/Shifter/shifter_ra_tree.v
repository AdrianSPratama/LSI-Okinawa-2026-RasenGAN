module shifter_ra_tree #(
    parameter WIDTH     = 48,
    parameter MAX_SHIFT = 15
)(
    input  wire [WIDTH-1:0]                 in,
    input  wire [$clog2(MAX_SHIFT+1)-1:0]   shift_amt,
    output wire [WIDTH-1:0]                 out
);
    localparam stages = $clog2(MAX_SHIFT + 1);

    wire sign_bit = in[WIDTH-1];

    wire [WIDTH-1:0] s_val [0:stages];
    assign s_val[0] = in;

    genvar i;
    generate
        for (i = 0; i < stages; i = i + 1) begin : stage_loop
            localparam SHIFT_DIST = 1 << i;

            wire [WIDTH-1:0] shifted_val;
            assign shifted_val = {{SHIFT_DIST{sign_bit}}, s_val[i][WIDTH-1:SHIFT_DIST]};
            assign s_val[i+1] = (shift_amt[i]) ? shifted_val : s_val[i];
        end
    endgenerate

    assign out = s_val[stages];
endmodule