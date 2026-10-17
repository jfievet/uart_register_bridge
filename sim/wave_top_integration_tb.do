
add wave -noupdate -divider {top_integration_tb}
add wave -position insertpoint sim:/top_integration_tb/*

add wave -noupdate -divider {top_integration_inst}
add wave -position insertpoint sim:/top_integration_tb/top_integration_inst/*

add wave -noupdate -divider {uart_axi_lite_bridge_inst}
add wave -position insertpoint sim:/top_integration_tb/top_integration_inst/uart_axi_lite_bridge_inst/*

add wave -noupdate -divider {axil_end_bridge_inst}
add wave -position insertpoint sim:/top_integration_tb/top_integration_inst/uart_axi_lite_bridge_inst/axil_end_bridge_inst/*

add wave -noupdate -divider {uart_inst}
add wave -position insertpoint sim:/top_integration_tb/top_integration_inst/uart_axi_lite_bridge_inst/uart_inst/*

add wave -noupdate -divider {system_module_inst}
add wave -position insertpoint sim:/top_integration_tb/top_integration_inst/system_module_inst/*

add wave -noupdate -divider {uart_bank_bridge_inst}
add wave -position insertpoint sim:/top_integration_tb/top_integration_inst/uart_bank_bridge_inst/*

config wave -signalnamewidth 1