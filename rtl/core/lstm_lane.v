`timescale 1ns/1ps

// One lane of the 16-lane fixed-weight INT8 LSTM accelerator.
//
// This tapeout-oriented version keeps the original LSTM vector shape:
//   vector = [y0,y1,y2,y3,y4,y5,y6,y7,h_prev]
// Inputs are loaded serially through an 8-bit bus before start is asserted.
// Weights and biases are fixed in logic, avoiding the SRAM macro and host bus.
module lstm_lane #(
    parameter integer LANE_ID          = 0,
    parameter integer ACC_WIDTH        = 24,
    parameter integer FRAC_BITS        = 7,
    parameter integer GATE_INPUT_SHIFT = 10
)(
    input  wire              clk,
    input  wire              rst_n,

    input  wire              load_en,
    input  wire [3:0]        load_addr,
    input  wire signed [7:0] load_data,

    input  wire              start,
    output reg               busy,
    output reg               done,
    output reg  signed [7:0] h_out,
    output reg  signed [7:0] c_out
);
    localparam [1:0] GATE_F = 2'd0;
    localparam [1:0] GATE_I = 2'd1;
    localparam [1:0] GATE_G = 2'd2;
    localparam [1:0] GATE_O = 2'd3;

    localparam [3:0]
        ST_IDLE      = 4'd0,
        ST_GATE_INIT = 4'd1,
        ST_GATE_MAC  = 4'd2,
        ST_SAVE_GATE = 4'd3,
        ST_MUL_FC    = 4'd4,
        ST_MUL_IG    = 4'd5,
        ST_UPDATE_C  = 4'd6,
        ST_MUL_OH    = 4'd7,
        ST_UPDATE_H  = 4'd8,
        ST_DONE      = 4'd9;

    reg [3:0] state;
    reg [1:0] current_gate;
    reg [3:0] vector_index;  // 0..7: y0..y7, 8: h_state

    reg signed [7:0] y0;
    reg signed [7:0] y1;
    reg signed [7:0] y2;
    reg signed [7:0] y3;
    reg signed [7:0] y4;
    reg signed [7:0] y5;
    reg signed [7:0] y6;
    reg signed [7:0] y7;
    reg signed [7:0] h_state;
    reg signed [7:0] c_state;
    reg signed [7:0] c_next;

    reg signed [ACC_WIDTH-1:0] acc;
    reg signed [ACC_WIDTH-1:0] fc_product_ext;
    reg signed [ACC_WIDTH-1:0] ig_product_ext;
    reg signed [ACC_WIDTH-1:0] oh_product_ext;

    wire signed [7:0] gate_f;
    wire signed [7:0] gate_i;
    wire signed [7:0] gate_g;
    wire signed [7:0] gate_o;

    wire gate_clear;
    wire gate_write_en;
    wire signed [7:0] gate_value_from_lut;

    assign gate_clear = (state == ST_IDLE) && start;
    assign gate_write_en = (state == ST_SAVE_GATE);

    gate_regs u_gate_regs (
        .clk         (clk),
        .rst_n       (rst_n),
        .clear       (gate_clear),
        .write_en    (gate_write_en),
        .gate_select (current_gate),
        .gate_value  (gate_value_from_lut),
        .gate_f      (gate_f),
        .gate_i      (gate_i),
        .gate_g      (gate_g),
        .gate_o      (gate_o)
    );

    reg signed [7:0] mul_a;
    reg signed [7:0] mul_b;
    wire signed [15:0] mul_product;

    mul8 u_mul8 (
        .a       (mul_a),
        .b       (mul_b),
        .product (mul_product)
    );

    act_lut #(
        .ACC_WIDTH   (ACC_WIDTH),
        .INPUT_SHIFT (GATE_INPUT_SHIFT)
    ) u_gate_activation (
        .acc     (acc),
        .is_tanh (current_gate == GATE_G),
        .value   (gate_value_from_lut)
    );

    wire signed [7:0] tanh_c_next;

    tanh8 u_tanh_c (
        .x (c_next),
        .y (tanh_c_next)
    );

    wire signed [ACC_WIDTH-1:0] mul_product_acc;
    wire signed [ACC_WIDTH-1:0] gate_bias_acc;
    wire signed [ACC_WIDTH-1:0] c_next_sum;
    wire signed [ACC_WIDTH-1:0] h_next_shifted;
    reg  signed [7:0]           base_weight_value;
    reg  signed [7:0]           base_bias_value;
    reg  signed [7:0]           gate_weight_value;
    reg  signed [7:0]           gate_bias_value;
    reg  signed [7:0]           vector_value;
    reg  signed [7:0]           c_next_sat;
    reg  signed [7:0]           h_next_sat;

    assign mul_product_acc = {{(ACC_WIDTH-16){mul_product[15]}}, mul_product};
    assign gate_bias_acc = {{(ACC_WIDTH-8){gate_bias_value[7]}}, gate_bias_value} <<< FRAC_BITS;
    assign c_next_sum = (fc_product_ext >>> FRAC_BITS) + (ig_product_ext >>> FRAC_BITS);
    assign h_next_shifted = oh_product_ext >>> FRAC_BITS;

    always @(*) begin
        case (vector_index)
            4'd0: vector_value = y0;
            4'd1: vector_value = y1;
            4'd2: vector_value = y2;
            4'd3: vector_value = y3;
            4'd4: vector_value = y4;
            4'd5: vector_value = y5;
            4'd6: vector_value = y6;
            4'd7: vector_value = y7;
            default: vector_value = h_state;
        endcase
    end

    // Each lane represents a distinct output row.  Lane zero retains the
    // original trained coefficients.  The other rows use small deterministic
    // offsets, mirrored exactly by model/golden_model.py.
    function signed [4:0] lane_delta;
        input integer lane;
        begin
            case (lane)
                0: lane_delta =  5'sd0;
                1: lane_delta =  5'sd1;
                2: lane_delta = -5'sd1;
                3: lane_delta =  5'sd2;
                4: lane_delta = -5'sd2;
                5: lane_delta =  5'sd3;
                6: lane_delta = -5'sd3;
                7: lane_delta =  5'sd4;
                8: lane_delta = -5'sd4;
                9: lane_delta =  5'sd5;
                10: lane_delta = -5'sd5;
                11: lane_delta =  5'sd6;
                12: lane_delta = -5'sd6;
                13: lane_delta =  5'sd7;
                14: lane_delta = -5'sd7;
                default: lane_delta = 5'sd8;
            endcase
        end
    endfunction

    function signed [7:0] sat8_coeff;
        input signed [9:0] value;
        begin
            if (value > 10'sd127)
                sat8_coeff = 8'sd127;
            else if (value < -10'sd128)
                sat8_coeff = -8'sd128;
            else
                sat8_coeff = value[7:0];
        end
    endfunction

    always @(*) begin
        case ({current_gate, vector_index})
            {GATE_F, 4'd0}: base_weight_value = -8'sd81;
            {GATE_F, 4'd1}: base_weight_value = -8'sd46;
            {GATE_F, 4'd2}: base_weight_value = -8'sd73;
            {GATE_F, 4'd3}: base_weight_value =  8'sd46;
            {GATE_F, 4'd4}: base_weight_value =  8'sd0;
            {GATE_F, 4'd5}: base_weight_value = -8'sd55;
            {GATE_F, 4'd6}: base_weight_value =  8'sd8;
            {GATE_F, 4'd7}: base_weight_value =  8'sd88;
            {GATE_F, 4'd8}: base_weight_value = -8'sd1;

            {GATE_I, 4'd0}: base_weight_value =  8'sd48;
            {GATE_I, 4'd1}: base_weight_value =  8'sd70;
            {GATE_I, 4'd2}: base_weight_value =  8'sd6;
            {GATE_I, 4'd3}: base_weight_value =  8'sd50;
            {GATE_I, 4'd4}: base_weight_value = -8'sd46;
            {GATE_I, 4'd5}: base_weight_value =  8'sd59;
            {GATE_I, 4'd6}: base_weight_value = -8'sd84;
            {GATE_I, 4'd7}: base_weight_value = -8'sd89;
            {GATE_I, 4'd8}: base_weight_value =  8'sd92;

            {GATE_G, 4'd0}: base_weight_value =  8'sd85;
            {GATE_G, 4'd1}: base_weight_value =  8'sd95;
            {GATE_G, 4'd2}: base_weight_value =  8'sd30;
            {GATE_G, 4'd3}: base_weight_value =  8'sd87;
            {GATE_G, 4'd4}: base_weight_value =  8'sd83;
            {GATE_G, 4'd5}: base_weight_value =  8'sd71;
            {GATE_G, 4'd6}: base_weight_value =  8'sd60;
            {GATE_G, 4'd7}: base_weight_value =  8'sd92;
            {GATE_G, 4'd8}: base_weight_value = -8'sd48;

            {GATE_O, 4'd0}: base_weight_value =  8'sd32;
            {GATE_O, 4'd1}: base_weight_value =  8'sd91;
            {GATE_O, 4'd2}: base_weight_value =  8'sd60;
            {GATE_O, 4'd3}: base_weight_value = -8'sd58;
            {GATE_O, 4'd4}: base_weight_value = -8'sd92;
            {GATE_O, 4'd5}: base_weight_value =  8'sd48;
            {GATE_O, 4'd6}: base_weight_value = -8'sd71;
            {GATE_O, 4'd7}: base_weight_value =  8'sd66;
            default:        base_weight_value =  8'sd8;
        endcase
        gate_weight_value = sat8_coeff(base_weight_value + lane_delta(LANE_ID));
    end

    always @(*) begin
        case (current_gate)
            GATE_F:  base_bias_value =  8'sd8;
            GATE_I:  base_bias_value = -8'sd9;
            GATE_G:  base_bias_value = -8'sd10;
            default: base_bias_value = -8'sd5;
        endcase
        gate_bias_value = sat8_coeff(base_bias_value + lane_delta(LANE_ID));
    end

    always @(*) begin
        if (c_next_sum > 127)
            c_next_sat = 8'sd127;
        else if (c_next_sum < -128)
            c_next_sat = -8'sd128;
        else
            c_next_sat = c_next_sum[7:0];
    end

    always @(*) begin
        if (h_next_shifted > 127)
            h_next_sat = 8'sd127;
        else if (h_next_shifted < -128)
            h_next_sat = -8'sd128;
        else
            h_next_sat = h_next_shifted[7:0];
    end

    always @(*) begin
        mul_a = 8'sd0;
        mul_b = 8'sd0;

        case (state)
            ST_GATE_MAC: begin
                mul_a = gate_weight_value;
                mul_b = vector_value;
            end

            ST_MUL_FC: begin
                mul_a = gate_f;
                mul_b = c_state;
            end

            ST_MUL_IG: begin
                mul_a = gate_i;
                mul_b = gate_g;
            end

            ST_MUL_OH: begin
                mul_a = gate_o;
                mul_b = tanh_c_next;
            end

            default: begin
                mul_a = 8'sd0;
                mul_b = 8'sd0;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state          <= ST_IDLE;
            current_gate   <= GATE_F;
            vector_index   <= 4'd0;
            y0             <= 8'sd0;
            y1             <= 8'sd0;
            y2             <= 8'sd0;
            y3             <= 8'sd0;
            y4             <= 8'sd0;
            y5             <= 8'sd0;
            y6             <= 8'sd0;
            y7             <= 8'sd0;
            h_state        <= 8'sd0;
            c_state        <= 8'sd0;
            c_next         <= 8'sd0;
            acc            <= {ACC_WIDTH{1'b0}};
            fc_product_ext <= {ACC_WIDTH{1'b0}};
            ig_product_ext <= {ACC_WIDTH{1'b0}};
            oh_product_ext <= {ACC_WIDTH{1'b0}};
            busy           <= 1'b0;
            done           <= 1'b0;
            h_out          <= 8'sd0;
            c_out          <= 8'sd0;
        end else begin
            done <= 1'b0;

            if ((!busy) && load_en) begin
                case (load_addr)
                    4'd0: y0 <= load_data;
                    4'd1: y1 <= load_data;
                    4'd2: y2 <= load_data;
                    4'd3: y3 <= load_data;
                    4'd4: y4 <= load_data;
                    4'd5: y5 <= load_data;
                    4'd6: y6 <= load_data;
                    4'd7: y7 <= load_data;
                    4'd8: begin
                        h_state <= load_data;
                        h_out   <= load_data;
                    end
                    4'd9: begin
                        c_state <= load_data;
                        c_out   <= load_data;
                    end
                    default: begin
                    end
                endcase
            end

            case (state)
                ST_IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        current_gate <= GATE_F;
                        vector_index <= 4'd0;
                        busy         <= 1'b1;
                        state        <= ST_GATE_INIT;
                    end
                end

                ST_GATE_INIT: begin
                    acc          <= gate_bias_acc;
                    vector_index <= 4'd0;
                    state        <= ST_GATE_MAC;
                end

                ST_GATE_MAC: begin
                    acc <= acc + mul_product_acc;
                    if (vector_index == 4'd8) begin
                        state <= ST_SAVE_GATE;
                    end else begin
                        vector_index <= vector_index + 4'd1;
                    end
                end

                ST_SAVE_GATE: begin
                    if (current_gate == GATE_O) begin
                        state <= ST_MUL_FC;
                    end else begin
                        current_gate <= current_gate + 2'd1;
                        state        <= ST_GATE_INIT;
                    end
                end

                ST_MUL_FC: begin
                    fc_product_ext <= mul_product_acc;
                    state          <= ST_MUL_IG;
                end

                ST_MUL_IG: begin
                    ig_product_ext <= mul_product_acc;
                    state          <= ST_UPDATE_C;
                end

                ST_UPDATE_C: begin
                    c_next <= c_next_sat;
                    state  <= ST_MUL_OH;
                end

                ST_MUL_OH: begin
                    oh_product_ext <= mul_product_acc;
                    state          <= ST_UPDATE_H;
                end

                ST_UPDATE_H: begin
                    h_state   <= h_next_sat;
                    c_state   <= c_next;
                    h_out     <= h_next_sat;
                    c_out     <= c_next;
                    state     <= ST_DONE;
                end

                ST_DONE: begin
                    busy  <= 1'b0;
                    done  <= 1'b1;
                    state <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end
endmodule
