-------------------------------------------------------------------------------
-- Module to calculate the ISat constant for MLP bias setting
-- This module must be used in conjuction with a divider core and a bram
-- generator core. The latency from clock_enable to data valid is currently 36
-- clock cycles
-- Started on March 2nd by Charlie Vincent
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity iSatCalc is
  generic (
    Temp_guess   : integer := 20;
    iSat_guess   : integer := -20;
    vFloat_guess : integer := 0);
  port (
    adc_clk        : in std_logic;      -- adc input clock
    vFloat         : in std_logic_vector(15 downto 0);  -- Floating Voltage input
    Temp           : in std_logic_vector(15 downto 0);  -- Temperature input
    BRAMret        : in std_logic_vector(15 downto 0);  -- data returned by BRAM
    volt_in        : in std_logic_vector(13 downto 0);  -- Voltage input
    volt1          : in std_logic_vector(13 downto 0);  -- Fist bias voltage in cycle
    clk_en         : in std_logic;      -- Clock Enable to set period start
    divider_tdata  : in std_logic_vector(23 downto 0);
    divider_tvalid : in std_logic;

    divisor_tdata   : out std_logic_vector(15 downto 0);
    divisor_tvalid  : out std_logic;
    dividend_tdata  : out std_logic_vector(15 downto 0);
    dividend_tvalid : out std_logic;
    BRAM_addr       : out std_logic_vector(13 downto 0);  -- BRAM address out
    iSat            : out std_logic_vector(15 downto 0);  -- Saturation current
    data_valid      : out std_logic);  -- valid to propagate to float and temp block

end entity iSatCalc;

architecture Behavioral of iSatCalc is

  signal exp_count : integer range 0 to 31 := 0;
  signal exp_en    : std_logic             := '0';
  signal exp_ret   : signed(13 downto 0)   := (others => '0');
  signal index     : std_logic             := '0';
  signal diff_set  : std_logic             := '0';
  signal waitBRAM  : std_logic             := '0';  -- Signal to indicate when
                                                    -- to wait for the bram return
  signal storeSig  : signed(13 downto 0)   := (others => '0');

  signal iSat_mask : signed(29 downto 0) := to_signed(iSat_guess, 30);

  signal addr_mask_store : integer := 0;
  signal int_store       : integer := 0;
  signal rem_store       : integer := 0;

  signal calc_switch : std_logic := '0';

begin  -- architecture Behavioral

  index <= divider_tvalid;
  iSat  <= std_logic_vector(iSat_mask(15 downto 0));

  -- purpose: Process to calculate Saturation current
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: saturation current
  iSat_proc : process (adc_clk) is
  begin
    if rising_edge(adc_clk) then
      if exp_en = '1' then
        if calc_switch = '1' then
          iSat_mask <= shift_right(storeSig * signed(BRAMret), 13);
        else
          iSat_mask <= shift_right(storeSig * signed(BRAMret), 2);
        end if;
        data_valid <= '1';
      else
        data_valid <= '0';
      end if;
    end if;
  end process iSat_proc;

  -- purpose: process to set the divisor and dividend for the divider
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: divisor, dividend, tUser
  div_proc : process (adc_clk) is
    variable divisor_mask : signed(13 downto 0) := (others => '0');
  begin  -- process diff_proc
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        -- Setting the variables to go into the division
        divisor_mask := to_signed(to_integer(signed(Temp)), 14);
        if abs(divisor_mask) > 0 then
          divisor_tdata <= "00" & std_logic_vector(divisor_mask);
        else
          divisor_tdata <= "00" & std_logic_vector(to_signed(Temp_guess, 14));
        end if;
        dividend_tdata  <= "00" &std_logic_vector(to_signed(to_integer(signed(volt1))-to_integer(signed(vFloat)), 14));
        dividend_tvalid <= '1';
        divisor_tvalid  <= '1';
        diff_set        <= '1';
        storeSig        <= signed(volt_in);
      else
        -- making them zero otherwise, though strictly this should not be
        -- necessary as we're sending a tvalid signal
        divisor_tdata   <= (others => '0');
        dividend_tdata  <= (others => '0');
        dividend_tvalid <= '0';
        divisor_tvalid  <= '0';
        diff_set        <= '0';
      end if;
    end if;
  end process div_proc;

  -- purpose: process to set the BRAM address for data data retrieval.
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: BRAM_addr, waitBRAM
  BRAM_proc : process (adc_clk) is
    variable divider_int : signed(13 downto 0) := (others => '0');
    variable divider_rem : signed(9 downto 0)  := (others => '0');
    variable addr_mask   : integer             := 0;
  begin  -- process BRAM_proc
    if rising_edge(adc_clk) then
      if index = '1' then
        -- Extracting the integer part and the fractional part returned by the
        -- divider core to use in the bram address mapping
        divider_rem := signed(divider_tdata(9 downto 0));
        divider_int := signed(divider_tdata(23 downto 10));
        int_store   <= to_integer(divider_int);
        rem_store   <= to_integer(divider_rem);
        if divider_int = to_signed(-8, 14) then
          addr_mask   := 0;
          calc_switch <= '1';
        elsif divider_int = to_signed(-7, 14) then
          addr_mask   := 1024 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(-6, 14) then
          addr_mask   := 2048 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(-5, 14) then
          addr_mask   := 3072 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(-4, 14) then
          addr_mask   := 4096 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(-3, 14) then
          addr_mask   := 5120 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(-2, 14) then
          addr_mask   := 6144 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(-1, 14) then
          addr_mask   := 7168 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(0, 14) then
          addr_mask   := 8192 + (2*to_integer(divider_rem));
          calc_switch <= '0';
        elsif divider_int = to_signed(1, 14) then
          addr_mask   := 9216 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(2, 14) then
          addr_mask   := 10240 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(3, 14) then
          addr_mask   := 11264 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(4, 14) then
          addr_mask   := 12288 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(5, 14) then
          addr_mask   := 13312 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(6, 14) then
          addr_mask   := 14336 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        elsif divider_int = to_signed(7, 14) then
          addr_mask   := 15360 + (2*to_integer(divider_rem));
          calc_switch <= '1';
        else
          if divider_int < to_signed(-8, 14) then
            addr_mask   := 0;
            calc_switch <= '1';
          elsif divider_int >= to_signed(8, 14) then
            addr_mask   := 16383;
            calc_switch <= '1';
          end if;
        end if;
        addr_mask_store <= addr_mask;
        BRAM_addr       <= std_logic_vector(to_unsigned(addr_mask, 14));
        waitBRAM        <= '1';
      else
        waitBRAM <= '0';
      end if;
    end if;
  end process BRAM_proc;

  -- purpose: process to collect bram data after address is set by division module
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: exp_ret, exp_en
  collect_proc : process (adc_clk) is
  begin  -- process collect_proc
    -- Setting a collection tick to get the right block ram memory back once
    -- the address has been assigned.
    if rising_edge(adc_clk) then
      if waitBRAM = '1' then
        exp_count <= exp_count + 1;
      end if;
      if exp_count = 1 then
        exp_count <= exp_count + 1;
      elsif exp_count = 2 then
        exp_en <= '1';
      end if;
      if exp_en = '1' then
        exp_count <= 0;
        exp_en    <= '0';
      end if;
    end if;
  end process collect_proc;

end architecture Behavioral;
