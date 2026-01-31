module priority_encoder_cell #(
    parameter IDX_WIDTH = 1
)(
    input  wire                 v_hi,   // Valid dari sisi kiri
    input  wire [IDX_WIDTH-1:0] i_hi,   // Index dari sisi kiri
    input  wire                 v_lo,   // Valid dari sisi kanan
    input  wire [IDX_WIDTH-1:0] i_lo,   // Index dari sisi kanan
    output reg                  v_out,  // Valid gabungan
    output reg  [IDX_WIDTH:0]   i_out   // Index gabungan (bertambah 1 bit)
);
    wire [IDX_WIDTH-1:0] i_sel = v_hi ? i_hi : i_lo;
    always @(*) begin
        v_out = v_hi | v_lo;
        i_out = {v_hi, i_sel};
    end
endmodule