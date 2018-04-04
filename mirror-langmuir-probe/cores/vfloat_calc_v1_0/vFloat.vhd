-------------------------------------------------------------------------------
-- Module to set 3 different voltages levels for inital MLP demonstration
-- Started on March 26th by Charlie Vincent
--
-- Adjust variable is to lengthen period to a number that is indivisible by three
-- First two levels will be of length period, third level will be of length
-- period + adjust
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vFloatCalc is

  port (
    adc_clk : in std_logic;             -- adc input clock
    temp    : in signed(13 downto 0);   -- Temperature input
    iSat    : in signed(13 downto 0);   -- Saturation current input
    volt_in : in signed(13 downto 0);   -- input voltage
    natLog  : in signed(13 downto 0);

    vFloat : out signed(13 downto 0)    -- calculated floating voltage
    );

end entity vFloatCalc;

architecture Behavioral of vFloatCalc is
begin  -- architecture Behavioral

  -- purpose: Calculate output temperature
  -- type   : combinational
  -- inputs : adc
  -- outputs: temperature
  vfloat_proc : process (adc_clk) is
  begin  -- process temp_proc
    if rising_edge(adc_clk) then
      vFloat <= iSat;
    end if;
  end process vfloat_proc;

end architecture Behavioral;
