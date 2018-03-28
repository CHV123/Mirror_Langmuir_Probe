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

entity SetVolts is

  generic (
    period : integer := 40;             -- level duration
    adjust : integer := 0               -- adjustment for non-divisible periods
    );
  port (
    adc_clk : in std_logic;             -- adc input clock
    volt1   : in signed(31 downto 0);   -- level for voltage 1
    volt2   : in signed(31 downto 0);   -- level for voltage 2
    volt3   : in signed(31 downto 0);   -- level for voltage 3
    period_in  : in unsigned(31 downto 0);  

    volt_out : out signed(13 downto 0);
    period_out : out unsigned(31 downto 0);
    adjust_out : out unsigned(31 downto 0)
    );

end entity SetVolts;

architecture Behavioral of SetVolts is
  signal output  : signed(13 downto 0)  := (others => '0');  -- mask for the output voltage
  signal counter : integer              := 0;  -- counter for setting the voltage levels
  signal level   : integer range 0 to 2 := 0;  -- counter for registering the voltage levels

  signal period_mask : integer := 0;
  signal adjust_mask : integer := 0;
begin  -- architecture Behavioral

  period_out <= to_unsigned(period_mask, period_out'length);
  adjust_out <= to_unsigned(adjust_mask, adjust_out'length);

  -- Process to define the level period
  period_proc : process(adc_clk)
    variable div3 : integer := 0;
    variable div8 : integer := 0;
    variable div4 : integer := 0;
  begin
    if rising_edge(adc_clk) then
      if period_in > period then
        div8 := to_integer(shift_right(period_in, 3));
        div4 := to_integer(shift_right(period_in, 2));
        div3 := to_integer(to_unsigned(div4 + div8, 32));
        period_mask <= div3;
        adjust_mask <= div3 - div4;
      else
        period_mask <= period;
        adjust_mask <= adjust;
      end if;
    end if;
  end process;

  -- Process to count
  count_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      counter <= counter + 1;
      if level = 2 then
        if counter = period_mask - adjust_mask then
          counter <= 0;
        end if;
      else
        if counter = period_mask then
          counter <= 0;
        end if;
      end if;
    end if;
  end process;

  -- Process to advance level
  level_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      if level = 2 then
        if counter = period + adjust then
          level <= 0;
        end if;  -- end of counter descision
      else
        if counter = period then
          level <= level + 1;
        end if;  -- end of counter decision
      end if;  -- end of level descision
    end if;  -- end of rising edge
  end process;

  -- Setting the output to various voltage levels
  set_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      case level is
        when 0 =>
          output <= volt1(13 downto 0);
        when 1 =>
          output <= volt2(13 downto 0);
        when 2 =>
          output <= volt3(13 downto 0);
        when others =>
          output <= (others => '0');
      end case;
    end if;
  end process;

  out_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      volt_out <= output;
    end if;
  end process;

end architecture Behavioral;
