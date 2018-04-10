-------------------------------------------------------------------------------
-- Test bench for the SetVolts vhdl module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_SetVolts is

end entity tb_SetVolts;

architecture behaviour of tb_SetVolts is
  -- Instantiating the SetVolts module
  component SetVolts is
    generic (
      period : integer;
      adjust : integer
      );
    port (
      adc_clk : in std_logic;
      volt1   : in signed(31 downto 0);
      volt2   : in signed(31 downto 0);
      volt3   : in signed(31 downto 0);

      volt_out : out signed(13 downto 0)
      );
  end component SetVolts;

  -- parameters
  constant period : integer := 10;
  constant adjust : integer := 0;

  -- input signals
  signal adc_clk : std_logic           := '0';
  signal volt1   : signed(31 downto 0) := (others => '0');
  signal volt2   : signed(31 downto 0) := (others => '0');
  signal volt3   : signed(31 downto 0) := (others => '0');

  -- output signals
  signal volt_out : signed(13 downto 0) := (others => '0');

  -- Clock periods
  constant adc_clk_period : time := 4 ns;

begin  -- architecture behaviour
  -- Instantiating test unit
  uut : SetVolts
    generic map (
      period => period,
      adjust => adjust)
    port map (
      -- Inputs
      adc_clk => adc_clk,
      volt1   => volt1,
      volt2   => volt2,
      volt3   => volt3,

      -- Outputs
      volt_out => volt_out
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
    volt1 <= to_signed(7000, volt1'length);
    volt2 <= to_signed(1000, volt2'length);
    volt3 <= to_signed(-2000, volt3'length);
    wait for adc_clk_period*100;
    volt1 <= to_signed(4000, volt1'length);
    volt2 <= to_signed(500, volt2'length);
    volt3 <= to_signed(-6000, volt3'length);
    wait for adc_clk_period*90;
  end process;

end architecture behaviour;
