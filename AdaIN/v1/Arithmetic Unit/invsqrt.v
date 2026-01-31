module invsqrt #(
    parameter WIDTH = 32, // Total bit (Fixed Point)
    parameter FBITS = 20  // Jumlah bit pecahan (Q12.20)
) (
    input  wire signed [WIDTH-1:0] in, // Q12.20
    output wire signed [WIDTH-1:0] out // Q13.19
);

    // ========================================================================
    // TAHAP 1: GUESS (Analisa Input & Siapkan Koefisien)
    // ========================================================================
    wire [4:0] k; // Posisi index bit '1' (0..30)
    assign k = (in[30]) ? 5'd30 :
               (in[29]) ? 5'd29 :
               (in[28]) ? 5'd28 :
               (in[27]) ? 5'd27 :
               (in[26]) ? 5'd26 :
               (in[25]) ? 5'd25 :
               (in[24]) ? 5'd24 :
               (in[23]) ? 5'd23 :
               (in[22]) ? 5'd22 :
               (in[21]) ? 5'd21 :
               (in[20]) ? 5'd20 :
               (in[19]) ? 5'd19 :
               (in[18]) ? 5'd18 :
               (in[17]) ? 5'd17 :
               (in[16]) ? 5'd16 :
               (in[15]) ? 5'd15 :
               (in[14]) ? 5'd14 :
               (in[13]) ? 5'd13 :
               (in[12]) ? 5'd12 :
               (in[11]) ? 5'd11 :
               (in[10]) ? 5'd10 :
               (in[9])  ? 5'd9  :
               (in[8])  ? 5'd8  :
               (in[7])  ? 5'd7  :
               (in[6])  ? 5'd6  :
               (in[5])  ? 5'd5  :
               (in[4])  ? 5'd4  :
               (in[3])  ? 5'd3  :
               (in[2])  ? 5'd2  :
               (in[1])  ? 5'd1  : 5'd0; // Default ke 0 jika input 0/1
               
    reg [5:0] shift_in;
    assign shift_in <= 30 - k;

    wire [31:0] aligned_in;
    assign aligned_in = in << shift_in; // Q2.30
    
    wire [2:0] lut_index;
    assign lut_index = {k[0], aligned_in[29:28]};

    reg signed [31:0] A0; 
    reg signed [15:0] A1; 
    always @(*) begin
        case (lut_index)    
            // Coba geser kanan 1     
            // A0: Q3.29
            // A1: Q1.15   
            // Genap (k[0]=0) -> Range [1, 2)
            3'b000 : begin A0 = 32'h2D8368E9; A1 = 16'hC9F2; end 
            3'b001 : begin A0 = 32'h29172F72; A1 = 16'hD819; end 
            3'b010 : begin A0 = 32'h25C1C2A8; A1 = 16'hE0FD; end 
            3'b011 : begin A0 = 32'h23203A68; A1 = 16'hE700; end 
            
            // Ganjil (k[0]=1) -> Range [2, 4) -> Perlu dibagi akar 2
            3'b100 : begin A0 = 32'h202ECA77; A1 = 16'hD9C7; end 
            3'b101 : begin A0 = 32'h1D0E2FF2; A1 = 16'hE3C9; end 
            3'b110 : begin A0 = 32'h1AB2B987; A1 = 16'hEA12; end 
            3'b111 : begin A0 = 32'h18D6772B; A1 = 16'hEE53; end 
            default: begin A0 = 0; A1 = 0; end
        endcase
    end

    // ========================================================================
    // TAHAP 2: CALCULATE (Hitung Aproksimasi Linear)
    // ========================================================================
    // Rumus: Y = A0 + (A1 * x_frac)
    

    wire signed [15:0] x_frac;
    assign x_frac = aligned_in[31:16]; // Q2.14


    wire signed [31:0] product;
    assign product = A1 * x_frac;

   
    wire signed [31:0] result_overscaled;
    assign result_overscaled = A0 + product; 
                                            
    // ========================================================================
    // TAHAP 3: SHIFT (Geser Kanan Saja)
    // ========================================================================
    
    wire [4:0] shift_out;
    assign shift_out = k[4:1]; // Sama dengan k / 2 (integer division)

    // Final result
    assign out = result_overscaled >>> shift_out; // Q13.19

endmodule