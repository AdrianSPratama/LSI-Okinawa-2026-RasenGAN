// `include "upsample_1x2.v"

module upsample_2x2 #(parameter length = 12, frac = 8)
(
    input wire [length-1:0] a,
    input wire [length-1:0] b,
    input wire [length-1:0] c,
    input wire [length-1:0] d,

    output wire [length-1:0] p,
    output wire [length-1:0] q,
    output wire [length-1:0] r,
    output wire [length-1:0] s,


    output wire [length-1:0] w,
    output wire [length-1:0] x,
    output wire [length-1:0] y,
    output wire [length-1:0] z
);

    upsample_1x2 #(length, frac) up1 (
        .a(a),
        .b(b),
        .p(p),
        .q(q)
    );

    upsample_1x2 #(length, frac) up2 (
        .a(c),
        .b(d),
        .p(r),
        .q(s)
    );
    
    upsample_1x2 #(length, frac) up3 (
        .a(p),
        .b(r),
        .p(w),
        .q(y)
    );

    upsample_1x2 #(length, frac) up4 (
        .a(q),
        .b(s),
        .p(x),
        .q(z)
    );

endmodule;