-------------------------------------------------------------------------------
-- Test bench for the SetVolts vhdl module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity tb_Temp is
end entity tb_Temp;

architecture test_bench of tb_Temp is

  ----------------------------------------------------------------------------------------------
  -- Instantiating the Temp module
  component TempCalc is
    port (
      adc_clk       : in std_logic;     -- adc input clock
      clk_rst       : in std_logic;     -- adc input clock
      vFloat        : in std_logic_vector(15 downto 0);  -- Floating Voltage input
      iSat          : in std_logic_vector(15 downto 0);  -- iSat input
      BRAMret       : in std_logic_vector(15 downto 0);  -- data returned by BRAM
      volt_in       : in std_logic_vector(13 downto 0);  -- Voltage input
      volt2         : in std_logic_vector(13 downto 0);  -- Fist bias voltage in cycle
      clk_en        : in std_logic;     -- Clock Enable to set period start
      divider_tdata : in std_logic_vector(31 downto 0);
      divider_tvalid : in std_logic;

      divisor_tdata   : out std_logic_vector(15 downto 0);
      divisor_tvalid  : out std_logic;
      dividend_tdata  : out std_logic_vector(15 downto 0);
      dividend_tvalid : out std_logic;
      BRAM_addr       : out std_logic_vector(13 downto 0);  -- BRAM address out
      Temp            : out std_logic_vector(15 downto 0);  -- Saturation current
      data_valid      : out std_logic);  -- valid to propagate to float and temp block
  end component TempCalc;
  --------------------------------------------------------------------------------------------

  ------------------- Divider generator core
  component div_gen_0
    port (
      aclk                   : in  std_logic;
      s_axis_divisor_tvalid  : in  std_logic;
      s_axis_divisor_tdata   : in  std_logic_vector(15 downto 0);
      s_axis_dividend_tvalid : in  std_logic;
      s_axis_dividend_tdata  : in  std_logic_vector(15 downto 0);
      m_axis_dout_tvalid     : out std_logic;
      m_axis_dout_tdata      : out std_logic_vector(31 downto 0)
      );
  end component;
  -- Divider generator core ------------------
  
  ------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
  COMPONENT blk_mem_gen_0
    PORT (
      clka : IN STD_LOGIC;
      wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      dina : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
  END COMPONENT;
  -- COMP_TAG_END ------ End COMPONENT Declaration ------------
  
  ----------------------------------------------------------------------------------------------------
  -- Signals for TempCalc module

  -- input signals
  signal adc_clk       : std_logic                     := '0';
  signal clk_rst       : std_logic                     := '0';
  signal vFloat        : std_logic_vector(15 downto 0)           := std_logic_vector(to_signed(0, 16));  -- Floating Voltage input
  signal iSat          : std_logic_vector(15 downto 0)           := std_logic_vector(to_signed(-100, 16));  -- Temperature input
  signal BRAMret       : std_logic_vector(15 downto 0)           := std_logic_vector(to_signed(0, 16));  -- data returned by BRAM
  signal volt_in       : std_logic_vector(13 downto 0)           := std_logic_vector(to_signed(-860, 14));  -- Voltage input
  signal volt2         : std_logic_vector(13 downto 0)           := std_logic_vector(to_signed(350, 14));  -- Second bias voltage in cycle
  signal clk_en        : std_logic                     := '0';  -- Clock Enable to set period start
  signal divider_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal divider_tvalid : std_logic := '0';


  -- output signals
  signal divisor_tdata   : std_logic_vector(15 downto 0) := (others => '0');
  signal divisor_tvalid  : std_logic                     := '0';
  signal dividend_tdata  : std_logic_vector(15 downto 0) := (others => '0');
  signal dividend_tvalid : std_logic                     := '0';
  signal BRAM_addr       : std_logic_vector(13 downto 0) := (others => '0');
  signal Temp_out        : std_logic_vector(15 downto 0)           := (others => '0');  -- Electron temperature
  signal data_valid      : std_logic                     := '0';  -- valid to propagate to float and temp block
  -- Signals for TempCalc Module
  ---------------------------------------------------------------------------------------------------

  -- Signals for blk_mem_gen_0 ------------------------------------------------------------------
  -- input signals
  signal addra : std_logic_vector(13 downto 0) := (others => '0');
  signal wea : std_logic_vector(0 downto 0) := (others => '0');
  signal dina : std_logic_vector(15 downto 0) := (others => '0');
  signal douta : std_logic_vector(15 downto 0) := (others => '0');

  -- Clock periods
  constant adc_clk_period : time := 8 ns;

  -- Simulation signals


begin  -- architecture behaviour
  -- Instantiating test unit
  uut : TempCalc
    port map (
      adc_clk       => adc_clk,
      clk_rst       => clk_rst,
      vFloat        => vFloat,
      iSat          => iSat,
      BRAMret       => BRAMret,
      volt_in       => volt_in,
      volt2         => volt2,
      clk_en        => clk_en,
      divider_tdata => divider_tdata,
      divider_tvalid => divider_tvalid,

      divisor_tdata   => divisor_tdata,
      divisor_tvalid  => divisor_tvalid,
      dividend_tdata  => dividend_tdata,
      dividend_tvalid => dividend_tvalid,
      BRAM_addr       => BRAM_addr,
      Temp            => Temp_out,
      data_valid      => data_valid
      );

  ------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
  Divider_core : div_gen_0
    port map (
      aclk                   => adc_clk,
      s_axis_divisor_tvalid  => divisor_tvalid,
      s_axis_divisor_tdata   => divisor_tdata,
      s_axis_dividend_tvalid => dividend_tvalid,
      s_axis_dividend_tdata  => dividend_tdata,
      m_axis_dout_tvalid      => divider_tvalid,
      m_axis_dout_tdata      => divider_tdata
      );
  -- INST_TAG_END ------ End INSTANTIATION Template --------- 
  
  ------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
  BRAM_core_SPR : blk_mem_gen_0
    PORT MAP (
      clka => adc_clk,
      wea => wea,
      addra => addra,
      dina => dina,
      douta => douta
    );
  -- INST_TAG_END ------ End INSTANTIATION Template ---------

  BRAMret <= douta;
  addra <= BRAM_addr;
  
  -- Clock process definitions
  adc_clk_process : process
  begin
    adc_clk <= '0';
    wait for adc_clk_period/2;
    adc_clk <= '1';
    wait for adc_clk_period/2;
  end process;

  -- purpose: Process to fluctuate temperature
  -- type   : combinational
  -- inputs : 
  -- outputs: Temp
  iSat_proc: process is
  begin  -- process temp_proc
    wait for adc_clk_period*50;
    iSat <= std_logic_vector(signed(iSat));-- + to_signed(200, 14));
  end process iSat_proc;

  -- purpose: Stimulation process to provide voltage input
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: volt_in
  voltInput : process
  begin  -- process voltInput
    wait for adc_clk_period*60;
    volt_in <= std_logic_vector(signed(volt_in));-- + to_signed(200, 14));
  end process voltInput;

  -- Stimulus process
  stim_proc : process
    variable counter : integer := 0;
  begin
    wait for adc_clk_period;
    if counter = 0 then
      clk_en  <= '1';
      counter := counter + 1;
    elsif counter > 0 and counter < 40 then
      clk_en  <= '0';
      counter := counter + 1;
    else
      clk_en  <= '0';
      counter := 0;
    end if;
  end process;

end architecture test_bench;
