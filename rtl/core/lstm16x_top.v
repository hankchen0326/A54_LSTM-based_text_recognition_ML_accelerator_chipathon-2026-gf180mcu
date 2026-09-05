`timescale 1ns/1ps

// Twenty signal pins plus VDD/VSS: byte-command wrapper around sixteen
// parallel recurrent INT8 LSTM lanes.
module lstm16x_top #(
    parameter integer ACC_WIDTH        = 24,
    parameter integer FRAC_BITS        = 7,
    parameter integer GATE_INPUT_SHIFT = 10
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       cmd_valid,
    input  wire [7:0] cmd_data,
    output reg        rsp_valid,
    output reg  [7:0] rsp_data,
    inout  wire       VDD,
    inout  wire       VSS
);
    localparam [1:0]
        PENDING_NONE = 2'd0,
        PENDING_Y    = 2'd1,
        PENDING_H    = 2'd2,
        PENDING_C    = 2'd3;

    reg [1:0] pending_kind;
    reg [3:0] pending_index;

    reg       core_load_en;
    reg [3:0] core_load_addr;
    reg [3:0] core_lane_sel;
    reg [7:0] core_data_in;
    reg       core_start;

    wire [127:0] lane_h;
    wire [127:0] lane_c;
    wire [15:0] lane_busy;
    wire [15:0] lane_done;
    wire core_busy;
    wire core_done;
    wire _unused_power;

    assign _unused_power = &{1'b0, VDD, VSS};
    assign core_busy = lane_busy[0];
    assign core_done = lane_done[0];

    genvar lane;
    generate
        for (lane = 0; lane < 16; lane = lane + 1) begin : g_lane
            wire lane_load_en;
            assign lane_load_en = core_load_en &&
                                  ((core_load_addr < 4'd8) ||
                                   (core_lane_sel == lane));

            lstm_lane #(
                .LANE_ID          (lane),
                .ACC_WIDTH        (ACC_WIDTH),
                .FRAC_BITS        (FRAC_BITS),
                .GATE_INPUT_SHIFT (GATE_INPUT_SHIFT)
            ) u_lane (
                .clk       (clk),
                .rst_n     (rst_n),
                .load_en   (lane_load_en),
                .load_addr (core_load_addr),
                .load_data (core_data_in),
                .start     (core_start),
                .busy      (lane_busy[lane]),
                .done      (lane_done[lane]),
                .h_out     (lane_h[lane*8 +: 8]),
                .c_out     (lane_c[lane*8 +: 8])
            );
        end
    endgenerate

    // Byte protocol:
    //   00..07 + data : load broadcast y[0]..y[7]
    //   10..1F + data : load h_prev for lane 0..15
    //   20..2F + data : load c_prev for lane 0..15
    //   30           : start; completion response is D0
    //   40..4F       : read h lane 0..15
    //   50..5F       : read c lane 0..15
    //   60           : status {done,busy,6'b0}
    //   A8           : chip signature; A9: protocol/version 16h
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending_kind  <= PENDING_NONE;
            pending_index <= 4'd0;
            core_load_en  <= 1'b0;
            core_load_addr <= 4'd0;
            core_lane_sel <= 4'd0;
            core_data_in  <= 8'd0;
            core_start    <= 1'b0;
            rsp_valid     <= 1'b0;
            rsp_data      <= 8'd0;
        end else begin
            core_load_en <= 1'b0;
            core_start   <= 1'b0;
            rsp_valid    <= 1'b0;

            if (core_done) begin
                rsp_valid <= 1'b1;
                rsp_data  <= 8'hD0;
            end

            if (cmd_valid) begin
                if (pending_kind != PENDING_NONE) begin
                    core_data_in <= cmd_data;
                    case (pending_kind)
                        PENDING_Y: begin
                            core_load_addr <= pending_index;
                            core_lane_sel  <= 4'd0;
                        end
                        PENDING_H: begin
                            core_load_addr <= 4'd8;
                            core_lane_sel  <= pending_index;
                        end
                        default: begin
                            core_load_addr <= 4'd9;
                            core_lane_sel  <= pending_index;
                        end
                    endcase
                    core_load_en <= !core_busy;
                    pending_kind <= PENDING_NONE;
                end else if ((cmd_data[7:4] == 4'h0) &&
                             (cmd_data[3:0] < 4'd8)) begin
                    pending_kind  <= PENDING_Y;
                    pending_index <= cmd_data[3:0];
                end else if (cmd_data[7:4] == 4'h1) begin
                    pending_kind  <= PENDING_H;
                    pending_index <= cmd_data[3:0];
                end else if (cmd_data[7:4] == 4'h2) begin
                    pending_kind  <= PENDING_C;
                    pending_index <= cmd_data[3:0];
                end else begin
                    case (cmd_data[7:4])
                        4'h3: begin
                            if (!core_busy && (cmd_data == 8'h30))
                                core_start <= 1'b1;
                            else begin
                                rsp_valid <= 1'b1;
                                rsp_data  <= 8'hE1;
                            end
                        end
                        4'h4: begin
                            rsp_valid <= 1'b1;
                            rsp_data  <= lane_h[cmd_data[3:0]*8 +: 8];
                        end
                        4'h5: begin
                            rsp_valid <= 1'b1;
                            rsp_data  <= lane_c[cmd_data[3:0]*8 +: 8];
                        end
                        4'h6: begin
                            rsp_valid <= 1'b1;
                            rsp_data  <= {core_done, core_busy, 6'b0};
                        end
                        4'hA: begin
                            rsp_valid <= 1'b1;
                            if (cmd_data == 8'hA8)
                                rsp_data <= 8'hA8;
                            else if (cmd_data == 8'hA9)
                                rsp_data <= 8'h16;
                            else
                                rsp_data <= 8'hEE;
                        end
                        default: begin
                            rsp_valid <= 1'b1;
                            rsp_data  <= 8'hEE;
                        end
                    endcase
                end
            end
        end
    end
endmodule
