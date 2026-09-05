`timescale 1ns/1ps

// Combinational signed 8-bit x 8-bit multiplier.
// It avoids using Verilog '*'.  The implementation is sign-magnitude
// plus shift-add partial products, so it synthesizes to standard cells.
module mul8 (
    input  wire signed [7:0]  a,
    input  wire signed [7:0]  b,
    output wire signed [15:0] product
);
    wire sign;
    wire [8:0] abs_a;
    wire [8:0] abs_b;
    wire [17:0] abs_a_18;

    wire [17:0] pp0;
    wire [17:0] pp1;
    wire [17:0] pp2;
    wire [17:0] pp3;
    wire [17:0] pp4;
    wire [17:0] pp5;
    wire [17:0] pp6;
    wire [17:0] pp7;
    wire [17:0] pp8;
    wire [17:0] product_abs;

    wire signed [15:0] product_pos;
    wire signed [15:0] product_neg;

    assign sign = a[7] ^ b[7];

    // 9-bit magnitude is needed to represent abs(-128) = 128.
    assign abs_a = a[7] ? ({1'b0, ~a} + 9'd1) : {1'b0, a};
    assign abs_b = b[7] ? ({1'b0, ~b} + 9'd1) : {1'b0, b};

    assign abs_a_18 = {9'd0, abs_a};

    assign pp0 = abs_b[0] ? (abs_a_18      ) : 18'd0;
    assign pp1 = abs_b[1] ? (abs_a_18 << 1 ) : 18'd0;
    assign pp2 = abs_b[2] ? (abs_a_18 << 2 ) : 18'd0;
    assign pp3 = abs_b[3] ? (abs_a_18 << 3 ) : 18'd0;
    assign pp4 = abs_b[4] ? (abs_a_18 << 4 ) : 18'd0;
    assign pp5 = abs_b[5] ? (abs_a_18 << 5 ) : 18'd0;
    assign pp6 = abs_b[6] ? (abs_a_18 << 6 ) : 18'd0;
    assign pp7 = abs_b[7] ? (abs_a_18 << 7 ) : 18'd0;
    assign pp8 = abs_b[8] ? (abs_a_18 << 8 ) : 18'd0;

    assign product_abs = pp0 + pp1 + pp2 + pp3 + pp4 + pp5 + pp6 + pp7 + pp8;

    assign product_pos = $signed(product_abs[15:0]);
    assign product_neg = -$signed(product_abs[15:0]);
    assign product = sign ? product_neg : product_pos;
endmodule
