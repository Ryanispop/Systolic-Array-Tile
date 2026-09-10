`timescale 1ns/1ps

module mac_array_2x2 #(
    parameter int DATA_W = 8,
    parameter int ACC_W  = 32
) (
    input  logic clk,
    input  logic rst,
    input  logic clear,

    input  logic signed [DATA_W-1:0] a0, a1,
    input  logic signed [DATA_W-1:0] b0, b1,

    output logic signed [ACC_W-1:0] acc00,
    output logic signed [ACC_W-1:0] acc01,
    output logic signed [ACC_W-1:0] acc10,
    output logic signed [ACC_W-1:0] acc11
);

    logic signed [DATA_W-1:0] a_00_to_01;
    logic signed [DATA_W-1:0] a_10_to_11;
    logic signed [DATA_W-1:0] b_00_to_10;
    logic signed [DATA_W-1:0] b_01_to_11;

    logic signed [DATA_W-1:0] unused_a01;
    logic signed [DATA_W-1:0] unused_b10;
    logic signed [DATA_W-1:0] unused_a11;
    logic signed [DATA_W-1:0] unused_b11;

    mac_pe #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) pe00 (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_in(a0),
        .b_in(b0),
        .acc(acc00),
        .a_out(a_00_to_01),
        .b_out(b_00_to_10)
    );

    mac_pe #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) pe01 (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_in(a_00_to_01),
        .b_in(b1),
        .acc(acc01),
        .a_out(unused_a01),
        .b_out(b_01_to_11)
    );

    mac_pe #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) pe10 (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_in(a1),
        .b_in(b_00_to_10),
        .acc(acc10),
        .a_out(a_10_to_11),
        .b_out(unused_b10)
    );

    mac_pe #(
        .DATA_W(DATA_W),
        .ACC_W(ACC_W)
    ) pe11 (
        .clk(clk),
        .rst(rst),
        .clear(clear),
        .a_in(a_10_to_11),
        .b_in(b_01_to_11),
        .acc(acc11),
        .a_out(unused_a11),
        .b_out(unused_b11)
    );


endmodule
