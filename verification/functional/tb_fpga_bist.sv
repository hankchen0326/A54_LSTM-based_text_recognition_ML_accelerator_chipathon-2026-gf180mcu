`timescale 1ns/1ps

module tb_fpga_bist;
    reg clk = 0;
    reg rst_n = 0;
    reg begin_test = 0;
    wire asic_rst_n, cmd_valid, rsp_valid, test_done, test_pass;
    wire [7:0] cmd_data, rsp_data;
    wire VDD = 1'b1;
    wire VSS = 1'b0;

    always #5 clk = ~clk;

    lstm16x_fpga_bist tester (
        .clk(clk), .rst_n(rst_n), .begin_test(begin_test), .asic_clk(),
        .asic_rst_n(asic_rst_n), .asic_cmd_valid(cmd_valid),
        .asic_cmd_data(cmd_data), .asic_rsp_valid(rsp_valid),
        .asic_rsp_data(rsp_data), .test_done(test_done), .test_pass(test_pass)
    );

    lstm16x_top asic (
        .clk(clk), .rst_n(asic_rst_n), .cmd_valid(cmd_valid),
        .cmd_data(cmd_data), .rsp_valid(rsp_valid), .rsp_data(rsp_data),
        .VDD(VDD), .VSS(VSS)
    );

    initial begin
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk); begin_test = 1;
        @(posedge clk); begin_test = 0;
        wait (test_done);
        if (!test_pass) $fatal(1, "FAIL: 22-pin FPGA BIST mismatch");
        $display("PASS: FPGA BIST verified the 22-pin ASIC protocol");
        $finish;
    end

    initial begin
        repeat (500) @(posedge clk);
        $fatal(1, "FAIL: FPGA BIST timeout");
    end
endmodule
