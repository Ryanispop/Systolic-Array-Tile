`timescale 1ns/1ps

module skew_unit #(
    parameter int DATA_W = 8
) (
    input  logic clk,
    input  logic rst,
    input  logic start,

    input  logic signed [DATA_W-1:0] A00, A01,
    input  logic signed [DATA_W-1:0] A10, A11,

    input  logic signed [DATA_W-1:0] B00, B01,
    input  logic signed [DATA_W-1:0] B10, B11,

    output logic signed [DATA_W-1:0] a0, a1,
    output logic signed [DATA_W-1:0] b0, b1,

    output logic busy,
    output logic feed_done
); 

    logic [1:0] cycle;

    // Sequential control
    always_ff @(posedge clk) begin
        if (rst) begin
            cycle <= '0;
            busy  <= 1'b0;
            feed_done  <= 1'b0;
        end else begin
            feed_done <= 1'b0;

            if (start && !busy) begin
                cycle <= 2'd0;
                busy  <= 1'b1;
            end else if (busy) begin

                if (cycle == 2'd2) begin
                    busy <= 1'b0;
                    feed_done <= 1'b1;
                end else begin
                    cycle <= cycle + 1'b1;
                end

            end
        end
    end


    // Combinational output selection
    always_comb begin

        // Default: inject zeros
        a0 = '0;
        a1 = '0;
        b0 = '0;
        b1 = '0;

        if (busy) begin
            case (cycle)

                2'd0: begin
                    a0 = A00;
                    a1 = '0;
                    b0 = B00;
                    b1 = '0;
                end

                2'd1: begin
                    a0 = A01;
                    a1 = A10;
                    b0 = B10;
                    b1 = B01;
                end

                2'd2: begin
                    a0 = '0;
                    a1 = A11;
                    b0 = '0;
                    b1 = B11;
                end

                default: begin
                    // Defaults above already give us zeros
                end

            endcase
        end
    end
    
endmodule
