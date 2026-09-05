`timescale 1ns/1ps

// 32-entry activation LUT for Q1.7 gate values.
// Inputs are accumulated in Q2.14.  The index samples the pre-activation
// range [-1.0, 0.9375] in 0.0625 steps:
//   idx = clamp((acc >>> INPUT_SHIFT) + 16, 0, 31)
module act_lut #(
    parameter integer ACC_WIDTH   = 24,
    parameter integer INPUT_SHIFT = 10
)(
    input  wire signed [ACC_WIDTH-1:0] acc,
    input  wire                        is_tanh,
    output reg  signed [7:0]           value
);
    reg signed [ACC_WIDTH-1:0] scaled;
    reg signed [ACC_WIDTH:0]   index_temp;
    reg [4:0]                  index;

    always @(*) begin
        scaled = acc >>> INPUT_SHIFT;
        index_temp = $signed({scaled[ACC_WIDTH-1], scaled}) + $signed({{(ACC_WIDTH-4){1'b0}}, 5'd16});

        if (index_temp < 0)
            index = 5'd0;
        else if (index_temp > 31)
            index = 5'd31;
        else
            index = index_temp[4:0];
    end

    always @(*) begin
        if (is_tanh) begin
            case (index)
                5'd0:  value = -8'sd97;
                5'd1:  value = -8'sd94;
                5'd2:  value = -8'sd90;
                5'd3:  value = -8'sd86;
                5'd4:  value = -8'sd81;
                5'd5:  value = -8'sd76;
                5'd6:  value = -8'sd71;
                5'd7:  value = -8'sd65;
                5'd8:  value = -8'sd59;
                5'd9:  value = -8'sd53;
                5'd10: value = -8'sd46;
                5'd11: value = -8'sd39;
                5'd12: value = -8'sd31;
                5'd13: value = -8'sd24;
                5'd14: value = -8'sd16;
                5'd15: value = -8'sd8;
                5'd16: value =  8'sd0;
                5'd17: value =  8'sd8;
                5'd18: value =  8'sd16;
                5'd19: value =  8'sd24;
                5'd20: value =  8'sd31;
                5'd21: value =  8'sd39;
                5'd22: value =  8'sd46;
                5'd23: value =  8'sd53;
                5'd24: value =  8'sd59;
                5'd25: value =  8'sd65;
                5'd26: value =  8'sd71;
                5'd27: value =  8'sd76;
                5'd28: value =  8'sd81;
                5'd29: value =  8'sd86;
                5'd30: value =  8'sd90;
                default: value = 8'sd94;
            endcase
        end else begin
            case (index)
                5'd0:  value = 8'sd34;
                5'd1:  value = 8'sd36;
                5'd2:  value = 8'sd38;
                5'd3:  value = 8'sd39;
                5'd4:  value = 8'sd41;
                5'd5:  value = 8'sd43;
                5'd6:  value = 8'sd45;
                5'd7:  value = 8'sd46;
                5'd8:  value = 8'sd48;
                5'd9:  value = 8'sd50;
                5'd10: value = 8'sd52;
                5'd11: value = 8'sd54;
                5'd12: value = 8'sd56;
                5'd13: value = 8'sd58;
                5'd14: value = 8'sd60;
                5'd15: value = 8'sd62;
                5'd16: value = 8'sd64;
                5'd17: value = 8'sd66;
                5'd18: value = 8'sd68;
                5'd19: value = 8'sd70;
                5'd20: value = 8'sd72;
                5'd21: value = 8'sd74;
                5'd22: value = 8'sd76;
                5'd23: value = 8'sd78;
                5'd24: value = 8'sd80;
                5'd25: value = 8'sd82;
                5'd26: value = 8'sd83;
                5'd27: value = 8'sd85;
                5'd28: value = 8'sd87;
                5'd29: value = 8'sd89;
                5'd30: value = 8'sd90;
                default: value = 8'sd92;
            endcase
        end
    end
endmodule
