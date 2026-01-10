module counter #(
    parameter BITWIDTH = 5
) (
    input wire enable, reset, clk,
    output reg [BITWIDTH-1:0] counter_out
);
    
always @(posedge clk) begin
    if(!reset) begin
        counter_out <= 0;
    end
    else begin
        if (enable) begin
            counter_out <= counter_out + 1;
        end
        else begin
            counter_out <= counter_out;
        end
    end
end

endmodule