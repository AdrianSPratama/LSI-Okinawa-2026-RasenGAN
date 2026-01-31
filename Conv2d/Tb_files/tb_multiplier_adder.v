`include "multiplier_adder.v"

`timescale 1ns / 1ps

module tb_multiplier_adder;

    // 1. Parameters
    parameter PIXEL_WIDTH = 16;
    parameter KERNEL_WIDTH = 16;
    parameter RESULT_WIDTH = 48;

    // 2. Inputs (Regs because we drive them in initial block)
    reg signed [PIXEL_WIDTH-1:0] x00, x01, x02;
    reg signed [PIXEL_WIDTH-1:0] x10, x11, x12;
    reg signed [PIXEL_WIDTH-1:0] x20, x21, x22;

    reg signed [KERNEL_WIDTH-1:0] k00, k01, k02;
    reg signed [KERNEL_WIDTH-1:0] k10, k11, k12;
    reg signed [KERNEL_WIDTH-1:0] k20, k21, k22;

    // 3. Outputs (Wires)
    wire signed [RESULT_WIDTH-1:0] result;

    // 4. Instantiate the DUT (Device Under Test)
    multiplier_adder #(
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .KERNEL_WIDTH(KERNEL_WIDTH),
        .RESULT_WIDTH(RESULT_WIDTH)
    ) dut (
        .x00(x00), .x01(x01), .x02(x02),
        .x10(x10), .x11(x11), .x12(x12),
        .x20(x20), .x21(x21), .x22(x22),
        .k00(k00), .k01(k01), .k02(k02),
        .k10(k10), .k11(k11), .k12(k12),
        .k20(k20), .k21(k21), .k22(k22),
        .result(result)
    );

    // 5. Task to simplify driving inputs
    task set_inputs(
        input signed [PIXEL_WIDTH-1:0] v_x, // Set all pixels to this value
        input signed [KERNEL_WIDTH-1:0] v_k  // Set all kernels to this value
    );
    begin
        x00 = v_x; x01 = v_x; x02 = v_x;
        x10 = v_x; x11 = v_x; x12 = v_x;
        x20 = v_x; x21 = v_x; x22 = v_x;
        
        k00 = v_k; k01 = v_k; k02 = v_k;
        k10 = v_k; k11 = v_k; k12 = v_k;
        k20 = v_k; k21 = v_k; k22 = v_k;
    end
    endtask

    // 6. Task to set specific pattern (Identity Kernel)
    task set_identity_kernel;
    begin
        // Reset all to zero first
        k00 = 0; k01 = 0; k02 = 0;
        k10 = 0; k11 = 1; k12 = 0; // Center is 1
        k20 = 0; k21 = 0; k22 = 0;
    end
    endtask

    // 7. Test Vectors
    initial begin
        $display("---------------------------------------------------");
        $display("Starting Testbench for Multiplier Adder (Convolution)");
        $display("---------------------------------------------------");

        // Case 1: Simple Accumulation (All 1s)
        // 9 pixels * 1 * 1 = 9 expected
        set_inputs(16'd1, 16'd1);
        #10;
        $display("Case 1: All 1s.      Result: %0d (Expected: 9)", result);
        if (result !== 9) $display("--> ERROR!");

        // Case 2: Zero Kernel (Result should be 0)
        set_inputs(16'd100, 16'd0);
        #10;
        $display("Case 2: Zero Kernel. Result: %0d (Expected: 0)", result);
        if (result !== 0) $display("--> ERROR!");

        // Case 3: Identity Kernel (Only center pixel passes)
        set_inputs(16'd50, 16'd0); // Set pixels to 50, kernel to 0
        set_identity_kernel();     // Set center kernel to 1
        x11 = 16'd123;             // Set center pixel to specific value
        #10;
        $display("Case 3: Identity.    Result: %0d (Expected: 123)", result);
        if (result !== 123) $display("--> ERROR!");

        // Case 4: Negative Numbers (Signed Arithmetic)
        // Pixels = -2, Kernel = 5. Result = 9 * (-2 * 5) = -90
        set_inputs(-16'sd2, 16'sd5); 
        #10;
        $display("Case 4: Signed Math. Result: %0d (Expected: -90)", result);
        if (result !== -90) $display("--> ERROR!");

        // Case 5: Manual Specific Calculation
        // Top row 1s, Middle row 2s, Bottom row 3s
        // Kernel always 1
        set_inputs(16'd0, 16'd1);
        x00=1; x01=1; x02=1;
        x10=2; x11=2; x12=2;
        x20=3; x21=3; x22=3;
        // Sum = (1*3) + (2*3) + (3*3) = 3 + 6 + 9 = 18
        #10;
        $display("Case 5: Row Sums.    Result: %0d (Expected: 18)", result);
        if (result !== 18) $display("--> ERROR!");

        $display("---------------------------------------------------");
        $display("Testbench Complete.");
        $display("---------------------------------------------------");
        $finish;
    end

endmodule