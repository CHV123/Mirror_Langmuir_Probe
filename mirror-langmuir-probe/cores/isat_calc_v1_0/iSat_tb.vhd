-------------------------------------------------------------------------------
-- Test bench for the SetVolts vhdl module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity tb_iSat is
end entity tb_iSat;

architecture test_bench of tb_iSat is

  ----------------------------------------------------------------------------------------------
  -- Instantiating the iSat module
  component iSatCalc is
    generic (
      mapBRAMco : integer := 1;
      mapBRAMad : integer := 0);
    port (
      adc_clk       : in std_logic;     -- adc input clock
      vFloat        : in signed(13 downto 0);  -- Floating Voltage input
      temp          : in signed(13 downto 0);  -- Temperature input
      BRAMret       : in signed(13 downto 0);  -- data returned by BRAM
      volt_in       : in signed(13 downto 0);  -- Voltage input
      volt1         : in signed(13 downto 0);  -- Fist bias voltage in cycle
      clk_en        : in std_logic;     -- Clock Enable to set period start
      divider_tdata : in std_logic_vector(31 downto 0);
      divider_tuser : in std_logic_vector(1 downto 0);

      divisor_tdata   : out std_logic_vector(15 downto 0);
      divisor_tvalid  : out std_logic;
      dividend_tdata  : out std_logic_vector(15 downto 0);
      dividend_tvalid : out std_logic;
      dividend_tuser  : out std_logic_vector(1 downto 0);
      BRAM_addr       : out std_logic_vector(13 downto 0);  -- BRAM address out
      iSat            : out signed(13 downto 0);  -- Saturation current
      data_valid      : out std_logic);  -- valid to propagate to float and temp block
  end component iSatCalc;
  --------------------------------------------------------------------------------------------

  ------------------- Divider generator core
  component div_gen_0
    port (
      aclk                   : in  std_logic;
      s_axis_divisor_tvalid  : in  std_logic;
      s_axis_divisor_tdata   : in  std_logic_vector(15 downto 0);
      s_axis_dividend_tvalid : in  std_logic;
      s_axis_dividend_tuser  : in  std_logic_vector(1 downto 0);
      s_axis_dividend_tdata  : in  std_logic_vector(15 downto 0);
      m_axis_dout_tvalid     : out std_logic;
      m_axis_dout_tuser      : out std_logic_vector(1 downto 0);
      m_axis_dout_tdata      : out std_logic_vector(31 downto 0)
      );
  end component;
  -- Divider generator core ------------------
  
  ------------- Begin Cut here for COMPONENT Declaration ------ COMP_TAG
  COMPONENT blk_mem_gen_0
    PORT (
      clka : IN STD_LOGIC;
      wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
      addra : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
      dina : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
      douta : OUT STD_LOGIC_VECTOR(13 DOWNTO 0)
    );
  END COMPONENT;
  -- COMP_TAG_END ------ End COMPONENT Declaration ------------
  
  ----------------------------------------------------------------------------------------------------
  -- Signals for iSatCalc module
  -- parameters
  constant mapBRAMco : integer := 1;
  constant mapBRAMad : integer := 0;

  -- input signals
  signal adc_clk       : std_logic                     := '0';
  signal vFloat        : signed(13 downto 0)           := to_signed(2, 14);  -- Floating Voltage input
  signal temp          : signed(13 downto 0)           := to_signed(5, 14);  -- Temperature input
  signal BRAMret       : signed(13 downto 0)           := to_signed(0, 14);  -- data returned by BRAM
  signal volt_in       : signed(13 downto 0)           := (others => '0');  -- Voltage input
  signal volt1         : signed(13 downto 0)           := to_signed(14, 14);  -- Fist bias voltage in cycle
  signal clk_en        : std_logic                     := '0';  -- Clock Enable to set period start
  signal divider_tdata : std_logic_vector(31 downto 0) := (others => '0');
  signal divider_tuser : std_logic_vector(1 downto 0)  := (others => '0');


  -- output signals
  signal divisor_tdata   : std_logic_vector(15 downto 0) := (others => '0');
  signal divisor_tvalid  : std_logic                     := '0';
  signal dividend_tdata  : std_logic_vector(15 downto 0) := (others => '0');
  signal dividend_tvalid : std_logic                     := '0';
  signal dividend_tuser  : std_logic_vector(1 downto 0)  := (others => '0');
  signal BRAM_addr       : std_logic_vector(13 downto 0) := (others => '0');
  signal iSat_out        : signed(13 downto 0)           := (others => '0');  -- Saturation current
  signal data_valid      : std_logic                     := '0';  -- valid to propagate to float and temp block
  -- Signals for iSatCalc Module
  ---------------------------------------------------------------------------------------------------

  -- Signals for blk_mem_gen_0 ------------------------------------------------------------------
  -- input signals
  signal addra : std_logic_vector(3 downto 0) := (others => '0');
  signal wea : std_logic_vector(0 downto 0) := (others => '0');
  signal dina : std_logic_vector(13 downto 0) := (others => '0');
  signal douta : std_logic_vector(13 downto 0) := (others => '0');

  -- Clock periods
  constant adc_clk_period : time := 8 ns;

  -- Simulation signals


begin  -- architecture behaviour
  -- Instantiating test unit
  uut : iSatCalc
    port map (
      adc_clk       => adc_clk,
      vFloat        => vFloat,
      temp          => temp,
      BRAMret       => BRAMret,
      volt_in       => volt_in,
      volt1         => volt1,
      clk_en        => clk_en,
      divider_tdata => divider_tdata,
      divider_tuser => divider_tuser,

      divisor_tdata   => divisor_tdata,
      divisor_tvalid  => divisor_tvalid,
      dividend_tdata  => dividend_tdata,
      dividend_tvalid => dividend_tvalid,
      dividend_tuser  => dividend_tuser,
      BRAM_addr       => BRAM_addr,
      iSat            => iSat_out,
      data_valid      => data_valid
      );

  ------------- Begin Cut here for INSTANTIATION Template ----- INST_TAG
  Divider_core : div_gen_0
    port map (
      aclk                   => adc_clk,
      s_axis_divisor_tvalid  => divisor_tvalid,
      s_axis_divisor_tdata   => divisor_tdata,
      s_axis_dividend_tvalid => dividend_tvalid,
      s_axis_dividend_tuser  => dividend_tuser,
      s_axis_dividend_tdata  => dividend_tdata,
      m_axis_dout_tuser      => divider_tuser,
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

  BRAMret <= signed(douta);
  addra <= BRAM_addr(3 downto 0);
  
  -- Clock process definitions
  adc_clk_process : process
  begin
    adc_clk <= '0';
    wait for adc_clk_period/2;
    adc_clk <= '1';
    wait for adc_clk_period/2;
  end process;

  -- purpose: Stimulation process to provide voltage input
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: volt_in
  voltInput : process
  begin  -- process voltInput
    wait for adc_clk_period;
    volt_in <= volt_in + 1;
  end process voltInput;

  -- Stimulus process
  stim_proc : process
    variable counter : integer := 0;
  begin
    wait for adc_clk_period;
    if counter = 0 then
      clk_en  <= '1';
      counter := counter + 1;
    elsif counter > 0 and counter < 124 then
      clk_en  <= '0';
      counter := counter + 1;
    else
      clk_en  <= '0';
      counter := 0;
    end if;
  end process;

end architecture test_bench;
