source $board_path/config/ports.tcl

# Add PS and AXI Interconnect
set board_preset $board_path/config/board_preset.tcl
source $sdk_path/fpga/lib/starting_point.tcl

# Add ADCs and DACs
source $sdk_path/fpga/lib/redp_adc_dac.tcl
set adc_dac_name adc_dac
add_redp_adc_dac $adc_dac_name

# Rename clocks
set adc_clk $adc_dac_name/adc_clk

# Add processor system reset synchronous to adc clock
set rst_adc_clk_name proc_sys_reset_adc_clk
cell xilinx.com:ip:proc_sys_reset:5.0 $rst_adc_clk_name {} {
  ext_reset_in $ps_name/FCLK_RESET0_N
  slowest_sync_clk $adc_clk
}

# Add config and status registers
source $sdk_path/fpga/lib/ctl_sts.tcl
add_ctl_sts $adc_clk $rst_adc_clk_name/peripheral_aresetn

# Connect LEDs
#connect_port_pin led_o [get_slice_pin [ctl_pin led] 7 0]

# Connect ADC to status register
for {set i 0} {$i < [get_parameter n_adc]} {incr i} {
  connect_pins [sts_pin adc$i] adc_dac/adc[expr $i + 1]
}

# Use AXI Stream clock converter (ADC clock -> FPGA clock)
set intercon_idx 0
set idx [add_master_interface $intercon_idx]
cell xilinx.com:ip:axis_clock_converter:1.1 adc_clock_converter {
  TDATA_NUM_BYTES 4
} {
  s_axis_aresetn $rst_adc_clk_name/peripheral_aresetn
  m_axis_aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
  s_axis_aclk $adc_clk
  m_axis_aclk [set ps_clk$intercon_idx]
}

# Add AXI stream FIFO to read pulse data from the PS
cell xilinx.com:ip:axi_fifo_mm_s:4.1 adc_axis_fifo {
  C_USE_TX_DATA 0
  C_USE_TX_CTRL 0
  C_USE_RX_CUT_THROUGH true
  C_RX_FIFO_DEPTH 16384
  C_RX_FIFO_PF_THRESHOLD 8192
} {
  s_axi_aclk [set ps_clk$intercon_idx]
  s_axi_aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
  S_AXI [set interconnect_${intercon_idx}_name]/M${idx}_AXI
  AXI_STR_RXD adc_clock_converter/M_AXIS
}

assign_bd_address [get_bd_addr_segs adc_axis_fifo/S_AXI/Mem0]
set memory_segment  [get_bd_addr_segs /${::ps_name}/Data/SEG_adc_axis_fifo_Mem0]
set_property offset [get_memory_offset adc_fifo] $memory_segment
set_property range  [get_memory_range adc_fifo]  $memory_segment

#############################################################################################################
# Adding the "Set Voltage" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:set_voltage:1.0 set_voltage_0

set_property -dict [list CONFIG.period {25}] [get_bd_cells set_voltage_0]

# Setting input connections
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins set_voltage_0/adc_clk]

# Setting output connections
connect_bd_net [get_bd_pins set_voltage_0/volt_out] [get_bd_pins adc_dac/dac1] ;# connecting output to dac1
connect_bd_net [get_bd_pins set_voltage_0/volt_out] [get_bd_pins adc_dac/dac2] ;# connecting output to dac2
# Need slice to connect to LEDs
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 slice_volt_out_led_13_6
set_property -dict [list CONFIG.DIN_TO {6} CONFIG.DIN_FROM {13} CONFIG.DIN_WIDTH {14} CONFIG.DIN_TO {6} CONFIG.DIN_FROM {13} CONFIG.DOUT_WIDTH {8}] [get_bd_cells slice_volt_out_led_13_6]
connect_bd_net [get_bd_pins set_voltage_0/volt_out] [get_bd_pins slice_volt_out_led_13_6/Din]
connect_bd_net [get_bd_ports led_o] [get_bd_pins slice_volt_out_led_13_6/Dout]
###########################################################################################################

#############################################################################################################
# Adding the "Calculate Isat" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:isat_calc:1.0 isat_calc_0
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins isat_calc_0/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 iSat_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells iSat_concat]
connect_bd_net [get_bd_pins iSat_concat/dout] [get_bd_pins sts/Isaturation]
connect_bd_net [get_bd_pins isat_calc_0/iSat] [get_bd_pins iSat_concat/In0]
###########################################################################################################

#############################################################################################################
# Adding the "Calculate Temperature" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:temp_calc:1.0 temp_calc_0
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins temp_calc_0/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 temp_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells temp_concat]
connect_bd_net [get_bd_pins temp_concat/dout] [get_bd_pins sts/Temperature]
connect_bd_net [get_bd_pins temp_calc_0/temp] [get_bd_pins temp_concat/In0]
###########################################################################################################

#############################################################################################################
# Adding the "Calculate Floating potential" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:vfloat_calc:1.0 vfloat_calc_0
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins vfloat_calc_0/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 vfloat_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells vfloat_concat]
connect_bd_net [get_bd_pins vfloat_concat/dout] [get_bd_pins sts/vFloat]
connect_bd_net [get_bd_pins vfloat_calc_0/vFloat] [get_bd_pins vfloat_concat/In0]
###########################################################################################################

##########################################################################################################
# Constant block to fill out module return values
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 module_const

set_property -dict [list CONFIG.CONST_WIDTH {18} CONFIG.CONST_VAL {0}] [get_bd_cells module_const]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins iSat_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins temp_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins vfloat_concat/In1]
###########################################################################################################

###########################################################################################################
# Creating and setting up divider block
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 div_gen_0

set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {true}] [get_bd_cells div_gen_0]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {true}] [get_bd_cells div_gen_0]
set_property -dict [list CONFIG.fractional_width {14} CONFIG.latency {18} CONFIG.dividend_tuser_width {3}] [get_bd_cells div_gen_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 div_const
set_property -dict [list CONFIG.CONST_WIDTH {18} CONFIG.CONST_VAL {0}] [get_bd_cells div_const]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 divisor_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells divisor_concat]

connect_bd_net [get_bd_pins div_const/dout] [get_bd_pins divisor_concat/In1]
connect_bd_net [get_bd_pins divisor_concat/dout] [get_bd_pins div_gen_0/s_axis_divisor_tdata]
connect_bd_net [get_bd_pins isat_calc_0/divisor] [get_bd_pins divisor_concat/In0]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 dividend_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells divisor_concat]

connect_bd_net [get_bd_pins div_const/dout] [get_bd_pins dividend_concat/In1]
connect_bd_net [get_bd_pins dividend_concat/dout] [get_bd_pins div_gen_0/s_axis_dividend_tdata]
connect_bd_net [get_bd_pins isat_calc_0/dividend] [get_bd_pins dividend_concat/In0]

connect_bd_net [get_bd_pins div_gen_0/m_axis_dout_tdata] [get_bd_pins isat_calc_0/Mult1]
connect_bd_net [get_bd_pins div_gen_0/m_axis_dout_tuser] [get_bd_pins isat_calc_0/Mult1Ind]
###########################################################################################################

connect_bd_net [get_bd_pins temp_calc_0/temp] [get_bd_pins isat_calc_0/temp]
connect_bd_net [get_bd_pins vfloat_calc_0/vFloat] [get_bd_pins isat_calc_0/vFloat]
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins isat_calc_0/volt_in]


