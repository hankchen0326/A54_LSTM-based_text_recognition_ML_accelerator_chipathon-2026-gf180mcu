`timescale 1ns/1ps

module tb_A54_A;
    reg        clk;
    reg        rst_n;
    reg        cmd_valid;
    reg  [7:0] cmd_data;
    wire       rsp_valid_OUT;
    wire [7:0] rsp_data_OUT;
    supply0    VSS;
    supply1    VDD;

    A54_A dut (
        .VSS(VSS),
        .VDD(VDD),
        .rsp_data_IN(8'h00),
        .rsp_valid_IN(1'b0),
        .clk(clk),
        .rst_n(rst_n),
        .cmd_valid(cmd_valid),
        .cmd_data(cmd_data),
        .rsp_valid_OUT(rsp_valid_OUT),
        .rsp_data_OUT(rsp_data_OUT)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 1'b0;
        rst_n = 1'b0;
        cmd_valid = 1'b0;
        cmd_data = 8'h00;

        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        @(negedge clk);
        cmd_data = 8'hA8;
        cmd_valid = 1'b1;
        @(posedge clk);
        #1;
        if (rsp_valid_OUT !== 1'b1 || rsp_data_OUT !== 8'hA8) begin
            $display("WRAPPER FAIL: valid=%b data=%02h", rsp_valid_OUT, rsp_data_OUT);
            $fatal(1);
        end

        $display("WRAPPER PASS: signature=%02h", rsp_data_OUT);
        @(negedge clk);
        cmd_valid = 1'b0;
        cmd_data = 8'h00;
        $finish;
    end
endmodule
