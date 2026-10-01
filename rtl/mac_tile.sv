`timescale 1ns/1ps

// One buffered C = A * B transaction at a time. Matrices are row-major;
// element [row][col] occupies [(row*N+col)*WIDTH +: WIDTH].
module mac_tile #(
    parameter int N = 2,
    parameter int DATA_W = 8,
    parameter int ACC_W = 32
) (
    input  logic clk,
    input  logic rst,
    input  logic in_valid,
    output logic in_ready,
    input  logic [N*N*DATA_W-1:0] in_a,
    input  logic [N*N*DATA_W-1:0] in_b,
    output logic out_valid,
    input  logic out_ready,
    output logic [N*N*ACC_W-1:0] out_c,
    output logic busy
);
    localparam int COUNT_W = (N > 1) ? $clog2(2*N-1) : 1;
    typedef enum logic [2:0] {IDLE, CLEAR, FEED, DRAIN, CAPTURE, RESULT} state_t;
    state_t state;
    logic [COUNT_W-1:0] cycle;
    logic [N*N*DATA_W-1:0] a_buffer, b_buffer;
    wire [N*N*ACC_W-1:0] accumulators;
    logic signed [DATA_W-1:0] a_feed [0:N-1];
    logic signed [DATA_W-1:0] b_feed [0:N-1];
    wire signed [DATA_W-1:0] a_forward [0:N-1][0:N-1];
    wire signed [DATA_W-1:0] b_forward [0:N-1][0:N-1];
    // Boundary forwarding ports are intentionally unused (including N=1).
    wire [N*DATA_W-1:0] unused_a_boundary, unused_b_boundary;
    wire clear_array = (state == CLEAR);

    assign in_ready = !rst && (state == IDLE);
    assign out_valid = !rst && (state == RESULT);
    assign busy = !rst && (state != IDLE);

    // Row r receives A[r][t-r]; column c receives B[t-c][c].
    // Outside the feed window, zeros drain the registered operand links.
    always_comb begin
        for (int lane = 0; lane < N; lane++) begin
            a_feed[lane] = '0;
            b_feed[lane] = '0;
            if (state == FEED && int'(cycle) >= lane && int'(cycle) < lane+N) begin
                a_feed[lane] = a_buffer[(lane*N+int'(cycle)-lane)*DATA_W +: DATA_W];
                b_feed[lane] = b_buffer[((int'(cycle)-lane)*N+lane)*DATA_W +: DATA_W];
            end
        end
    end

    for (genvar row = 0; row < N; row++) begin : gen_row
        assign unused_a_boundary[row*DATA_W +: DATA_W] = a_forward[row][N-1];
        assign unused_b_boundary[row*DATA_W +: DATA_W] = b_forward[N-1][row];
        for (genvar col = 0; col < N; col++) begin : gen_col
            wire signed [DATA_W-1:0] a_operand;
            wire signed [DATA_W-1:0] b_operand;
            if (col == 0) begin : gen_left
                assign a_operand = a_feed[row];
            end else begin : gen_horizontal
                assign a_operand = a_forward[row][col-1];
            end
            if (row == 0) begin : gen_top
                assign b_operand = b_feed[col];
            end else begin : gen_vertical
                assign b_operand = b_forward[row-1][col];
            end
            mac_pe #(.DATA_W(DATA_W), .ACC_W(ACC_W)) pe (
                .clk(clk), .rst(rst), .clear(clear_array),
                .a_in(a_operand), .b_in(b_operand),
                .a_out(a_forward[row][col]), .b_out(b_forward[row][col]),
                .acc(accumulators[(row*N+col)*ACC_W +: ACC_W])
            );
        end
    end

    // Reset aborts an in-flight transaction and invalidates the output bank.
    // Capture occurs on a separate edge AFTER the final PE accumulation.
    always_ff @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            cycle <= '0;
            a_buffer <= '0;
            b_buffer <= '0;
            out_c <= '0;
        end else begin
            case (state)
                IDLE: if (in_valid) begin
                    a_buffer <= in_a;
                    b_buffer <= in_b;
                    state <= CLEAR;
                end
                CLEAR: begin
                    cycle <= '0;
                    state <= FEED;
                end
                FEED: begin
                    if (cycle == COUNT_W'(2*N-2)) begin
                        cycle <= '0;
                        if (N == 1) state <= CAPTURE;
                        else state <= DRAIN;
                    end else cycle <= cycle + 1'b1;
                end
                DRAIN: begin
                    if (cycle == COUNT_W'(N-2)) state <= CAPTURE;
                    else cycle <= cycle + 1'b1;
                end
                CAPTURE: begin
                    out_c <= accumulators;
                    state <= RESULT;
                end
                RESULT: if (out_ready) state <= IDLE;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
