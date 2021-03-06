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

# # Add AXI stream width converter to write data to AXI LITE FIFO
# cell xilinx.com:ip:axis_dwidth_converter:1.1 adc_dwidth_converter {
#     S_TDATA_NUM_BYTES 8
#     M_TDATA_NUM_BYTES 4
# } {
#   aclk [set ps_clk$intercon_idx]
#   aresetn [set rst${intercon_idx}_name]/peripheral_aresetn
#   S_AXIS adc_clock_converter/M_AXIS
# }


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
  AXI_STR_RXD adc_clock_converter/M_AXIS
}

assign_bd_address [get_bd_addr_segs adc_axis_fifo/S_AXI/Mem0]
set memory_segment  [get_bd_addr_segs /${::ps_name}/Data/SEG_adc_axis_fifo_Mem0]
set_property offset [get_memory_offset adc_fifo] $memory_segment
set_property range  [get_memory_range adc_fifo]  $memory_segment

####################################################################################################
# Instantiating  all the needed blocks and ports
create_bd_port -dir I Ext_trigger

create_bd_cell -type ip -vlnv PSFC:user:isat_calc:1.0 iSat_calc
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 iSat_concat
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 iSat_div
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 iSat_SPR

create_bd_cell -type ip -vlnv PSFC:user:vfloat_calc:1.0 vFloat_calc
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 vFloat_concat
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 vFloat_div
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 vFloat_SPR

create_bd_cell -type ip -vlnv PSFC:user:temp_calc:1.0 Temp_calc
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 Temp_concat
create_bd_cell -type ip -vlnv xilinx.com:ip:div_gen:5.1 Temp_div
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 Temp_SPR

create_bd_cell -type ip -vlnv PSFC:user:set_voltage:1.0 set_voltage
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 output_slice

create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 module_const

create_bd_cell -type ip -vlnv PSFC:user:manual_calibration:1.0 calibrate_LB
create_bd_cell -type ip -vlnv PSFC:user:manual_calibration:1.0 calibrate_PC

create_bd_cell -type ip -vlnv PSFC:user:data_collector:1.0 data_collector
create_bd_cell -type ip -vlnv PSFC:user:acquire_trigger:1.0 acquire_trigger
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 trigger_to_trigger

create_bd_cell -type ip -vlnv PSFC:user:output_mux:1.0 output_mux
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 trigger_to_mux

create_bd_cell -type ip -vlnv xilinx.com:ip:util_vector_logic:2.0 trigger_OR

create_bd_cell -type ip -vlnv PSFC:user:moving_average:1.0 moving_average_PC
create_bd_cell -type ip -vlnv PSFC:user:moving_average:1.0 moving_average_LB
#############################################################################################################
# Adding the "Calculate Isat" ip and making the appropriate connections
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins iSat_calc/adc_clk]

set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells iSat_concat]
connect_bd_net [get_bd_pins iSat_concat/dout] [get_bd_pins sts/Isaturation]
connect_bd_net [get_bd_pins iSat_calc/iSat] [get_bd_pins iSat_concat/In0]

# Creating and setting up divider core for iSat block
set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {false}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.remainder_type {Fractional} CONFIG.fractional_width {10}] [get_bd_cells iSat_div]
set_property -dict [list CONFIG.latency {28}] [get_bd_cells iSat_div]

connect_bd_net [get_bd_pins iSat_div/aclk] [get_bd_pins adc_dac/adc_clk]
connect_bd_intf_net [get_bd_intf_pins iSat_calc/divisor] [get_bd_intf_pins iSat_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins iSat_div/M_AXIS_DOUT] [get_bd_intf_pins iSat_calc/divider]
connect_bd_intf_net [get_bd_intf_pins iSat_calc/dividend] [get_bd_intf_pins iSat_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Isat block
connect_bd_net [get_bd_pins iSat_SPR/clka] [get_bd_pins adc_dac/adc_clk]

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {16}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charlesv/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/cores/isat_calc_v1_0/iSat_lut.coe}] [get_bd_cells iSat_SPR]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells iSat_SPR]

# Connect up the block to iSat
connect_bd_net [get_bd_pins iSat_calc/BRAM_addr] [get_bd_pins iSat_SPR/addra]
connect_bd_net [get_bd_pins iSat_SPR/douta] [get_bd_pins iSat_calc/BRAMret]
###############################################################################################################

#############################################################################################################
# Adding the "Calculate VFloat" ip and making the appropriate connections
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins vFloat_calc/adc_clk]

set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells vFloat_concat]
connect_bd_net [get_bd_pins vFloat_concat/dout] [get_bd_pins sts/vFloat]
connect_bd_net [get_bd_pins vFloat_calc/vFloat] [get_bd_pins vFloat_concat/In0]

# Creating and setting up divider core for vFloat block
set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {false}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.remainder_type {Fractional} CONFIG.fractional_width {10}] [get_bd_cells vFloat_div]
set_property -dict [list CONFIG.latency {28}] [get_bd_cells vFloat_div]

connect_bd_net [get_bd_pins vFloat_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins vFloat_calc/divisor] [get_bd_intf_pins vFloat_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins vFloat_div/M_AXIS_DOUT] [get_bd_intf_pins vFloat_calc/divider]
connect_bd_intf_net [get_bd_intf_pins vFloat_calc/dividend] [get_bd_intf_pins vFloat_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the VFloat block
connect_bd_net [get_bd_pins vFloat_SPR/clka] [get_bd_pins adc_dac/adc_clk]

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells vFloat_SPR]
set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {16}] [get_bd_cells vFloat_SPR]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled}] [get_bd_cells vFloat_SPR]
set_property -dict [list CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_bd_cells vFloat_SPR]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charlesv/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/cores/vfloat_calc_v1_0/vFloat_lut.coe}] [get_bd_cells vFloat_SPR]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells vFloat_SPR]

# Connect up the block to vFloat
connect_bd_net [get_bd_pins vFloat_calc/BRAM_addr] [get_bd_pins vFloat_SPR/addra]
connect_bd_net [get_bd_pins vFloat_SPR/douta] [get_bd_pins vFloat_calc/BRAMret]
###############################################################################################################

#############################################################################################################
# Adding the "Calculate Temp" ip and making the appropriate connections
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins Temp_calc/adc_clk]

set_property -dict [list CONFIG.IN0_WIDTH {14} CONFIG.IN1_WIDTH {18}] [get_bd_cells Temp_concat]
connect_bd_net [get_bd_pins Temp_concat/dout] [get_bd_pins sts/Temperature]
connect_bd_net [get_bd_pins Temp_calc/Temp] [get_bd_pins Temp_concat/In0]

# Creating and setting up divider core for Temp block
set_property -dict [list CONFIG.dividend_and_quotient_width {14} CONFIG.dividend_has_tuser {false}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.divisor_width {14} CONFIG.divide_by_zero_detect {false}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.remainder_type {Fractional} CONFIG.fractional_width {12}] [get_bd_cells Temp_div]
set_property -dict [list CONFIG.latency {30}] [get_bd_cells Temp_div]

connect_bd_net [get_bd_pins Temp_div/aclk] [get_bd_pins adc_dac/adc_clk]

connect_bd_intf_net [get_bd_intf_pins Temp_calc/divisor] [get_bd_intf_pins Temp_div/S_AXIS_DIVISOR]
connect_bd_intf_net [get_bd_intf_pins Temp_div/M_AXIS_DOUT] [get_bd_intf_pins Temp_calc/divider]
connect_bd_intf_net [get_bd_intf_pins Temp_calc/dividend] [get_bd_intf_pins Temp_div/S_AXIS_DIVIDEND]

# Creating the BRAM for the Temp block
connect_bd_net [get_bd_pins Temp_SPR/clka] [get_bd_pins adc_dac/adc_clk]

set_property -dict [list CONFIG.Enable_32bit_Address {false} CONFIG.use_bram_block {Stand_Alone}] [get_bd_cells Temp_SPR]
set_property -dict [list CONFIG.Write_Width_A {16} CONFIG.Write_Depth_A {16384} CONFIG.Read_Width_A {16}] [get_bd_cells Temp_SPR]
set_property -dict [list CONFIG.Operating_Mode_A {READ_FIRST} CONFIG.Enable_A {Always_Enabled}] [get_bd_cells Temp_SPR]
set_property -dict [list CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_bd_cells Temp_SPR]
set_property -dict [list CONFIG.Load_Init_File {true} CONFIG.Coe_File {/home/charlesv/MLP_project/koheron-sdk/instruments/mirror-langmuir-probe/cores/temp_calc_v1_0/Temp_lut.coe}] [get_bd_cells Temp_SPR]
set_property -dict [list CONFIG.Fill_Remaining_Memory_Locations {true} CONFIG.Use_RSTA_Pin {false}] [get_bd_cells Temp_SPR]

# Connect up the block to Temp
connect_bd_net [get_bd_pins Temp_calc/BRAM_addr] [get_bd_pins Temp_SPR/addra]
connect_bd_net [get_bd_pins Temp_SPR/douta] [get_bd_pins Temp_calc/BRAMret]
###############################################################################################################

###############################################################################################################
# Making connections between calculation modules
connect_bd_net [get_bd_pins iSat_calc/iSat] [get_bd_pins Temp_calc/iSat]
connect_bd_net [get_bd_pins Temp_calc/Temp] [get_bd_pins iSat_calc/Temp]
connect_bd_net [get_bd_pins vFloat_calc/vFloat] [get_bd_pins iSat_calc/vFloat]
connect_bd_net [get_bd_pins iSat_calc/iSat] [get_bd_pins vFloat_calc/iSat]
connect_bd_net [get_bd_pins vFloat_calc/vFloat] [get_bd_pins Temp_calc/vFloat]
connect_bd_net [get_bd_pins vFloat_calc/Temp] [get_bd_pins Temp_calc/Temp]

#############################################################################################################
# Adding the "Set Voltage" ip and making the appropriate connections
set_property -dict [list CONFIG.period {40} CONFIG.Temp_guess {100} CONFIG.Negbias {-3} CONFIG.Posbias {1}] [get_bd_cells set_voltage]

# Setting input connections
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins set_voltage/adc_clk]
connect_bd_net [get_bd_pins Temp_calc/Temp] [get_bd_pins set_voltage/Temp]
connect_bd_net [get_bd_pins ctl/Period] [get_bd_pins set_voltage/period_in]
connect_bd_net [get_bd_pins Temp_calc/data_valid] [get_bd_pins set_voltage/Temp_valid]

# Setting output connections
connect_bd_net [get_bd_pins set_voltage/Temp_en] [get_bd_pins Temp_calc/clk_en]
connect_bd_net [get_bd_pins set_voltage/Isat_en] [get_bd_pins iSat_calc/clk_en]
connect_bd_net [get_bd_pins set_voltage/vFloat_en] [get_bd_pins vFloat_calc/clk_en]

# connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins adc_dac/dac1]
# connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins adc_dac/dac2]

# connect_bd_net [get_bd_pins output_slice/dout] [get_bd_pins adc_dac/dac1]
# connect_bd_net [get_bd_pins output_slice/dout] [get_bd_pins adc_dac/dac2]

set_property -dict [list CONFIG.DIN_FROM {13} CONFIG.DOUT_WIDTH {14}] [get_bd_cells output_slice]
connect_bd_net [get_bd_pins output_slice/din] [get_bd_pins ctl/led]
###########################################################################################################
# Making sure clocks are synchronous
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins iSat_calc/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins iSat_calc/divider]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins Temp_calc/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins Temp_calc/divider]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins vFloat_calc/divider]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins vFloat_calc/divider]

set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins iSat_calc/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins iSat_calc/dividend]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins Temp_calc/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins Temp_calc/dividend]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins vFloat_calc/dividend]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins vFloat_calc/dividend]

set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins iSat_calc/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins iSat_calc/divisor]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins Temp_calc/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins Temp_calc/divisor]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins vFloat_calc/divisor]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins vFloat_calc/divisor]
##########################################################################################################
# Constant block to fill out module return values
set_property -dict [list CONFIG.CONST_WIDTH {18} CONFIG.CONST_VAL {0}] [get_bd_cells module_const]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins iSat_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins Temp_concat/In1]
connect_bd_net [get_bd_pins module_const/dout] [get_bd_pins vFloat_concat/In1]
###########################################################################################################

##################################################################################################################
# Adding the Manual Calibration block for the loopback
connect_bd_net [get_bd_pins calibrate_LB/adc_clk] [get_bd_pins adc_dac/adc_clk]
# connect_bd_net [get_bd_pins moving_average_LB/volt_out] [get_bd_pins calibrate_LB/volt_in];
connect_bd_net [get_bd_pins adc_dac/adc2] [get_bd_pins calibrate_LB/volt_in]
# connect_bd_net [get_bd_pins calibrate_LB/volt_out] [get_bd_pins iSat_calc/volt1]
# connect_bd_net [get_bd_pins calibrate_LB/volt_out] [get_bd_pins Temp_calc/volt2]
# connect_bd_net [get_bd_pins calibrate_LB/volt_out] [get_bd_pins vFloat_calc/volt3]
connect_bd_net [get_bd_pins ctl/Scale_LB] [get_bd_pins calibrate_LB/scale]
connect_bd_net [get_bd_pins ctl/Offset_LB] [get_bd_pins calibrate_LB/offset]
# connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins iSat_calc/volt1]
# connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins Temp_calc/volt2]
# connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins vFloat_calc/volt3]


# Adding the Manual Calibration block for the Plasma current
connect_bd_net [get_bd_pins calibrate_PC/adc_clk] [get_bd_pins adc_dac/adc_clk]
# connect_bd_net [get_bd_pins moving_average_PC/volt_out] [get_bd_pins calibrate_PC/volt_in]
connect_bd_net [get_bd_pins adc_dac/adc1] [get_bd_pins calibrate_PC/volt_in]
# connect_bd_net [get_bd_pins calibrate_PC/volt_out] [get_bd_pins iSat_calc/volt_in]
# connect_bd_net [get_bd_pins calibrate_PC/volt_out] [get_bd_pins Temp_calc/volt_in]
# connect_bd_net [get_bd_pins calibrate_PC/volt_out] [get_bd_pins vFloat_calc/volt_in]
connect_bd_net [get_bd_pins ctl/Scale_PC] [get_bd_pins calibrate_PC/scale]
connect_bd_net [get_bd_pins ctl/Offset_PC] [get_bd_pins calibrate_PC/offset]
##################################################################################################################

##################################################################################################################
# adding connections for the moving average cores
connect_bd_net [get_bd_pins moving_average_LB/adc_clk] [get_bd_pins adc_dac/adc_clk]
connect_bd_net [get_bd_pins moving_average_LB/volt_in] [get_bd_pins calibrate_LB/volt_out]
connect_bd_net [get_bd_pins moving_average_LB/clk_rst] [get_bd_pins acquire_trigger/clear_pulse]

connect_bd_net [get_bd_pins moving_average_PC/adc_clk] [get_bd_pins adc_dac/adc_clk]
connect_bd_net [get_bd_pins moving_average_PC/volt_in] [get_bd_pins calibrate_PC/volt_out]
connect_bd_net [get_bd_pins moving_average_PC/clk_rst] [get_bd_pins acquire_trigger/clear_pulse]

connect_bd_net [get_bd_pins moving_average_LB/volt_out] [get_bd_pins iSat_calc/volt1]
connect_bd_net [get_bd_pins moving_average_LB/volt_out] [get_bd_pins Temp_calc/volt2]
connect_bd_net [get_bd_pins moving_average_LB/volt_out] [get_bd_pins vFloat_calc/volt3]

connect_bd_net [get_bd_pins moving_average_PC/volt_out] [get_bd_pins iSat_calc/volt_in]
connect_bd_net [get_bd_pins moving_average_PC/volt_out] [get_bd_pins Temp_calc/volt_in]
connect_bd_net [get_bd_pins moving_average_PC/volt_out] [get_bd_pins vFloat_calc/volt_in]
##################################################################################################################

###########################################################################################################
# Instantiate and connect data collector
connect_bd_net [get_bd_pins adc_dac/adc_clk] [get_bd_pins data_collector/adc_clk]
connect_bd_net [get_bd_pins Temp_calc/Temp] [get_bd_pins data_collector/Temp]
connect_bd_net [get_bd_pins vFloat_calc/vFloat] [get_bd_pins data_collector/vFloat]
connect_bd_net [get_bd_pins iSat_calc/iSat] [get_bd_pins data_collector/iSat]
connect_bd_net [get_bd_pins Temp_calc/data_valid] [get_bd_pins data_collector/Temp_valid]
# connect_bd_net [get_bd_pins Temp_SPR/douta] [get_bd_pins data_collector/vFloat]
# connect_bd_net [get_bd_pins Temp_calc/BRAM_addr] [get_bd_pins data_collector/iSat]
# connect_bd_net [get_bd_pins set_voltage/Temp_en] [get_bd_pins data_collector/Temp_valid]
connect_bd_net [get_bd_pins moving_average_LB/volt_out] [get_bd_pins data_collector/v_out]
connect_bd_net [get_bd_pins moving_average_PC/volt_out] [get_bd_pins data_collector/v_in]
# connect_bd_net [get_bd_pins set_voltage/volt_out] [get_bd_pins data_collector/v_in]
connect_bd_net [get_bd_pins data_collector/tdata] [get_bd_pins adc_clock_converter/s_axis_tdata]
connect_bd_net [get_bd_pins data_collector/tvalid] [get_bd_pins adc_clock_converter/s_axis_tvalid]
connect_bd_net [get_bd_pins data_collector/volt_valid] [get_bd_pins set_voltage/store_en]
set_property CONFIG.FREQ_HZ 125000000 [get_bd_intf_pins data_collector/interface_axis]
set_property CONFIG.CLK_DOMAIN system_pll_0_clk_out1 [get_bd_intf_pins data_collector/interface_axis]
###########################################################################################################

###########################################################################################################
# Instantiate and connect acquisition trigger block
connect_bd_net [get_bd_pins acquire_trigger/adc_clk] [get_bd_pins adc_dac/adc_clk]
connect_bd_net [get_bd_pins ctl/Acquisition_length] [get_bd_pins acquire_trigger/AcqTime]
connect_bd_net [get_bd_pins acquire_trigger/acquire_valid] [get_bd_pins data_collector/clk_en]
connect_bd_net [get_bd_pins acquire_trigger/timestamp] [get_bd_pins sts/Timestamp]
connect_bd_net [get_bd_pins acquire_trigger/clear_pulse] [get_bd_pins Temp_calc/clk_rst]
connect_bd_net [get_bd_pins acquire_trigger/clear_pulse] [get_bd_pins iSat_calc/clk_rst]
connect_bd_net [get_bd_pins acquire_trigger/clear_pulse] [get_bd_pins vFloat_calc/clk_rst]
connect_bd_net [get_bd_pins acquire_trigger/clear_pulse] [get_bd_pins set_voltage/clk_rst]
connect_bd_net [get_bd_pins acquire_trigger/clear_pulse] [get_bd_pins calibrate_LB/clk_rst]
connect_bd_net [get_bd_pins acquire_trigger/clear_pulse] [get_bd_pins calibrate_PC/clk_rst]

# Taking a bit from the trigger to implement the acquisition trigger and OR gate with the external trigger

set_property -dict [list CONFIG.C_SIZE {1} CONFIG.C_OPERATION {or}] [get_bd_cells trigger_OR]
set_property -dict [list CONFIG.DIN_TO {0} CONFIG.DIN_FROM {0} CONFIG.DIN_WIDTH {32}] [get_bd_cells trigger_to_trigger]

connect_bd_net [get_bd_ports Ext_trigger] [get_bd_pins trigger_OR/Op1]
connect_bd_net [get_bd_pins ctl/Trigger] [get_bd_pins trigger_to_trigger/Din]
connect_bd_net [get_bd_pins trigger_to_trigger/Dout] [get_bd_pins trigger_OR/Op2]
connect_bd_net [get_bd_pins trigger_OR/Res] [get_bd_pins acquire_trigger/trigger]
##################################################################################################################

##################################################################################################################
# Connecting a multiplexer for constant voltage to assist in calibration
connect_bd_net [get_bd_pins output_mux/signal_1] [get_bd_pins set_voltage/volt_out]
connect_bd_net [get_bd_pins output_mux/signal_2] [get_bd_pins output_slice/dout]
connect_bd_net [get_bd_pins output_mux/adc_clk] [get_bd_pins adc_dac/adc_clk]

set_property -dict [list CONFIG.DIN_TO {1} CONFIG.DIN_FROM {1} CONFIG.DOUT_WIDTH {1}] [get_bd_cells trigger_to_mux]
connect_bd_net [get_bd_pins output_mux/switch] [get_bd_pins trigger_to_mux/dout]
connect_bd_net [get_bd_pins ctl/Trigger] [get_bd_pins trigger_to_mux/din]

connect_bd_net [get_bd_pins output_mux/signal_out] [get_bd_pins adc_dac/dac1]
connect_bd_net [get_bd_pins output_mux/signal_out] [get_bd_pins adc_dac/dac2]
##################################################################################################################

# Need slice to connect to LEDs
create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 led_slice
# create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 led_concat
set_property -dict [list CONFIG.DIN_TO {0} CONFIG.DIN_FROM {7} CONFIG.DIN_WIDTH {18} CONFIG.DOUT_WIDTH {8}] [get_bd_cells led_slice]
# set_property -dict [list CONFIG.IN0_WIDTH {1} CONFIG.IN1_WIDTH {8}] [get_bd_cells led_concat]
connect_bd_net [get_bd_pins ctl/Scale_LB] [get_bd_pins led_slice/Din]
# connect_bd_net [get_bd_pins led_slice/Dout] [get_bd_pins led_concat/In0]
# connect_bd_net [get_bd_pins data_collector/tvalid] [get_bd_pins led_concat/In1]
# connect_bd_net [get_bd_ports led_o] [get_bd_pins led_concat/Dout]
connect_bd_net [get_bd_pins led_slice/Dout] [get_bd_ports led_o]

validate_bd_design

