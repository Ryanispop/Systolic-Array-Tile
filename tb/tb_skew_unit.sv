`timescale 1ns/1ps

module tb_skew_unit;

    localparam int DATA_W = 8;

    logic clk;
    logic rst;
    logic start;

    logic signed [DATA_W-1:0] A00, A01;
    logic signed [DATA_W-1:0] A10, A11;

    logic signed [DATA_W-1:0] B00, B01;
    logic signed [DATA_W-1:0] B10, B11;

    logic signed [DATA_W-1:0] a0, a1;
    logic signed [DATA_W-1:0] b0, b1;

    logic busy;
    logic done;

    skew_unit #(
        .DATA_W(DATA_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),

        .A00(A00),
        .A01(A01),
        .A10(A10),
        .A11(A11),

        .B00(B00),
        .B01(B01),
        .B10(B10),
        .B11(B11),

        .a0(a0),
        .a1(a1),
        .b0(b0),
        .b1(b1),

        .busy(busy),
        .feed_done(done)
    );

    always #5 clk = ~clk;

    task automatic check_outputs(
        input logic signed [DATA_W-1:0] exp_a0,
        input logic signed [DATA_W-1:0] exp_a1,
        input logic signed [DATA_W-1:0] exp_b0,
        input logic signed [DATA_W-1:0] exp_b1
    );
        begin
            #1;

            $display(
                "a0=%0d a1=%0d b0=%0d b1=%0d busy=%0b done=%0b",
                a0, a1, b0, b1, busy, done
            );

            if (a0 !== exp_a0 ||
                a1 !== exp_a1 ||
                b0 !== exp_b0 ||
                b1 !== exp_b1) begin

                $fatal(
                    1,
                    "Mismatch: expected a0=%0d a1=%0d b0=%0d b1=%0d",
                    exp_a0, exp_a1, exp_b0, exp_b1
                );
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_skew_unit);

        clk   = 0;
        rst   = 1;
        start = 0;

        A00 = 1;
        A01 = 2;
        A10 = 3;
        A11 = 4;

        B00 = 5;
        B01 = 6;
        B10 = 7;
        B11 = 8;

        // Reset
        repeat (2) @(posedge clk);
        rst = 0;

        // Start feeder
        @(negedge clk);
        start = 1;

        @(posedge clk);
        #1;

        if (!busy)
            $fatal(1, "busy should be high after start");

        check_outputs(1, 0, 5, 0);

        // Remove start pulse
        @(negedge clk);
        start = 0;

        // Cycle 1
        @(posedge clk);
        check_outputs(2, 3, 7, 6);

        // Cycle 2
        @(posedge clk);
        check_outputs(0, 4, 0, 8);

        // After final feed cycle
        @(posedge clk);
        #1;

        if (busy)
            $fatal(1, "busy should be low after feeding");

        if (!done)
            $fatal(1, "done should pulse after feeding");

        check_outputs(0, 0, 0, 0);

        // done should only stay high for one cycle
        @(posedge clk);
        #1;

        if (done)
            $fatal(1, "done should only pulse for one cycle");

        $display("All skew_unit tests passed.");
        $finish;
    end

endmodule
