`timescale 1ns/1ps

module tb_lstm16x_top;
    reg clk;
    reg rst_n;
    reg cmd_valid;
    reg [7:0] cmd_data;
    wire rsp_valid;
    wire [7:0] rsp_data;
    wire VDD = 1'b1;
    wire VSS = 1'b0;

    integer errors;
    integer lane;
    integer timeout_cycles;
    reg signed [7:0] expected_h [0:15];
    reg signed [7:0] expected_c [0:15];

    lstm16x_top dut (
        .clk(clk), .rst_n(rst_n), .cmd_valid(cmd_valid),
        .cmd_data(cmd_data), .rsp_valid(rsp_valid), .rsp_data(rsp_data),
        .VDD(VDD), .VSS(VSS)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task send_byte;
        input [7:0] value;
        begin
            @(negedge clk);
            cmd_data = value;
            cmd_valid = 1'b1;
            @(negedge clk);
            cmd_valid = 1'b0;
        end
    endtask

    task query_byte;
        input [7:0] command;
        input signed [7:0] expected;
        begin
            send_byte(command);
            if (!rsp_valid || ($signed(rsp_data) !== expected)) begin
                $display("query %02x mismatch valid=%0d got=%0d expected=%0d",
                         command, rsp_valid, $signed(rsp_data), expected);
                errors = errors + 1;
            end
        end
    endtask

    task load_pair;
        input [7:0] command;
        input signed [7:0] value;
        begin
            send_byte(command);
            send_byte(value);
        end
    endtask

    task load_vector0;
        begin
            load_pair(8'h00,  47); load_pair(8'h01, -45);
            load_pair(8'h02,  36); load_pair(8'h03, -42);
            load_pair(8'h04,  14); load_pair(8'h05,  25);
            load_pair(8'h06, -22); load_pair(8'h07,  38);
        end
    endtask

    task load_vector1;
        begin
            load_pair(8'h00, -55); load_pair(8'h01, -26);
            load_pair(8'h02, -40); load_pair(8'h03, -10);
            load_pair(8'h04, -63); load_pair(8'h05,  46);
            load_pair(8'h06,  22); load_pair(8'h07, -13);
        end
    endtask

    task run_and_check;
        begin
            send_byte(8'h30);
            timeout_cycles = 0;
            while (!rsp_valid && timeout_cycles < 100) begin
                @(negedge clk);
                timeout_cycles = timeout_cycles + 1;
            end
            if (!rsp_valid || rsp_data !== 8'hD0) begin
                $display("FAIL: completion response missing/wrong: %02x", rsp_data);
                $fatal(1);
            end

            for (lane = 0; lane < 16; lane = lane + 1) begin
                query_byte(8'h40 | lane[7:0], expected_h[lane]);
                query_byte(8'h50 | lane[7:0], expected_c[lane]);
            end
        end
    endtask

    initial begin
        errors = 0;
        rst_n = 1'b0;
        cmd_valid = 1'b0;
        cmd_data = 8'd0;
        repeat (4) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        query_byte(8'hA8, 8'shA8);
        query_byte(8'hA9, 8'sh16);

        for (lane = 0; lane < 16; lane = lane + 1) begin
            load_pair(8'h10 | lane[7:0], lane - 8);
            load_pair(8'h20 | lane[7:0], 2 * lane - 15);
        end

        load_vector0();
        expected_h[0]  = -5; expected_c[0]  = -4;
        expected_h[1]  = -5; expected_c[1]  = -3;
        expected_h[2]  = -5; expected_c[2]  = -2;
        expected_h[3]  = -5; expected_c[3]  = -1;
        expected_h[4]  = -5; expected_c[4]  = -4;
        expected_h[5]  =  0; expected_c[5]  =  0;
        expected_h[6]  = -5; expected_c[6]  = -2;
        expected_h[7]  =  0; expected_c[7]  =  2;
        expected_h[8]  =  0; expected_c[8]  =  0;
        expected_h[9]  =  0; expected_c[9]  =  4;
        expected_h[10] = -5; expected_c[10] = -2;
        expected_h[11] =  0; expected_c[11] =  6;
        expected_h[12] = -5; expected_c[12] = -1;
        expected_h[13] =  0; expected_c[13] =  7;
        expected_h[14] =  0; expected_c[14] =  1;
        expected_h[15] =  4; expected_c[15] = 14;
        run_and_check();

        load_vector1();
        expected_h[0]  = -22; expected_c[0]  = -41;
        expected_h[1]  = -18; expected_c[1]  = -40;
        expected_h[2]  = -18; expected_c[2]  = -40;
        expected_h[3]  = -18; expected_c[3]  = -39;
        expected_h[4]  = -23; expected_c[4]  = -41;
        expected_h[5]  = -22; expected_c[5]  = -41;
        expected_h[6]  = -19; expected_c[6]  = -40;
        expected_h[7]  = -18; expected_c[7]  = -40;
        expected_h[8]  = -23; expected_c[8]  = -41;
        expected_h[9]  = -18; expected_c[9]  = -39;
        expected_h[10] = -19; expected_c[10] = -40;
        expected_h[11] = -18; expected_c[11] = -38;
        expected_h[12] = -19; expected_c[12] = -39;
        expected_h[13] = -18; expected_c[13] = -37;
        expected_h[14] = -19; expected_c[14] = -38;
        expected_h[15] = -18; expected_c[15] = -33;
        run_and_check();

        if (errors != 0) $fatal(1, "FAIL: %0d protocol/data mismatches", errors);
        $display("PASS: 22-pin lstm16x_top matches Python golden vectors");
        $finish;
    end
endmodule
