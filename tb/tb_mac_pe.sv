`timescale 1ns/1ps

module tb_mac_pe;

    localparam int DATA_W = 8;
    localparam int ACC_W  = 32;

    logic clk;
    logic rst;
    logic clear;
    logic signed [DATA_W-1:0] a;
    logic signed [DATA_W-1:0] b;
    logic signed [DATA_W-1:0] a_out, b_out;
    logic signed [ACC_W-1:0] acc;

    mac_pe #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) dut (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_in(a),
        .b_in(b),
        .a_out(a_out),
        .b_out(b_out),
        .acc(acc)
    );

    always #5 clk = ~clk;

    task do_mac(
        input logic signed [DATA_W-1:0] ta,
        input logic signed [DATA_W-1:0] tb,
        input logic signed [ACC_W-1:0] expected
    );
        begin
            @(negedge clk);
            a = ta;
            b = tb;
            @(posedge clk);
            #1;

            if (acc !== expected || a_out !== ta || b_out !== tb) begin
                $display("FAIL: a=%0d b=%0d acc=%0d expected=%0d",
                         ta, tb, acc, expected);
                $fatal;
            end else begin
                $display("PASS: a=%0d b=%0d acc=%0d",
                         ta, tb, acc);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_mac_pe);

        clk = 0;
        rst = 1;
        clear = 1;
        a = 0;
        b = 0;

        repeat (2) @(posedge clk);
        @(negedge clk);
        rst = 0;
        clear = 0;
        #1;

        do_mac(3,  4,  12);   // acc = 0 + 12
        do_mac(2,  5,  22);   // acc = 12 + 10
        do_mac(-1, 7,  15);   // acc = 22 - 7
        do_mac(-3, -2, 21);   // acc = 15 + 6

        @(negedge clk);
        clear = 1;
        @(posedge clk);
        #1;

        if (acc !== 0 || a_out !== 0 || b_out !== 0) begin
            $display("FAIL: clear did not reset acc, acc=%0d", acc);
            $fatal;
        end

        clear = 0;

        do_mac(10, 2, 20);

        $display("All MAC PE tests passed.");
        $finish;
    end

endmodule
