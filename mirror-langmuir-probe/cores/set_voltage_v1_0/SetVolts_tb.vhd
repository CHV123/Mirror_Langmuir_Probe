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
      period  : integer;
      negBias : integer;
      posBias : integer
      );
    port (
      adc_clk : in std_logic;
      period_in : in unsigned(31 downto 0);
      Temp : in signed(13 downto 0);
      Temp_valid : in std_logic;

      volt_out : out signed(13 downto 0);
      outStable : out std_logic
      );
  end component SetVolts;

  -- parameters
  constant period : integer := 10;
  constant negBias : integer := -3;
  constant posBias : integer := 1;

  -- input signals
  signal adc_clk : std_logic           := '0';
  signal period_in : unsigned(31 downto 0) := (others => '0');
  signal Temp : signed(13 downto 0) := (others => '0');
  signal Temp_valid : std_logic := '0';

  -- output signals
  signal volt_out : signed(13 downto 0) := (others => '0');
  signal outStable : std_logic;

  -- Clock periods
  constant adc_clk_period : time := 4 ns;

begin  -- architecture behaviour
  -- Instantiating test unit
  uut : SetVolts
    generic map (
      period => period,
      negBias => negBias,
      posBias => posBias)
    port map (
      -- Inputs
      adc_clk => adc_clk,
      period_in => period_in,
      Temp => Temp,
      Temp_valid => Temp_valid,

      -- Outputs
      volt_out => volt_out,
      outStable => outStable
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
  temp_proc : process
  begin
    wait for adc_clk_period*30;
    Temp <= Temp + 1;  
  end process;
  
  temp_valid_proc : process
  begin
    wait for adc_clk_period * 39;
    Temp_valid <= '1';
    wait for adc_clk_period;
    Temp_valid <= '0';
  end process;
end architecture behaviour;
