`timescale 1ns/1ps

// 32-entry tanh LUT for Q1.7 cell state.
// c_next is stored in Q1.7 and sampled over [-1.0, 0.9375] in 0.0625 steps:
//   idx = clamp((c_next >>> INPUT_SHIFT) + 16, 0, 31)
module tanh8 #(
    parameter integer INPUT_SHIFT = 3
) (
    input  wire signed [7:0] x,
    output reg  signed [7:0] y
);
    reg signed [7:0] scaled;
    reg signed [8:0] index_temp;
    reg [4:0] index;

    always @(*) begin
        scaled = x >>> INPUT_SHIFT;
        index_temp = {scaled[7], scaled} + 9'sd16;
        if (index_temp < 0)
            index = 5'd0;
        else if (index_temp > 31)
            index = 5'd31;
        else
            index = index_temp[4:0];
    end

    always @(*) begin
        case (index)
            5'd0:  y = -8'sd97;
            5'd1:  y = -8'sd93;
            5'd2:  y = -8'sd89;
            5'd3:  y = -8'sd85;
            5'd4:  y = -8'sd81;
            5'd5:  y = -8'sd76;
            5'd6:  y = -8'sd70;
            5'd7:  y = -8'sd65;
            5'd8:  y = -8'sd59;
            5'd9:  y = -8'sd52;
            5'd10: y = -8'sd46;
            5'd11: y = -8'sd38;
            5'd12: y = -8'sd31;
            5'd13: y = -8'sd24;
            5'd14: y = -8'sd16;
            5'd15: y = -8'sd8;
            5'd16: y =  8'sd0;
            5'd17: y =  8'sd8;
            5'd18: y =  8'sd16;
            5'd19: y =  8'sd24;
            5'd20: y =  8'sd31;
            5'd21: y =  8'sd38;
            5'd22: y =  8'sd46;
            5'd23: y =  8'sd52;
            5'd24: y =  8'sd59;
            5'd25: y =  8'sd65;
            5'd26: y =  8'sd70;
            5'd27: y =  8'sd76;
            5'd28: y =  8'sd81;
            5'd29: y =  8'sd85;
            5'd30: y =  8'sd89;
            default: y = 8'sd93;
        endcase
    end
endmodule
