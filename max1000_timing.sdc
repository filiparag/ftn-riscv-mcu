# Create input clock which is 12MHz.
#create_clock -name i_clk -period 83.333 [get_ports {i_clk}]
create_clock -name {i_clk} -period 83.333 -waveform { 0.000 41.666 } [get_ports {i_clk}]

derive_pll_clocks
derive_clock_uncertainty

# Do not do any timming optimization on pins.
set_false_path -from {pll1|altpll_component|auto_generated|pll1|clk[0]} -to {pll1|altpll_component|auto_generated|pll1|clk[1]}
set_false_path -from {pll1|altpll_component|auto_generated|pll1|clk[1]} -to {pll1|altpll_component|auto_generated|pll1|clk[0]}
#set_false_path -from {pll1|basicpll|clk[0]} -to {pll1|basicpll|clk[1]}
#set_false_path -from {pll1|basicpll|clk[1]} -to {pll1|basicpll|clk[0]}
set_false_path -from [get_ports {i*}]
set_false_path -from * -to [get_ports {o*}]

#**************************************************************
# Set Input and Output Delay
#**************************************************************

set_input_delay -add_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.000 [all_inputs]
set_output_delay -add_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[0]}]  0.000 [all_outputs]

set_input_delay -add_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.000 [all_inputs]
set_output_delay -add_delay -clock [get_clocks {pll1|altpll_component|auto_generated|pll1|clk[1]}]  0.000 [all_outputs]

#set_input_delay -add_delay -clock [get_clocks {pll1|basicpll|clk[0]}]  0.000 [all_inputs]
#set_output_delay -add_delay -clock [get_clocks {pll1|basicpll|clk[0]}]  0.000 [all_outputs]

#set_input_delay -add_delay -clock [get_clocks {pll1|basicpll|clk[1]}]  0.000 [all_inputs]
#set_output_delay -add_delay -clock [get_clocks {pll1|basicpll|clk[1]}]  0.000 [all_outputs]
