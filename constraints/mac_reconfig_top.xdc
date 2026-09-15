#-----------------------------------------------------------------------------
# File: mac_reconfig_top.xdc
# Description: Timing & Out-Of-Context Constraints for Reconfigurable MAC
#-----------------------------------------------------------------------------

# Primary Clock Constraint (100 MHz / 10ns period)
create_clock -period 10.000 -name clk -waveform {0.000 5.000} [get_ports clk]

# Input Delay Constraints (2ns setup budget)
set_input_delay -clock [get_clocks clk] -max 2.000 [get_ports {rst_n mode_8b valid_in clr_acc A_4b_* B_4b_* A_8b* B_8b*}]

# Output Delay Constraints (2ns setup budget)
set_output_delay -clock [get_clocks clk] -max 2.000 [get_ports {valid_out acc_*}]
