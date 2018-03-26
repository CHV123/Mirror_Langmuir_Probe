-------------------------------------------------------------------------------
-- Module to set 3 different voltages levels for inital MLP demonstration
-- Started on March 26th by Charlie Vincent
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity SetVolts is

  generic (
    period : integer := 333;            -- level duration
    adjust : integer := 0);             -- adjustment for non-divisible periods

  port (
    adc_clk : in std_logic;             -- adc input clock
    volt1   : in signed(31 downto 0);   -- level for voltage 1
    volt2   : in signed(31 downto 0);   -- level for voltage 2
    volt3   : in signed(31 downto 0);   -- level for voltage 3

    volt_out : out signed(31 downto 0)
    );                                 

end entity SetVolts;

architecture Behavioral of SetVolts is
  signal output : signed(13 downto 0) := (others => '0');  -- mask for the output voltage
  signal counter : integer := 0;        -- counter for setting the voltage levels
begin  -- architecture Behavioral

  -- Process to count through the voltage levels
  count_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      counter <= counter + 1
    end if;
  end process;
  
  set_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      if counter = period then
        case level is
          when 1  => ;
          when others => null;
        end case;
      end if;
    end if;
  end process;
  
end architecture Behavioral;
