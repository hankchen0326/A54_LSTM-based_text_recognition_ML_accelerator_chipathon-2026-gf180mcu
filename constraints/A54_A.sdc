create_clock [get_ports clk] -name core_clk -period 100.0

set_input_delay 5.0 -clock [get_clocks core_clk] \
    [get_ports {rst_n cmd_valid cmd_data[*]}]
set_output_delay 5.0 -clock [get_clocks core_clk] \
    [get_ports {rsp_valid_OUT rsp_data_OUT[*]}]

set_false_path -from [get_ports rst_n]
set_false_path -from [get_ports {rsp_valid_IN rsp_data_IN[*]}]
