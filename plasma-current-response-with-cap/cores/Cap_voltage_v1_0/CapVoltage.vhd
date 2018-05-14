-------------------------------------------------------------------------------
-- Module to set 3 different voltages levels for inital MLP demonstration
-- Started on March 26th by Charlie Vincent
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CapVoltage is
    -- adjustment for non-divisible periods

  port (
    adc_clk : in std_logic;             -- adc input clock
    divider_tvalid : in std_logic;
    divider_tdata : in std_logic_vector(31 downto 0);

    Address_gen_tvalid : out std_logic;
    divider_int_res : out std_logic_vector(15 downto 0)
    );

end entity CapVoltage;

architecture Behavioral of CapVoltage is

begin  -- architecture Behavioral

--purpose: process to set the BRAM address for the look up table retrival
--Type   : combination
--inputs : adc_clk, divider_tdata
--outputs: BRAM_addr, waitBRAM
BRAM_proc : process (adc_clk) is
    variable divider_int : signed(15 downto 0) := (others => '0');
    variable divider_frac : signed(9 downto 0) := (others => '0');
    variable addr_mask   : integer         := 0;
  begin  -- process BRAM_proc
    if rising_edge(adc_clk) then
    	if divider_tvalid = '0' then
     		Address_gen_tvalid <= divider_tvalid;
     		divider_int_res <= "0000000000000000";
      	elsif divider_tvalid = '1' then
        	-- Extracting the integer part and the fractional part returned by the
        	-- divider core to use in the bram address mapping
        	divider_frac := signed(divider_tdata(9 downto 0));
        	divider_int := signed(divider_tdata(25 downto 10));
       		divider_int_res <= divider_tdata(25 downto 10);
        	--int_store   <= to_integer(divider_int);
        	--rem_store   <= to_integer(divider_frac);
        	Address_gen_tvalid <= divider_tvalid;
     	 end if;
    end if;
  end process BRAM_proc;


end architecture Behavioral;
