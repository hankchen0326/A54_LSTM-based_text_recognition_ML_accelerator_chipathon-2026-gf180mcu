`timescale 1ns/1ps

// Chipathon A54 project-block wrapper.
//
// The ports of this module intentionally match A54_A.def exactly.  They are
// the internal terminals of the organizer's pad cells, not the 22 package
// pads themselves.  The existing LSTM RTL is instantiated unchanged.
module A54_A (
    inout  wire       VSS,
    inout  wire       VDD,

    output wire [7:0] rsp_data_CS,
    output wire [7:0] rsp_data_SL,
    output wire [7:0] rsp_data_IE,
    output wire [7:0] rsp_data_OE,
    output wire [7:0] rsp_data_PU,
    output wire [7:0] rsp_data_PD,
    output wire [7:0] rsp_data_OUT,
    output wire [7:0] rsp_data_PDRV0,
    output wire [7:0] rsp_data_PDRV1,
    input  wire [7:0] rsp_data_IN,

    output wire       rsp_valid_CS,
    output wire       rsp_valid_SL,
    output wire       rsp_valid_IE,
    output wire       rsp_valid_OE,
    output wire       rsp_valid_PU,
    output wire       rsp_valid_PD,
    output wire       rsp_valid_OUT,
    output wire       rsp_valid_PDRV0,
    output wire       rsp_valid_PDRV1,
    input  wire       rsp_valid_IN,

    output wire       clk_PU,
    output wire       clk_PD,
    input  wire       clk,

    output wire       rst_n_PU,
    output wire       rst_n_PD,
    input  wire       rst_n,

    output wire       cmd_valid_PU,
    output wire       cmd_valid_PD,
    input  wire       cmd_valid,

    output wire [7:0] cmd_data_PU,
    output wire [7:0] cmd_data_PD,
    input  wire [7:0] cmd_data
);
    wire       core_rsp_valid;
    wire [7:0] core_rsp_data;

    // Input pads: disable weak pull-up and pull-down devices.
    assign clk_PU       = 1'b0;
    assign clk_PD       = 1'b0;
    assign rst_n_PU     = 1'b0;
    assign rst_n_PD     = 1'b0;
    assign cmd_valid_PU = 1'b0;
    assign cmd_valid_PD = 1'b0;
    assign cmd_data_PU  = 8'h00;
    assign cmd_data_PD  = 8'h00;

    // The nine response pads are used as outputs.  Their input receivers and
    // weak pulls are disabled, while their output drivers remain enabled.
    assign rsp_data_CS    = 8'h00;
    assign rsp_data_SL    = 8'h00;
    assign rsp_data_IE    = 8'h00;
    assign rsp_data_OE    = 8'hff;
    assign rsp_data_PU    = 8'h00;
    assign rsp_data_PD    = 8'h00;
    assign rsp_data_PDRV0 = 8'h00;
    assign rsp_data_PDRV1 = 8'h00;
    assign rsp_data_OUT   = core_rsp_data;

    assign rsp_valid_CS    = 1'b0;
    assign rsp_valid_SL    = 1'b0;
    assign rsp_valid_IE    = 1'b0;
    assign rsp_valid_OE    = 1'b1;
    assign rsp_valid_PU    = 1'b0;
    assign rsp_valid_PD    = 1'b0;
    assign rsp_valid_PDRV0 = 1'b0;
    assign rsp_valid_PDRV1 = 1'b0;
    assign rsp_valid_OUT   = core_rsp_valid;

    // Keep the pad readback terminals in the exact organizer interface even
    // though this design intentionally operates the response pads as outputs.
    wire _unused_response_readback;
    assign _unused_response_readback = ^{rsp_data_IN, rsp_valid_IN};

    lstm16x_top u_lstm16x_top (
        .clk       (clk),
        .rst_n     (rst_n),
        .cmd_valid (cmd_valid),
        .cmd_data  (cmd_data),
        .rsp_valid (core_rsp_valid),
        .rsp_data  (core_rsp_data),
        .VDD       (VDD),
        .VSS       (VSS)
    );
endmodule
