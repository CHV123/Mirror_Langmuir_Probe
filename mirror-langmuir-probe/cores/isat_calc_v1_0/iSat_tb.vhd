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
  -- Instantiating the iSat module
  component iSatCalc is
    generic (
      bram_lat : integer := 2;
      div_lat  : integer := 18);        -- latency of divider
    port (
      adc_clk  : in std_logic;          -- adc input clock
      vFloat   : in signed(13 downto 0);  -- Floating Voltage input
      temp     : in signed(13 downto 0);  -- Temperature input
      outBRAM  : in unsigned(13 downto 0);         -- data returned by BRAM
      Mult1    : in signed(31 downto 0);  -- data returned by the division multiplexer
      Mult1Ind : in std_logic_vector(3 downto 0);  -- index of data returned by division multiplexer
      volt_in  : in signed(13 downto 0);  -- Voltage input
      volt1    : in signed(13 downto 0);  -- Fist bias voltage in cycle
      clk_en   : in std_logic;          -- Clock Enable to set period start

      divisor  : out signed(13 downto 0);   -- Divisor out
      dividend : out signed(13 downto 0);   -- Dividend out
      tUser    : out unsigned(2 downto 0);  -- tUser signal for divider block
      iSat     : out signed(13 downto 0);   -- Saturation current
      Prop     : out std_logic);  -- valid to propagate to float and temp block
  end component iSatCalc;

  -- parameters
  constant bram_lat : integer := 2;
  constant div_lat  : integer := 18;

  -- input signals
  signal adc_clk  : std_logic                    := '0';
  signal vFloat   : signed(13 downto 0)          := to_signed(-30, 14);  -- Floating Voltage input
  signal temp     : signed(13 downto 0)          := to_signed(-1000, 14);  -- Temperature input
  signal outBRAM  : unsigned(13 downto 0)        := to_unsigned(19, 14);  -- data returned by BRAM
  signal Mult1    : signed(31 downto 0)          := (others => '0');  -- data returned by the division multiplexer
  signal Mult1Ind : std_logic_vector(3 downto 0) := (others => '0');  -- index of data returned by division multiplexer
  signal volt_in  : signed(13 downto 0)          := (others => '0');  -- Voltage input
  signal volt1    : signed(13 downto 0)          := to_signed(-3000, 14);  -- Fist bias voltage in cycle
  signal clk_en   : std_logic                    := '0';  -- Clock Enable to set period start

  -- output signals
  signal divisor  : signed(13 downto 0)  := (others => '0');  -- Divisor out
  signal dividend : signed(13 downto 0)  := (others => '0');  -- Dividend out
  signal tUser    : unsigned(2 downto 0) := (others => '0');  -- tUser signal for divider block
  signal iSat_out : signed(13 downto 0)  := (others => '0');  -- Saturation current
  signal Prop     : std_logic            := '0';  -- valid to propagate to float and temp block

  -- Clock periods
  constant adc_clk_period : time := 8 ns;

  -- Simulation signals


begin  -- architecture behaviour
  -- Instantiating test unit
  uut : iSatCalc
    generic map (
      bram_lat => bram_lat,
      div_lat  => div_lat)
    port map (
      adc_clk  => adc_clk,
      vFloat   => vFloat,
      temp     => temp,
      outBRAM  => outBRAM,
      Mult1    => Mult1,
      Mult1Ind => Mult1Ind,
      volt_in  => volt_in,
      volt1    => volt1,
      clk_en   => clk_en,

      divisor  => divisor,
      dividend => dividend,
      tUser    => tUser,
      iSat     => iSat_out,
      Prop     => Prop
      );

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

  -- purpose: Process to simulate the divider core
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: Mult1, Mult1Ind
  divStim_proc: process
  begin  -- process divStim_proc
    wait for adc_clk_period/2;
    if adc_clk = '1' then
      if tUser = to_unsigned(1, tUser'length) then
        wait for adc_clk_period*18;
        Mult1Ind <= "0010";
        wait for adc_clk_period;
        Mult1Ind <= "0000";
      end if;
    end if;
  end process divStim_proc;

  -- Stimulus process
  stim_proc : process
    variable counter : integer := 0;
  begin
    wait for adc_clk_period;
    if counter = 0 then
      clk_en  <= '1';
      counter := counter + 1;
    elsif counter > 0  and counter < 124 then
      clk_en  <= '0';
      counter := counter + 1;
    else
      clk_en  <= '0';
      counter := 0;
    end if;
  end process;

end architecture test_bench;
