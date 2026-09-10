`timescale 1ns/1ps

module tb_mac_array_2x2;

    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;

    logic clk;
    logic rst;
    logic clear;

    logic signed [DATA_W-1:0] a0, a1;
    logic signed [DATA_W-1:0] b0, b1;

    logic signed [ACC_W-1:0] acc00;
    logic signed [ACC_W-1:0] acc01;
    logic signed [ACC_W-1:0] acc10;
    logic signed [ACC_W-1:0] acc11;

    mac_array_2x2 #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .clear(clear),

        .a0(a0),
        .a1(a1),
        .b0(b0),
        .b1(b1),

        .acc00(acc00),
        .acc01(acc01),
        .acc10(acc10),
        .acc11(acc11)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_mac_array_2x2);

        clk   = 0;
        rst   = 1;
        clear = 0;

        a0 = 0;
        a1 = 0;
        b0 = 0;
        b1 = 0;

        // Reset for two cycles
        repeat (2) @(posedge clk);

        rst = 0;

        // --------------------------------------------------
        // Matrices:
        //
        // A = [ 1  2 ]
        //     [ 3  4 ]
        //
        // B = [ 5  6 ]
        //     [ 7  8 ]
        //
        // Expected:
        //
        // C = A*B
        //
        // C00 = 1*5 + 2*7 = 19
        // C01 = 1*6 + 2*8 = 22
        // C10 = 3*5 + 4*7 = 43
        // C11 = 3*6 + 4*8 = 50
        // --------------------------------------------------

        // Cycle 0
        @(negedge clk);
        a0 = 1;   // A00
        a1 = 0;

        b0 = 5;   // B00
        b1 = 0;

        // Cycle 1
        @(negedge clk);
        a0 = 2;   // A01
        a1 = 3;   // A10

        b0 = 7;   // B10
        b1 = 6;   // B01

        // Cycle 2
        @(negedge clk);
        a0 = 0;
        a1 = 4;   // A11

        b0 = 0;
        b1 = 8;   // B11

        // Cycle 3
        @(negedge clk);
        a0 = 0;
        a1 = 0;
        b0 = 0;
        b1 = 0;

        // Need another clock so final values propagate
        repeat (2) @(posedge clk);
        #1;

        $display("--------------------------------");
        $display("acc00 = %0d (expected 19)", acc00);
        $display("acc01 = %0d (expected 22)", acc01);
        $display("acc10 = %0d (expected 43)", acc10);
        $display("acc11 = %0d (expected 50)", acc11);
        $display("--------------------------------");

        if (acc00 !== 19) begin
            $error("acc00 incorrect");
        end

        if (acc01 !== 22) begin
            $error("acc01 incorrect");
        end

        if (acc10 !== 43) begin
            $error("acc10 incorrect");
        end

        if (acc11 !== 50) begin
            $error("acc11 incorrect");
        end

        if (
            acc00 === 19 &&
            acc01 === 22 &&
            acc10 === 43 &&
            acc11 === 50
        ) begin
            $display("PASS: 2x2 matrix multiplication correct");
        end else begin
            $fatal("FAIL: 2x2 matrix multiplication incorrect");
        end

        $finish;
    end

endmodule
