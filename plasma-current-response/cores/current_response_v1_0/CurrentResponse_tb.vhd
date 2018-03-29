-------------------------------------------------------------------------------
-- Test bench for the SetVolts vhdl module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_CurrentResponse is

end entity tb_CurrentResponse;

architecture behaviour of tb_CurrentResponse is
  -- Instantiating the SetVolts module
  component CurrentResponse is
    port (
    adc_clk : in std_logic;
    probe_bias : in signed(13 downto 0);
    current : out signed(13 downto 0)
      );
  end component CurrentResponse;

  -- input signals
  signal adc_clk : std_logic           := '0';
  signal probe_bias   : signed(13 downto 0) := (others => '0');


  -- output signals
  signal current : signed(13 downto 0) := (others => '0');

  -- Clock periods
  constant adc_clk_period : time := 4 ns;

begin  -- architecture behaviour
  -- Instantiating test unit
  uut : CurrentResponse
    port map (
      -- Inputs
      adc_clk => adc_clk,
      probe_bias   => probe_bias,
    
      -- Outputs
      current => current
      );

  -- Clock process definitions
  adc_clk_process : process
  begin
    adc_clk <= '0';
    wait for adc_clk_period/2;
    adc_clk <= '1';
    wait for adc_clk_period/2;
  end process;

  -- Stimulus process
  stim_proc : process
  begin
    wait for adc_clk_period*10;
    probe_bias <= to_signed(700, probe_bias'length);
    wait for adc_clk_period*100;
    probe_bias <= to_signed(400, probe_bias'length);
    wait for adc_clk_period*90;
  end process;

end architecture behaviour;
