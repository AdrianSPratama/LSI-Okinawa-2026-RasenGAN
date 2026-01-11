`timescale 1ns / 1ps

module window_reg_3x3 #(
    parameter DATA_WIDTH = 16
) (
    input wire clk,
    input wire Wr_window, Shift_window, Rst_window,
    input wire [DATA_WIDTH-1:0] in_row_n, in_row_n_1, in_row_n_2,
    // Output from every register
    output wire [DATA_WIDTH-1:0] out_window_00, out_window_01, out_window_02,
    output wire [DATA_WIDTH-1:0] out_window_10, out_window_11, out_window_12,
    output wire [DATA_WIDTH-1:0] out_window_20, out_window_21, out_window_22
);

integer i, j;
reg [DATA_WIDTH-1:0] window_reg [0:2][0:2];
always @(posedge clk) begin
    if (!Rst_window) begin
        for (i = 0; i<3; i = i+1) begin
            for (j = 0; j<3; j = j+1) begin
                window_reg[i][j] <= 0;
            end
        end
    end
    else begin
        if (Wr_window && Shift_window) begin
            // Write column 0
            window_reg[0][0] <= in_row_n_2;
            window_reg[1][0] <= in_row_n_1;
            window_reg[2][0] <= in_row_n;

            // Shift to right
            window_reg[0][2] <= window_reg[0][1]; window_reg[0][1] <= window_reg[0][0];
            window_reg[1][2] <= window_reg[1][1]; window_reg[1][1] <= window_reg[1][0];
            window_reg[2][2] <= window_reg[2][1]; window_reg[2][1] <= window_reg[2][0];
        end
        else if (Wr_window && !Shift_window) begin
            // Write column 0
            window_reg[0][0] <= in_row_n_2;
            window_reg[1][0] <= in_row_n_1;
            window_reg[2][0] <= in_row_n;
        end
        else if (!Wr_window && Shift_window) begin
            window_reg[0][2] <= window_reg[0][1]; window_reg[0][1] <= window_reg[0][0];
            window_reg[1][2] <= window_reg[1][1]; window_reg[1][1] <= window_reg[1][0];
            window_reg[2][2] <= window_reg[2][1]; window_reg[2][1] <= window_reg[2][0];
        end
        else begin
            for (i = 0; i<3; i = i+1) begin
                for (j = 0; j<3; j = j+1) begin
                    window_reg[i][j] <= window_reg[i][j];
                end
            end
        end
    end
end

// Assign output
assign out_window_00 = window_reg[0][0];
assign out_window_01 = window_reg[0][1];
assign out_window_02 = window_reg[0][2];
assign out_window_10 = window_reg[1][0];
assign out_window_11 = window_reg[1][1];
assign out_window_12 = window_reg[1][2];
assign out_window_20 = window_reg[2][0];
assign out_window_21 = window_reg[2][1];
assign out_window_22 = window_reg[2][2];

endmodule