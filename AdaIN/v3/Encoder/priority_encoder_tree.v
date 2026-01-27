module priority_encoder_tree #(
    parameter WIDTH = 48
)(
    input  wire [WIDTH-1:0]            in,
    output wire                        valid,
    output wire [($clog2(WIDTH)-1):0] out
);
    localparam stages    = $clog2(WIDTH);
    localparam EXT_WIDTH = 1 << stages; 

    wire [EXT_WIDTH-1:0] in_ext;
    assign in_ext = { {(EXT_WIDTH-WIDTH){1'b0}}, in };

    genvar s, b;
    generate
        for (s = 1; s <= stages; s = s + 1) begin : stage_loop
            localparam integer CURR_BLOCKS = EXT_WIDTH >> s;
            
            wire [CURR_BLOCKS-1:0] v_s;
            wire [s-1:0]           i_s [0:CURR_BLOCKS-1];

            for (b = 0; b < CURR_BLOCKS; b = b + 1) begin : block_loop
                if (s == 1) begin : base_stage
                    assign v_s[b] = in_ext[2*b+1] | in_ext[2*b];
                    assign i_s[b] = in_ext[2*b+1]; 
                end else begin : sub_stages
                    priority_encoder_cell #(
                        .IDX_WIDTH(s-1)
                    ) cell_inst (
                        .v_hi (stage_loop[s-1].v_s[2*b+1]), 
                        .i_hi (stage_loop[s-1].i_s[2*b+1]),
                        .v_lo (stage_loop[s-1].v_s[2*b]),   
                        .i_lo (stage_loop[s-1].i_s[2*b]),
                        .v_out(v_s[b]),
                        .i_out(i_s[b])
                    );
                end
            end
        end
    endgenerate

    assign valid = stage_loop[stages].v_s[0];
    assign out   = stage_loop[stages].i_s[0];
endmodule