`timescale 1ns/1ps

module tb_mac_tile #(
    parameter int N = 2,
    parameter int DATA_W = 8,
    parameter int ACC_W = 32
);
    logic clk;
    logic rst = 1;
    logic in_valid = 0;
    wire in_ready;
    logic [N*N*DATA_W-1:0] in_a = '0, in_b = '0;
    wire out_valid;
    logic out_ready = 0;
    wire [N*N*ACC_W-1:0] out_c;
    wire busy;
    logic [N*N*ACC_W-1:0] expected;
    int unsigned rng = 32'h12345678;

    mac_tile #(.N(N), .DATA_W(DATA_W), .ACC_W(ACC_W)) dut (.*);
    always #5 clk = ~clk;

    task automatic tick;
        @(posedge clk);
        #1;
    endtask

    // Deterministic random inputs, independent of simulator random seeds.
    function automatic int unsigned random_word;
        rng = rng ^ (rng << 13);
        rng = rng ^ (rng >> 17);
        rng = rng ^ (rng << 5);
        return rng;
    endfunction

    task automatic make_inputs(input int mode);
        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                case (mode)
                    0: begin // All zeros.
                        in_a[(row*N+col)*DATA_W +: DATA_W] = '0;
                        in_b[(row*N+col)*DATA_W +: DATA_W] = '0;
                    end
                    1: begin // Identity times a matrix with signed entries.
                        in_a[(row*N+col)*DATA_W +: DATA_W] = DATA_W'(row == col);
                        in_b[(row*N+col)*DATA_W +: DATA_W] = DATA_W'(row-col-1);
                    end
                    2: begin // Maximum positive and minimum negative operands.
                        in_a[(row*N+col)*DATA_W +: DATA_W] = DATA_W'(1 << (DATA_W-1));
                        in_b[(row*N+col)*DATA_W +: DATA_W] =
                            (col % 2 == 0) ? DATA_W'(1 << (DATA_W-1)) : DATA_W'((1 << (DATA_W-1))-1);
                    end
                    3: begin // Only the last multiply in the bottom-right PE is nonzero.
                        in_a[(row*N+col)*DATA_W +: DATA_W] = DATA_W'((row == N-1 && col == N-1) ? -2 : 0);
                        in_b[(row*N+col)*DATA_W +: DATA_W] = DATA_W'((row == N-1 && col == N-1) ? 3 : 0);
                    end
                    default: begin
                        in_a[(row*N+col)*DATA_W +: DATA_W] = DATA_W'(random_word());
                        in_b[(row*N+col)*DATA_W +: DATA_W] = DATA_W'(random_word());
                    end
                endcase
            end
        end
    endtask

    task automatic reference_product;
        longint signed sum, a_value, b_value;
        for (int row = 0; row < N; row++) begin
            for (int col = 0; col < N; col++) begin
                sum = 0;
                for (int k = 0; k < N; k++) begin
                    a_value = 64'($signed(in_a[(row*N+k)*DATA_W +: DATA_W]));
                    b_value = 64'($signed(in_b[(k*N+col)*DATA_W +: DATA_W]));
                    sum = sum + a_value*b_value;
                end
                expected[(row*N+col)*ACC_W +: ACC_W] = ACC_W'(sum);
            end
        end
    endtask

    task automatic run_transaction(input int mode, input int stall_cycles);
        @(negedge clk);
        if (!in_ready || busy || out_valid) $fatal(1, "Tile not idle");
        make_inputs(mode);
        reference_product();
        in_valid = 1;
        out_ready = (stall_cycles == 0);
        tick(); // Input acceptance.
        if (in_ready || !busy || out_valid) $fatal(1, "Input acceptance failed");
        @(negedge clk);
        // Inputs may change after acceptance. Holding valid must not overwrite
        // the captured input bank while ready is low.
        in_a = '1;
        in_b = '0;
        for (int elapsed = 1; elapsed <= 3*N; elapsed++) begin
            tick();
            if (!busy || in_ready) $fatal(1, "Unexpected input ready during compute");
            if (out_valid !== (elapsed == 3*N))
                $fatal(1, "Incorrect completion timing at cycle %0d", elapsed);
        end
        if (out_c !== expected)
            $fatal(1, "N=%0d mode=%0d: got %h expected %h", N, mode, out_c, expected);
        repeat (stall_cycles) begin
            tick();
            if (!out_valid || !busy || in_ready || out_c !== expected)
                $fatal(1, "Result changed or input accepted under backpressure");
        end
        @(negedge clk);
        in_valid = 0;
        out_ready = 1;
        tick();
        if (out_valid || busy || !in_ready) $fatal(1, "Output handshake failed");
    endtask

    task automatic run_waiting_request;
        logic [N*N*ACC_W-1:0] first_result;
        @(negedge clk);
        make_inputs(1);
        reference_product();
        first_result = expected;
        in_valid = 1;
        out_ready = 0;
        tick();
        @(negedge clk);
        // Present the second request while the first is still computing.
        make_inputs(4);
        reference_product();
        repeat (3*N) tick();
        if (!out_valid || out_c !== first_result)
            $fatal(1, "Waiting request overwrote the active input bank");
        repeat (3) begin
            tick();
            if (in_ready || !out_valid || out_c !== first_result)
                $fatal(1, "Waiting request disturbed the stalled result");
        end
        @(negedge clk);
        out_ready = 1;
        tick(); // Consume first result; ready becomes high for second request.
        if (!in_ready || out_valid || busy) $fatal(1, "Failed to return to idle");
        tick(); // Accept the already-present second request.
        if (in_ready || !busy || out_valid) $fatal(1, "Waiting request not accepted");
        @(negedge clk);
        in_valid = 0;
        in_a = '0;
        in_b = '0;
        repeat (3*N) tick();
        if (!out_valid || out_c !== expected)
            $fatal(1, "Waiting request produced incorrect result");
        tick();
        if (out_valid || busy || !in_ready) $fatal(1, "Second result not consumed");
    endtask

    initial begin
        clk = 0;
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_mac_tile);
        if (N < 1 || DATA_W < 2 || DATA_W > 16 || ACC_W < 1 || ACC_W > 32)
            $fatal(1, "Unsupported testbench parameter range");
        tick();
        if (in_ready || out_valid || busy || out_c !== '0) $fatal(1, "Reset failed");
        @(negedge clk);
        rst = 0;
        tick();
        // Valid low must not launch work, even if the consumer is ready.
        repeat (3) begin
            tick();
            if (!in_ready || busy || out_valid) $fatal(1, "Spurious transaction");
        end
        for (int mode = 0; mode < 24; mode++) run_transaction(mode, mode % 5);
        run_waiting_request();

        // Abort at every phase, including a stalled completed result.
        for (int offset = 0; offset <= 3*N+2; offset++) begin
            @(negedge clk);
            make_inputs(4);
            in_valid = 1;
            out_ready = 0;
            tick();
            @(negedge clk);
            in_valid = 0;
            repeat (offset) tick();
            @(negedge clk);
            rst = 1;
            in_valid = 1;
            tick();
            if (in_ready || out_valid || busy || out_c !== '0)
                $fatal(1, "Reset failed at offset %0d", offset);
            @(negedge clk);
            in_valid = 0;
            rst = 0;
            tick();
            run_transaction(3, 2);
        end
        $display("PASS mac_tile N=%0d DATA_W=%0d ACC_W=%0d", N, DATA_W, ACC_W);
        $finish;
    end

    initial begin
        #1000000;
        $fatal(1, "Testbench timeout");
    end
endmodule
