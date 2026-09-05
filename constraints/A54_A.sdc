###############################################################################
# Created by write_sdc
###############################################################################
current_design A54_A
###############################################################################
# Timing Constraints
###############################################################################
create_clock -name core_clk -period 100.0000 [get_ports {clk}]
set_propagated_clock [get_clocks {core_clk}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[0]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[1]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[2]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[3]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[4]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[5]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[6]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_data[7]}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {cmd_valid}]
set_input_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rst_n}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[0]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[1]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[2]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[3]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[4]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[5]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[6]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_data_OUT[7]}]
set_output_delay 5.0000 -clock [get_clocks {core_clk}] -add_delay [get_ports {rsp_valid_OUT}]
set_false_path\
    -from [list [get_ports {rsp_data_IN[0]}]\
           [get_ports {rsp_data_IN[1]}]\
           [get_ports {rsp_data_IN[2]}]\
           [get_ports {rsp_data_IN[3]}]\
           [get_ports {rsp_data_IN[4]}]\
           [get_ports {rsp_data_IN[5]}]\
           [get_ports {rsp_data_IN[6]}]\
           [get_ports {rsp_data_IN[7]}]\
           [get_ports {rsp_valid_IN}]\
           [get_ports {rst_n}]]
###############################################################################
# Environment
###############################################################################
###############################################################################
# Design Rules
###############################################################################
