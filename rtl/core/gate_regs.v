`timescale 1ns/1ps

// Stores the four LSTM gates in project order: f, i, g, o.
module gate_regs (
    input  wire              clk,
    input  wire              rst_n,
    input  wire              clear,
    input  wire              write_en,
    input  wire [1:0]        gate_select,
    input  wire signed [7:0] gate_value,
    output reg  signed [7:0] gate_f,
    output reg  signed [7:0] gate_i,
    output reg  signed [7:0] gate_g,
    output reg  signed [7:0] gate_o
);
    localparam [1:0] GATE_F = 2'd0;
    localparam [1:0] GATE_I = 2'd1;
    localparam [1:0] GATE_G = 2'd2;
    localparam [1:0] GATE_O = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gate_f <= 8'sd0;
            gate_i <= 8'sd0;
            gate_g <= 8'sd0;
            gate_o <= 8'sd0;
        end else if (clear) begin
            gate_f <= 8'sd0;
            gate_i <= 8'sd0;
            gate_g <= 8'sd0;
            gate_o <= 8'sd0;
        end else if (write_en) begin
            case (gate_select)
                GATE_F: gate_f <= gate_value;
                GATE_I: gate_i <= gate_value;
                GATE_G: gate_g <= gate_value;
                default: gate_o <= gate_value;
            endcase
        end
    end
endmodule
