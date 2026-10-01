`timescale 1ns/1ps

module mac_pe #(
    parameter int DATA_W = 8,
    parameter int ACC_W = 32
) (
    input logic clk,
    input logic rst,
    input logic clear,
    input logic signed [DATA_W-1:0] a_in,
    input logic signed [DATA_W-1:0] b_in,
    output logic signed [DATA_W-1:0] a_out,
    output logic signed [DATA_W-1:0] b_out,
    output logic signed [ACC_W-1:0] acc
);
    always_ff @(posedge clk) begin
        if (rst || clear) begin
            acc <= '0;
            a_out <= '0;
            b_out <= '0;
        end else begin
            // Explicit width makes wraparound intentional for narrow accumulators.
            acc <= acc + ACC_W'(a_in * b_in);
            a_out <= a_in;
            b_out <= b_in;
        end
    end
endmodule
