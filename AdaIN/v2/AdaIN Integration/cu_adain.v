`timescale 1ns/1ps

module cu_adain #(
    parameter N_MAX = 128
)(
    input  wire clk,
    input  wire rst,
    input  wire [1:0] start,      
    input  wire [$clog2(N_MAX+1)-1:0] N,

    output reg [2:0]  state,
    output reg [1:0]  l_count, 
    
    output reg [1:0]  multiplicand_sel, 
    output reg [2:0]  multiplier_sel,   
    output reg [1:0]  offset_sel,        
    output reg        add2_sel,          

    output reg        rst_mult,          
    output reg        rst_offset,   
    output reg        rst_acc1,     
    output reg        rst_acc1_in,   
    output reg        rst_acc2,   

    output reg        variance_en,
    output reg        inv_sigma_en,
    output reg        B1_en,
    output reg        B0_en,
    output reg        out_en,

    output reg [1:0]  done
);

    localparam IDLE      = 3'b000;
    localparam CALC_ACC  = 3'b001; 
    localparam CALC_VAR  = 3'b010; 
    localparam CALC_ISIG = 3'b011; 
    localparam CALC_B1   = 3'b100; 
    localparam CALC_B0   = 3'b101; 
    localparam CALC_NORM = 3'b110; 

    reg [$clog2(N_MAX)-1:0] col_count, row_count;
    
    reg [$clog2(N_MAX+1)-1:0] N_1;
    always @(posedge clk) begin
        N_1 <= N - 1;
    end
    
    wire last_col   = (col_count == N_1);
    wire last_row   = (row_count == N_1);
    wire last_flush = (l_count == 3);

// FSM
    always @(posedge clk) begin
        if (rst) begin
            state   <= IDLE;
            done    <= 0;

            col_count   <= 1;
            row_count   <= 0;
            l_count     <= 0;

            variance_en     <= 0;
            inv_sigma_en    <= 0;
            B1_en           <= 0;
            B0_en           <= 0;
            out_en          <= 0;

            multiplicand_sel    <= 0;
            multiplier_sel      <= 0;
            offset_sel          <= 0;
            add2_sel            <= 0;

            rst_mult    <= 1;
            rst_offset  <= 1;
            rst_acc1    <= 1;
            rst_acc1_in <= 1;
            rst_acc2    <= 1;
        end else begin 
            variance_en     <= 0;       
            inv_sigma_en    <= 0;   
            B1_en           <= 0;
            B0_en           <= 0;
            out_en          <= 0;
            
            l_count     <= l_count + 1;
            
            multiplier_sel      <= 0;
            multiplicand_sel    <= 0;
            offset_sel          <= 0;
            add2_sel            <= 0;
            
            rst_mult    <= 0;
            rst_offset  <= 1;
            rst_acc1    <= 0;
            rst_acc2    <= 0;
            case (state)
                IDLE: begin
                    col_count   <= 1;
                    row_count   <= 0;  
                    l_count     <= 0;
                    
                    rst_mult    <= 1;
                    rst_acc1    <= 1;
                    rst_acc2    <= 1;
                    rst_acc1_in <= 0;
                    if (start == 2'b01) begin
                        state   <= CALC_ACC;
                        done    <= 0;

                        rst_mult    <= 0;
                        rst_acc1    <= 0;
                    end else if (start == 2'b10) begin
                        state   <= CALC_NORM;
                        done    <= 0;
                        
                        multiplier_sel  <= 4;

                        rst_mult    <= 0;
                    end
                end

                CALC_ACC: begin 
                    add2_sel    <= 1;
                    if (l_count == 0) begin
                        col_count   <= col_count + 1;
                        l_count     <= 0;
                        if (last_col) begin
                            col_count   <= 0; 
                            row_count   <= row_count + 1;
                            if (last_row) begin
                                l_count     <= l_count + 1;
                            end
                        end
                    end 
                    
                    if (last_col & last_row) begin
                        rst_acc1_in <= 1;
                    end
                    
                    if (last_flush) begin 
                        state   <= CALC_VAR;        
                    end
                end

                CALC_VAR: begin  
                    variance_en     <= 1;  
                    
                    multiplicand_sel    <= 1; 
                    multiplier_sel      <= 1;      
                    add2_sel            <= 1;
                    if (last_flush) begin
                        state   <= CALC_ISIG; 
                    end
                end

                CALC_ISIG: begin
                    inv_sigma_en    <= 1;
        
                    multiplicand_sel    <= 2; 
                    multiplier_sel      <= 2; 
        
                    rst_offset  <= 0;
                    if (last_flush) begin
                        state   <= CALC_B1; 
                    end 
                end

                CALC_B1: begin
                    B1_en           <= 1;

                    multiplicand_sel    <= 3; 
                    multiplier_sel      <= 3; 
                    if (last_flush) begin
                        state   <= CALC_B0;       
                    end 
                end

                CALC_B0: begin
                    B0_en           <= 1;

                    multiplicand_sel    <= 1; 
                    multiplier_sel      <= 4; 
                    offset_sel          <= 1; 

                    rst_offset  <= 0; 
                    if (last_flush) begin 
                        state   <= IDLE;
                        done    <= 1;     
                    end
                end

                CALC_NORM: begin
                    out_en  <= 1;
                    
                    multiplier_sel      <= 4; 
                    offset_sel          <= 2;
                    
                    rst_offset  <= 0;
                    if (last_flush) begin
                        done    <= 2;    
                        
                        col_count   <= col_count + 1;
                        l_count     <= 3;          
                        if (last_col) begin
                            col_count   <= 0;
                            row_count   <= row_count + 1;
                        end 
                    end
                    
                    if (last_col & last_row) begin
                        state   <= IDLE;                                 
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule