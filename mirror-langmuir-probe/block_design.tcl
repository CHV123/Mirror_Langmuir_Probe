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

### THE ISAT BLOCK HIERARCHY ###############################################################################
#############################################################################################################
# Adding the "Calculate Isat" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:isat_calc:1.0 isat_calc_0
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins isat_calc_0/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 iSat_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells iSat_concat]
connect_bd_net [get_bd_pins iSat_concat/dout] [get_bd_pins sts/Isaturation]
connect_bd_net [get_bd_pins isat_calc_0/iSat] [get_bd_pins iSat_concat/In0]

# Creating and setting up divider core for iSat block
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 iSat_div

set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {true}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.fractional_width {14} CONFIG.latency {18} CONFIG.dividend_tuser_width {2}] [get_bd_cells iSat_div]

connect_bd_net [get_bd_pins iSat_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins isat_calc_0/divisor] [get_bd_intf_pins iSat_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins iSat_div/M_AXIS_DOUT] [get_bd_intf_pins isat_calc_0/divider]
connect_bd_intf_net [get_bd_intf_pins isat_calc_0/dividend] [get_bd_intf_pins iSat_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Isat block
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 iSat_SPR_0

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells iSat_SPR_0]
set_property -dict [list CONFIG.Write_Width_A {14} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {14}] [get_bd_cells iSat_SPR_0]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled} CONFIG.Write_Width_B {14}] [get_bd_cells iSat_SPR_0]
set_property -dict [list CONFIG.Read_Width_B {14} CONFIG.Register_PortA_Output_of_Memory_Primitives {false}] [get_bd_cells iSat_SPR_0]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charliev/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/base_coe.coe}] [get_bd_cells iSat_SPR_0]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells iSat_SPR_0]

# Connect up the block to iSat
connect_bd_net [get_bd_pins isat_calc_0/BRAM_addr] [get_bd_pins iSat_SPR_0/addra]
connect_bd_net [get_bd_pins iSat_SPR_0/douta] [get_bd_pins isat_calc_0/BRAMret]

# Grouping the ISat cells into a hierarchy
group_bd_cells iSat_calc_hier [get_bd_cells isat_calc_0] [get_bd_cells iSat_SPR_0] [get_bd_cells iSat_div]

###############################################################################################################

#############################################################################################################
# Adding the "Calculate Vfloat" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:vfloat_calc:1.0 vfloat_calc_0
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins vfloat_calc_0/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 vfloat_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells vfloat_concat]
connect_bd_net [get_bd_pins vfloat_concat/dout] [get_bd_pins sts/vFloat]
connect_bd_net [get_bd_pins vfloat_calc_0/vfloat] [get_bd_pins vfloat_concat/In0]

# Creating and setting up divider core for vfloat block
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 vFloat_div

set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {true}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.fractional_width {14} CONFIG.latency {18} CONFIG.dividend_tuser_width {2}] [get_bd_cells vFloat_div]

connect_bd_net [get_bd_pins vFloat_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins vfloat_calc_0/divisor] [get_bd_intf_pins vFloat_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins vFloat_div/M_AXIS_DOUT] [get_bd_intf_pins vfloat_calc_0/divider]
connect_bd_intf_net [get_bd_intf_pins vfloat_calc_0/dividend] [get_bd_intf_pins vFloat_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Vfloat block
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 vfloat_SPR_0

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells vfloat_SPR_0]
set_property -dict [list CONFIG.Write_Width_A {14} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {14}] [get_bd_cells vfloat_SPR_0]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled} CONFIG.Write_Width_B {14}] [get_bd_cells vfloat_SPR_0]
set_property -dict [list CONFIG.Read_Width_B {14} CONFIG.Register_PortA_Output_of_Memory_Primitives {false}] [get_bd_cells vfloat_SPR_0]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charliev/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/base_coe.coe}] [get_bd_cells vfloat_SPR_0]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells vfloat_SPR_0]

# Connect up the block to vfloat
connect_bd_net [get_bd_pins vfloat_calc_0/BRAM_addr] [get_bd_pins vfloat_SPR_0/addra]
connect_bd_net [get_bd_pins vfloat_SPR_0/douta] [get_bd_pins vfloat_calc_0/BRAMret]

# Grouping the Vfloat cells into a hierarchy
group_bd_cells vfloat_calc_hier [get_bd_cells vfloat_calc_0] [get_bd_cells vfloat_SPR_0] [get_bd_cells vFloat_div]
###############################################################################################################

#############################################################################################################
# Adding the "Calculate Temp" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:temp_calc:1.0 temp_calc_0
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins temp_calc_0/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 temp_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells temp_concat]
connect_bd_net [get_bd_pins temp_concat/dout] [get_bd_pins sts/Temperature]
connect_bd_net [get_bd_pins temp_calc_0/temp] [get_bd_pins temp_concat/In0]

# Creating and setting up divider core for temp block
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 Temp_div

set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {true}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.fractional_width {14} CONFIG.latency {18} CONFIG.dividend_tuser_width {2}] [get_bd_cells Temp_div]

connect_bd_net [get_bd_pins Temp_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins temp_calc_0/divisor] [get_bd_intf_pins Temp_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins Temp_div/M_AXIS_DOUT] [get_bd_intf_pins temp_calc_0/divider]
connect_bd_intf_net [get_bd_intf_pins temp_calc_0/dividend] [get_bd_intf_pins Temp_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Temp block
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 temp_SPR_0

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells temp_SPR_0]
set_property -dict [list CONFIG.Write_Width_A {14} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {14}] [get_bd_cells temp_SPR_0]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled} CONFIG.Write_Width_B {14}] [get_bd_cells temp_SPR_0]
set_property -dict [list CONFIG.Read_Width_B {14} CONFIG.Register_PortA_Output_of_Memory_Primitives {false}] [get_bd_cells temp_SPR_0]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charliev/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/base_coe.coe}] [get_bd_cells temp_SPR_0]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells temp_SPR_0]

# Connect up the block to temp
connect_bd_net [get_bd_pins temp_calc_0/BRAM_addr] [get_bd_pins temp_SPR_0/addra]
connect_bd_net [get_bd_pins temp_SPR_0/douta] [get_bd_pins temp_calc_0/BRAMret]

# Grouping the Temp cells into a hierarchy
group_bd_cells temp_calc_hier [get_bd_cells temp_calc_0] [get_bd_cells temp_SPR_0] [get_bd_cells Temp_div]
###############################################################################################################

###############################################################################################################
# Making connections between calculation modules
connect_bd_net [get_bd_pins iSat_calc_hier/isat_calc_0/iSat] [get_bd_pins temp_calc_hier/temp_calc_0/iSat]
connect_bd_net [get_bd_pins temp_calc_hier/temp_calc_0/Temp] [get_bd_pins iSat_calc_hier/isat_calc_0/Temp]
connect_bd_net [get_bd_pins vfloat_calc_hier/vfloat_calc_0/vFloat] [get_bd_pins iSat_calc_hier/isat_calc_0/vFloat]
connect_bd_net [get_bd_pins iSat_calc_hier/isat_calc_0/iSat] [get_bd_pins vfloat_calc_hier/vfloat_calc_0/iSat]
connect_bd_net [get_bd_pins vfloat_calc_hier/vfloat_calc_0/vFloat] [get_bd_pins temp_calc_hier/temp_calc_0/vFloat]
connect_bd_net [get_bd_pins vfloat_calc_hier/vfloat_calc_0/Temp] [get_bd_pins temp_calc_hier/temp_calc_0/Temp]

connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins iSat_calc_hier/isat_calc_0/volt_in]
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins temp_calc_hier/temp_calc_0/volt_in]
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins vfloat_calc_hier/vfloat_calc_0/volt_in]
###############################################################################################################

#############################################################################################################
# Adding the "Set Voltage" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:set_voltage:1.0 set_voltage_0

set_property -dict [list CONFIG.period {25}] [get_bd_cells set_voltage_0]

# Setting input connections
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins set_voltage_0/adc_clk]
connect_bd_net [get_bd_pins temp_calc_hier/Temp] [get_bd_pins set_voltage_0/Temp]
connect_bd_net [get_bd_pins ctl/Period] [get_bd_pins set_voltage_0/period_in]
connect_bd_net [get_bd_pins temp_calc_hier/temp_calc_0/data_valid] [get_bd_pins set_voltage_0/Temp_valid]

# Setting output connections
connect_bd_net [get_bd_pins set_voltage_0/volt_out] [get_bd_pins adc_dac/dac1] ;# connecting output to dac1
connect_bd_net [get_bd_pins set_voltage_0/volt_out] [get_bd_pins adc_dac/dac2] ;# connecting output to dac2
connect_bd_net [get_bd_pins set_voltage_0/Temp_en] [get_bd_pins temp_calc_hier/temp_calc_0/clk_en]
connect_bd_net [get_bd_pins set_voltage_0/Isat_en] [get_bd_pins iSat_calc_hier/isat_calc_0/clk_en]
connect_bd_net [get_bd_pins set_voltage_0/vFloat_en] [get_bd_pins vfloat_calc_hier/vfloat_calc_0/clk_en]
connect_bd_net [get_bd_pins set_voltage_0/volt1] [get_bd_pins iSat_calc_hier/isat_calc_0/volt1]
connect_bd_net [get_bd_pins set_voltage_0/volt2] [get_bd_pins vfloat_calc_hier/vfloat_calc_0/volt2]
# Need slice to connect to LEDs
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 slice_volt_out_led_13_6
set_property -dict [list CONFIG.DIN_TO {6} CONFIG.DIN_FROM {13} CONFIG.DIN_WIDTH {14} CONFIG.DIN_TO {6} CONFIG.DIN_FROM {13} CONFIG.DOUT_WIDTH {8}] [get_bd_cells slice_volt_out_led_13_6]
connect_bd_net [get_bd_pins set_voltage_0/volt_out] [get_bd_pins slice_volt_out_led_13_6/Din]
connect_bd_net [get_bd_ports led_o] [get_bd_pins slice_volt_out_led_13_6/Dout]
###########################################################################################################

group_bd_cells MLP_calculations [get_bd_cells set_voltage_0] [get_bd_cells iSat_calc_hier] [get_bd_cells vfloat_calc_hier] [get_bd_cells temp_calc_hier]; #Making one big MLP block

# Making sure clocks are synchronous
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/iSat_calc_hier/isat_calc_0/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/iSat_calc_hier/isat_calc_0/divider]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/temp_calc_hier/temp_calc_0/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/temp_calc_hier/temp_calc_0/divider]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/vfloat_calc_hier/vfloat_calc_0/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/vfloat_calc_hier/vfloat_calc_0/divider]

set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/iSat_calc_hier/isat_calc_0/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/iSat_calc_hier/isat_calc_0/dividend]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/temp_calc_hier/temp_calc_0/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/temp_calc_hier/temp_calc_0/dividend]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/vfloat_calc_hier/vfloat_calc_0/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/vfloat_calc_hier/vfloat_calc_0/dividend]

set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/iSat_calc_hier/isat_calc_0/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/iSat_calc_hier/isat_calc_0/divisor]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/temp_calc_hier/temp_calc_0/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/temp_calc_hier/temp_calc_0/divisor]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins /MLP_calculations/vfloat_calc_hier/vfloat_calc_0/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins /MLP_calculations/vfloat_calc_hier/vfloat_calc_0/divisor]
##########################################################################################################
# Constant block to fill out module return values
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 module_const

set_property -dict [list CONFIG.CONST_WIDTH {18} CONFIG.CONST_VAL {0}] [get_bd_cells module_const]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins iSat_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins temp_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins vfloat_concat/In1]
###########################################################################################################

# Vector logic to get acquistion pins
create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 MLP_calculations/util_vector_logic_0
connect_bd_net [get_bd_pins MLP_calculations/set_voltage_0/Isat_en] [get_bd_pins MLP_calculations/util_vector_logic_0/Op1]
connect_bd_net [get_bd_pins MLP_calculations/set_voltage_0/vFloat_en] [get_bd_pins MLP_calculations/util_vector_logic_0/Op2]
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {or} CONFIG.LOGO_FILE {data/sym_orgate.png}] [get_bd_cells MLP_calculations/util_vector_logic_0]

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 MLP_calculations/util_vector_logic_1
connect_bd_net [get_bd_pins MLP_calculations/util_vector_logic_0/Res] [get_bd_pins MLP_calculations/util_vector_logic_1/Op1]
connect_bd_net [get_bd_pins MLP_calculations/set_voltage_0/Temp_en] [get_bd_pins MLP_calculations/util_vector_logic_1/Op2]
set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {or} CONFIG.LOGO_FILE {data/sym_orgate.png}] [get_bd_cells MLP_calculations/util_vector_logic_1]
# End of Vector logic


