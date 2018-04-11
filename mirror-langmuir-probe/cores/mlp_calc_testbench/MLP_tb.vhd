-------------------------------------------------------------------------------
-- Test bench for the SetVolts vhdl module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

library UNISIM;
use UNISIM.vcomponents.all;

entity tb_MLP is
end entity tb_MLP;

architecture test_bench of tb_MLP is

  component MLP_modules is
    port (
      clk_100MHz     : in  std_logic;
      input_voltage  : in  std_logic_vector(13 downto 0);
      output_voltage : out std_logic_vector(13 downto 0);
      period         : in  std_logic_vector(31 downto 0);
      reset_rtl_0    : in  std_logic);
  end component MLP_modules;

  signal adc_clk  : std_logic                     := '0';
  signal volt_in  : std_logic_vector(13 downto 0) := (others => '0');
  signal volt_out : std_logic_vector(13 downto 0) := (others => '0');
  signal period   : std_logic_vector(31 downto 0) := (others => '0');
  signal reset    : std_logic                     := '0';

  -- Clock periods
  constant adc_clk_period : time := 10 ns;

  -- Simulation signals


begin  -- architecture behaviour

  dut : MLP_modules
    port map (
      clk_100MHz     => adc_clk,
      input_voltage  => volt_in,
      output_voltage => volt_out,
      period         => period,
      reset_rtl_0    => reset);

    -- purpose: Process for sim clock
    -- type   : combinational
    -- inputs : 
    -- outputs: adc_clk
    clk_proc : process is
    begin  -- process clk_proc
      wait for adc_clk_period/2;
      adc_clk <= '1';
      wait for adc_clk_period/2;
      adc_clk <= '0';
    end process clk_proc;

  -- purpose: Process to set the voltage input
  -- type   : combinational
  -- inputs : 
  -- outputs: volt_in
  volt_proc: process is
  begin  -- process volt_proc
    wait for adc_clk_period*38;
    volt_in <= std_logic_vector(to_signed(1253, volt_in'length));
    wait for adc_clk_period*38;
    volt_in <= std_logic_vector(to_signed(-1253, volt_in'length));
    wait for adc_clk_period*38;
    volt_in <= std_logic_vector(to_signed(0, volt_in'length));
  end process volt_proc;

end architecture test_bench;
