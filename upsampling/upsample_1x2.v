    module upsample_1x2 #(parameter length = 12, frac = 8)

    (
        input wire [length-1:0] a,
        input wire [length-1:0] b,
        output wire [length-1:0] p,
        output wire [length-1:0] q
    );
        // int result 8 integer (tapi ambil 4 integer saja) 12 frac (tapi ambil 8 frac saja) 
        wire [(length*2)-1:0] temp1, temp2;
        
        assign temp1 = (a * (12'b000011000000) + b * (12'b000001000000));    
        assign temp2 = (a * (12'b000001000000) + b * (12'b000011000000));   

        assign p = temp1[ (length*2) - 5 : frac ];
        assign q = temp2[ (length*2) - 5 : frac ];

    endmodule;

