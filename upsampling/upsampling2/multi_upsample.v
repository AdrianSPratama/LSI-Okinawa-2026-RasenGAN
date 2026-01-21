`include "upsample_1x2.v"
`include "upsample_2x2.v"

module multi_upsample #(parameter length = 16)
(
    input wire [length-1:0] a,
    input wire [length-1:0] b,
    input wire [length-1:0] c,
    input wire [length-1:0] d,

    input wire [3:0] write_mode,

    output wire [length-1:0] out1,
    output wire [length-1:0] out2,
    output wire [length-1:0] out3,
    output wire [length-1:0] out4,

    output reg [length-1:0] out5,
    output reg [length-1:0] out6,
    output reg [length-1:0] out7,
    output reg [length-1:0] out8,
    output reg [length-1:0] out9

);

    wire [length-1:0] p,q,r,s, k,l,m,n;

    upsample_2x2 #(
        .length(length)
    ) uut (
        .a(a),
        .b(b),
        .c(c),
        .d(d),

        .p(p),
        .q(q), 
        .r(r),
        .s(s),

        .w(out1),
        .x(out2),
        .y(out3),
        .z(out4)
    );


    upsample_1x2 #(
        .length(length)
    ) uut2 (
        .a(a),
        .b(c),

        .p(k),
        .q(l)
    );

    upsample_1x2 #(
        .length(length)
    ) uut3 (
        .a(b),
        .b(d),

        .p(m),
        .q(n)
    );


    always @(*) begin

        out5 = r;
        out6 = s;

        out7 = m;
        out8 = n;

        case (write_mode) 

        (4'b0000) : begin
            out9 = d;
        end


        // (4'b0001) : begin
        //     out5 = p;
        //     out6 = q;
        // end

        (4'b0010) : begin
            out9 = c;
        end

        // (4'b0011) : begin
        //     out7 = k;
        //     out8 = l;
        // end

        (4'b0101) : begin
            out7 = k;
            out8 = l;
        end

        (4'b0110) : begin
            out9 = b;
        end

        (4'b0111) : begin
            out5 = p;
            out6 = q;
        end

        (4'b1000) : begin
            out9 = a;
        end

        default : begin
        //     out5 = 0;
        //     out6 = 0;
        //     out7 = 0;
        //     out8 = 0;
       
        end
        endcase

        



        // out9 = (write_mode == 4'b0000) ? d : c;

    end


endmodule;