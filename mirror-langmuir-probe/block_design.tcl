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
  TDATA_NUM_BYTES 8
} {
  s_axis_aresetn $rst_adc_clk_name/peripheral_aresetn
  m_axis_aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
  s_axis_aclk $adc_clk
  m_axis_aclk [set ps_clk$intercon_idx]
}

# Add AXI stream width converter to write data to AXI LITE FIFO
cell xilinx.com:ip:axis_dwidth_converter:1.1 adc_dwidth_converter {
    S_TDATA_NUM_BYTES 8
    M_TDATA_NUM_BYTES 4
} {
  aclk [set ps_clk$intercon_idx]
  aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
  S_AXIS adc_clock_converter/M_AXIS
}    

# Add AXI stream FIFO to read pulse data from the PS
cell xilinx.com:ip:axi_fifo_mm_s:4.1 adc_axis_fifo {
  C_USE_TX_DATA 0
  C_USE_TX_CTRL 0
  C_USE_RX_CUT_THROUGH true
  C_RX_FIFO_DEPTH 32768
  C_RX_FIFO_PF_THRESHOLD 32763
} {
  s_axi_aclk [set ps_clk$intercon_idx]
  s_axi_aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
  S_AXI [set interconnect_${intercon_idx}_name]/M${idx}_AXI
  AXI_STR_RXD adc_dwidth_converter/M_AXIS
}

assign_bd_address [get_bd_addr_segs adc_axis_fifo/S_AXI/Mem0]
set memory_segment  [get_bd_addr_segs /${::ps_name}/Data/SEG_adc_axis_fifo_Mem0]
set_property offset [get_memory_offset adc_fifo] $memory_segment
set_property range  [get_memory_range adc_fifo]  $memory_segment


#############################################################################################################
# Adding the "Calculate Isat" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:isat_calc:1.0 isat_calc
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins isat_calc/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 iSat_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells iSat_concat]
connect_bd_net [get_bd_pins iSat_concat/dout] [get_bd_pins sts/Isaturation]
connect_bd_net [get_bd_pins isat_calc/iSat] [get_bd_pins iSat_concat/In0]

# Creating and setting up divider core for iSat block
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 iSat_div

set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {true}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.remainder_type {Fractional} CONFIG.fractional_width {12}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.latency {30} CONFIG.dividend_tuser_width {2}] [get_bd_cells iSat_div]

connect_bd_net [get_bd_pins iSat_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins isat_calc/divisor] [get_bd_intf_pins iSat_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins iSat_div/M_AXIS_DOUT] [get_bd_intf_pins isat_calc/divider]
connect_bd_intf_net [get_bd_intf_pins isat_calc/dividend] [get_bd_intf_pins iSat_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Isat block
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 iSat_SPR

connect_bd_net [get_bd_pins iSat_SPR/clka] [get_bd_pins adc_dac/adc_clk]

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {16}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charliev/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/cores/isat_calc_v1_0/iSat_lut.coe}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells iSat_SPR]

# Connect up the block to iSat
connect_bd_net [get_bd_pins isat_calc/BRAM_addr] [get_bd_pins iSat_SPR/addra]
connect_bd_net [get_bd_pins iSat_SPR/douta] [get_bd_pins isat_calc/BRAMret]

###############################################################################################################

#############################################################################################################
# Adding the "Calculate Vfloat" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:vfloat_calc:1.0 vfloat_calc
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins vfloat_calc/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 vfloat_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells vfloat_concat]
connect_bd_net [get_bd_pins vfloat_concat/dout] [get_bd_pins sts/vFloat]
connect_bd_net [get_bd_pins vfloat_calc/vfloat] [get_bd_pins vfloat_concat/In0]

# Creating and setting up divider core for vfloat block
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 vFloat_div

set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {true}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.remainder_type {Fractional} CONFIG.fractional_width {12}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.latency {30} CONFIG.dividend_tuser_width {2}] [get_bd_cells vFloat_div]

connect_bd_net [get_bd_pins vFloat_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins vfloat_calc/divisor] [get_bd_intf_pins vFloat_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins vFloat_div/M_AXIS_DOUT] [get_bd_intf_pins vfloat_calc/divider]
connect_bd_intf_net [get_bd_intf_pins vfloat_calc/dividend] [get_bd_intf_pins vFloat_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Vfloat block
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 vfloat_SPR

connect_bd_net [get_bd_pins vfloat_SPR/clka] [get_bd_pins adc_dac/adc_clk]

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells vfloat_SPR]
set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {16}] [get_bd_cells vfloat_SPR]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled}] [get_bd_cells vfloat_SPR]
set_property -dict [list CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_bd_cells vfloat_SPR]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charliev/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/cores/vfloat_calc_v1_0/ln_lut.coe}] [get_bd_cells vfloat_SPR]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells vfloat_SPR]

# Connect up the block to vfloat
connect_bd_net [get_bd_pins vfloat_calc/BRAM_addr] [get_bd_pins vfloat_SPR/addra]
connect_bd_net [get_bd_pins vfloat_SPR/douta] [get_bd_pins vfloat_calc/BRAMret]

###############################################################################################################

#############################################################################################################
# Adding the "Calculate Temp" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:temp_calc:1.0 temp_calc
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins temp_calc/adc_clk]

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 temp_concat
set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells temp_concat]
connect_bd_net [get_bd_pins temp_concat/dout] [get_bd_pins sts/Temperature]
connect_bd_net [get_bd_pins temp_calc/temp] [get_bd_pins temp_concat/In0]

# Creating and setting up divider core for temp block
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 Temp_div

set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {true}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.remainder_type {Fractional} CONFIG.fractional_width {12}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.latency {30} CONFIG.dividend_tuser_width {2}] [get_bd_cells Temp_div]

connect_bd_net [get_bd_pins Temp_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins temp_calc/divisor] [get_bd_intf_pins Temp_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins Temp_div/M_AXIS_DOUT] [get_bd_intf_pins temp_calc/divider]
connect_bd_intf_net [get_bd_intf_pins temp_calc/dividend] [get_bd_intf_pins Temp_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Temp block
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 temp_SPR

connect_bd_net [get_bd_pins temp_SPR/clka] [get_bd_pins adc_dac/adc_clk]

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells temp_SPR]
set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {16}] [get_bd_cells temp_SPR]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled}] [get_bd_cells temp_SPR]
set_property -dict [list CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_bd_cells temp_SPR]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charliev/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/cores/temp_calc_v1_0/oneLn_lut.coe}] [get_bd_cells temp_SPR]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells temp_SPR]

# Connect up the block to temp
connect_bd_net [get_bd_pins temp_calc/BRAM_addr] [get_bd_pins temp_SPR/addra]
connect_bd_net [get_bd_pins temp_SPR/douta] [get_bd_pins temp_calc/BRAMret]

###############################################################################################################

###############################################################################################################
# Making connections between calculation modules
connect_bd_net [get_bd_pins isat_calc/iSat] [get_bd_pins temp_calc/iSat]
connect_bd_net [get_bd_pins temp_calc/Temp] [get_bd_pins isat_calc/Temp]
connect_bd_net [get_bd_pins vfloat_calc/vFloat] [get_bd_pins isat_calc/vFloat]
connect_bd_net [get_bd_pins isat_calc/iSat] [get_bd_pins vfloat_calc/iSat]
connect_bd_net [get_bd_pins vfloat_calc/vFloat] [get_bd_pins temp_calc/vFloat]
connect_bd_net [get_bd_pins vfloat_calc/Temp] [get_bd_pins temp_calc/Temp]

connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins isat_calc/volt_in]
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins temp_calc/volt_in]
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins vfloat_calc/volt_in]
###############################################################################################################

#############################################################################################################
# Adding the "Set Voltage" ip and making the appropriate connections
create_bd_cell -type ip -vlnv PSFC:user:set_voltage:1.0 set_voltage

set_property -dict [list CONFIG.period {40} CONFIG.Temp_guess {20} CONFIG.Negbias {-3} CONFIG.Posbias {1}] [get_bd_cells set_voltage]

# Setting input connections
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins set_voltage/adc_clk]
connect_bd_net [get_bd_pins temp_calc/Temp] [get_bd_pins set_voltage/Temp]
connect_bd_net [get_bd_pins ctl/Period] [get_bd_pins set_voltage/period_in]
connect_bd_net [get_bd_pins temp_calc/data_valid] [get_bd_pins set_voltage/Temp_valid]

# Setting output connections
connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins adc_dac/dac1] ;# connecting output to dac1
connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins adc_dac/dac2] ;# connecting output to dac2
connect_bd_net [get_bd_pins set_voltage/Temp_en] [get_bd_pins temp_calc/clk_en]
connect_bd_net [get_bd_pins set_voltage/Isat_en] [get_bd_pins isat_calc/clk_en]
connect_bd_net [get_bd_pins set_voltage/vFloat_en] [get_bd_pins vfloat_calc/clk_en]
connect_bd_net [get_bd_pins set_voltage/volt1] [get_bd_pins isat_calc/volt1]
connect_bd_net [get_bd_pins set_voltage/volt2] [get_bd_pins temp_calc/volt2]

###########################################################################################################

# Making sure clocks are synchronous
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins isat_calc/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins isat_calc/divider]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins temp_calc/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins temp_calc/divider]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins vfloat_calc/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins vfloat_calc/divider]

set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins isat_calc/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins isat_calc/dividend]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins temp_calc/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins temp_calc/dividend]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins vfloat_calc/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins vfloat_calc/dividend]

set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins isat_calc/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins isat_calc/divisor]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins temp_calc/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins temp_calc/divisor]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins vfloat_calc/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins vfloat_calc/divisor]

# Grouping into a Hierarchy
group_bd_cells MLP_calc [get_bd_cells temp_SPR] [get_bd_cells vFloat_div] [get_bd_cells set_voltage] [get_bd_cells temp_calc] [get_bd_cells vfloat_calc] [get_bd_cells isat_calc] [get_bd_cells Temp_div] [get_bd_cells iSat_SPR] [get_bd_cells iSat_div] [get_bd_cells vfloat_SPR]

##########################################################################################################
# Constant block to fill out module return values
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 module_const

set_property -dict [list CONFIG.CONST_WIDTH {18} CONFIG.CONST_VAL {0}] [get_bd_cells module_const]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins iSat_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins temp_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins vfloat_concat/In1]
###########################################################################################################

###########################################################################################################
# Instantiate and connect data collector
create_bd_cell -type ip -vlnv PSFC:user:data_collector:1.0 data_collector

connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins data_collector/adc_clk]

connect_bd_net [get_bd_pins MLP_calc/Temp] [get_bd_pins data_collector/Temp]
connect_bd_net [get_bd_pins MLP_calc/vFloat] [get_bd_pins data_collector/vFloat]
connect_bd_net [get_bd_pins MLP_calc/iSat] [get_bd_pins data_collector/iSat]
connect_bd_net [get_bd_pins MLP_calc/temp_calc/data_valid] [get_bd_pins data_collector/Temp_valid]
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins data_collector/v_in]
connect_bd_net [get_bd_pins adc_dac/adc2] [get_bd_pins data_collector/v_out]

connect_bd_net [get_bd_pins data_collector/tdata] [get_bd_pins adc_clock_converter/s_axis_tdata]
connect_bd_net [get_bd_pins data_collector/tvalid] [get_bd_pins adc_clock_converter/s_axis_tvalid]

set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins data_collector/interface_axis]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins data_collector/interface_axis]
###########################################################################################################

###########################################################################################################
# Instantiate and connect acquisition trigger block
create_bd_cell -type ip -vlnv PSFC:user:acquire_trigger:1.0 acquire_trigger

connect_bd_net [get_bd_pins acquire_trigger/adc_clk] [get_bd_pins adc_dac/adc_clk]

connect_bd_net [get_bd_pins ctl/Acquisition_length] [get_bd_pins acquire_trigger/AcqTime]
connect_bd_net [get_bd_pins acquire_trigger/acquire_valid] [get_bd_pins data_collector/clk_en]
connect_bd_net [get_bd_pins acquire_trigger/timestamp] [get_bd_pins sts/Timestamp]

# Taking a bit from the trigger to implement the acquisition trigger
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 trigger_to_trigger
connect_bd_net [get_bd_pins ctl/Trigger] [get_bd_pins trigger_to_trigger/Din]
connect_bd_net [get_bd_pins trigger_to_trigger/Dout] [get_bd_pins acquire_trigger/trigger]
set_property -dict [list CONFIG.DIN_TO {0} CONFIG.DIN_FROM {0} CONFIG.DOUT_WIDTH {1} CONFIG.DIN_WIDTH {32}] [get_bd_cells trigger_to_trigger]

# Need slice to connect to LEDs
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 led_slice
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 led_concat
set_property -dict [list CONFIG.DIN_TO {0} CONFIG.DIN_FROM {6} CONFIG.DIN_WIDTH {18} CONFIG.DOUT_WIDTH {6}] [get_bd_cells led_slice]
set_property -dict [list CONFIG.IN0_WIDTH {1} CONFIG.IN1_WIDTH {7}] [get_bd_cells led_concat]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins led_slice/Din]
connect_bd_net [get_bd_pins led_slice/Dout] [get_bd_pins led_concat/In0]
connect_bd_net [get_bd_pins data_collector/tvalid] [get_bd_pins led_concat/In1]
connect_bd_net [get_bd_ports led_o] [get_bd_pins led_concat/Dout]

validate_bd_design

