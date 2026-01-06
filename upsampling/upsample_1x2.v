    module upsample_1x2 #(parameter length = 12, frac = 8)

    (
        input wire [length-1:0] a,
        input wire [length-1:0] b,
        output wire [length-1:0] p,
        output wire [length-1:0] q
    );
        // int result 8 integer (tapi ambil 4 integer saja) 12 frac (tapi ambil 8 frac saja) 
        wire [(length)-1:0] temp1, temp2;
        
        assign temp1 = ((a >> 1) + (a>>2) + (b>>2));    
        assign temp2 = ((b >> 2) + (b >> 1) + (a >> 2));   

        assign p = temp1;
        assign q = temp2;

    endmodule;

