-------------------------------------------------------------------------------
-- Module to downsample the clock to provide clk_en where needed.
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ClkCount is
    -- adjustment for non-divisible periods

  port (
    adc_clk : in std_logic;             -- adc input clock
    count : in std_logic_vector(31 downto 0);

    out_en : out std_logic
    );

end entity ClkCount;

architecture Behavioral of ClkCount is

  signal counter : unsigned(31 downto 0) := (others => '0');

begin  -- architecture Behavioral

--purpose: process to set the ouput enable given the input count and the adc_clk
--Type   : combination
--inputs : adc_clk, counter
--outputs: out_en

  Process(adc_clk)
  begin

    if to_integer(unsigned(count)) = 0 then
      out_en <= adc_clk;
    else
      if (rising_edge(adc_clk)) then
        if counter = unsigned(count) - 1 then
          out_en <= '1';
          counter <= (others => '0');
        else
          out_en <= '0';  
          counter <= counter + 1;
        end if;
      end if;
    end if;

    
  end process;

end architecture Behavioral;
