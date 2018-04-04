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

entity iSatCalc is

  generic (
    bram_lat : integer := 2;
    div_lat  : integer := 18);          -- latency of divider
  port (
    adc_clk  : in std_logic;            -- adc input clock
    vFloat   : in signed(13 downto 0);  -- Floating Voltage input
    temp     : in signed(13 downto 0);  -- Temperature input
    outBRAM  : in unsigned(13 downto 0);         -- data returned by BRAM
    Mult1    : in signed(31 downto 0);  -- data returned by the division multiplexer
    Mult1Ind : in std_logic_vector(3 downto 0);  -- index of data returned by division multiplexer
    volt_in  : in signed(13 downto 0);  -- Voltage input
    volt1    : in signed(13 downto 0);  -- Fist bias voltage in cycle
    clk_en   : in std_logic;            -- Clock Enable to set period start


    dividend : out signed(13 downto 0);   -- Dividend out
    tUser                 : out unsigned(2 downto 0);  -- tUser signal for divider block
    divisor : out signed(13 downto 0);   -- Divisor out
    iSat                  : out signed(13 downto 0);   -- Saturation current
    Prop                  : out std_logic);  -- valid to propagate to float and temp block


end entity iSatCalc;

architecture Behavioral of iSatCalc is

  signal exp_count : integer range 0 to 31 := 0;
  signal exp_en    : std_logic             := '0';
  signal exp_ret   : signed(13 downto 0)   := (others => '0');
  signal index     : unsigned(2 downto 0)  := (others => '0');
  signal div0      : std_logic             := '0';
  signal diff_set  : std_logic             := '0';
  signal tot_lat   : integer range 0 to 31 := 0;
  signal waitBRAM  : std_logic             := '0';  -- Signal to indicate when
                                                    -- to wait for the bram return
  signal storeSig  : signed(13 downto 0)   := (others => '0');

begin  -- architecture Behavioral

  index   <= unsigned(Mult1Ind(2 downto 1));
  div0    <= Mult1Ind(0);
  tot_lat <= bram_lat + div_lat;

  -- purpose: Process to calculate Saturation current
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: saturation current
  iSat_proc : process (adc_clk) is
  begin
    if rising_edge(adc_clk) then
      if index = to_unsigned(2, 3) then
        iSat <= Mult1;
      end if;
    end if;
  end process iSat_proc;

  -- purpose: process to set the divisor and dividend for the divider
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: divisor, dividend, tUser
  div_proc : process (adc_clk) is
  begin  -- process diff_proc
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        divisor  <= volt1 - vFloat;
        dividend <= temp;
        tUser    <= to_unsigned(1, tUser'length);
        diff_set <= '1';
        storeSig <= volt_in;
      elsif index = to_unsigned(1, 3) then
        waitBRAM <= '1';
      elsif exp_en = '1' then
        divisor  <= storeSig;
        dividend <= outBRAM;
        tUser    <= to_unsigned(2, tUser'length);
      else
        waitBRAM <= '0';
        diff_set <= '0';
        tUser    <= to_unsigned(3, tUser'length);
      end if;
    end if;
  end process div_proc;

  -- purpose: process to collect bram data after address is set by division module
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: exp_ret, exp_en
  collect_proc : process (adc_clk) is
  begin  -- process collect_proc
    if rising_edge(adc_clk) then
      if waitBRAM <= '1' then
        exp_count <= exp_count + 1;
      elsif exp_count = 1 then
        exp_count <= exp_count + 1;
      elsif exp_count = 2 then
        exp_en <= '1';
      else
        exp_count <= 0;
        exp_en    <= '0';
      end if;
    end if;
  end process collect_proc;

end architecture Behavioral;
