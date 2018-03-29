-------------------------------------------------------------------------------
-- Module to set 3 different voltages levels for inital MLP demonstration
-- Started on March 26th by Charlie Vincent
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CurrentResponse is
    -- adjustment for non-divisible periods

  port (
    adc_clk : in std_logic;             -- adc input clock
    probe_bias : in signed(13 downto 0);
    current : out signed(13 downto 0)
    );

end entity CurrentResponse;

architecture Behavioral of CurrentResponse is
    signal bias_mask : signed(31 downto 0) := (others => '0');
begin  -- architecture Behavioral
  -- Process to count through the voltage levels
 
    adf : process(adc_clk)        
    begin
    if rising_edge(adc_clk) then 
        bias_mask <= to_signed(5*to_integer(probe_bias), bias_mask'length);
        current <= bias_mask(13 downto 0);
    end if;
    end process;
  
end architecture Behavioral;
