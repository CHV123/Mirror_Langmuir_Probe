-------------------------------------------------------------------------------
-- Module to organise and store data for the MLP project
-- Started on March 26th by Charlie Vincent
--
-- Adjust variable is to lengthen period to a number that is indivisible by three
-- First two levels will be of length period, third level will be of length
-- period + adjust
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DataCollect is
  port (
    adc_clk    : in std_logic;          -- adc input clock
    Temp_valid : in std_logic;
    Temp       : in std_logic_vector(15 downto 0);
    iSat       : in std_logic_vector(15 downto 0);
    vFloat     : in std_logic_vector(15 downto 0);
    v_in       : in std_logic_vector(13 downto 0);
    v_out      : in std_logic_vector(13 downto 0);
    clk_en     : in std_logic;

    tvalid : out std_logic;
    tdata  : out std_logic_vector(31 downto 0)
    );

end entity DataCollect;

architecture Behavioral of DataCollect is
  signal switch      : std_logic                     := '0';
  signal data_hold_v : std_logic_vector(31 downto 0) := (others => '0');
  signal data_hold_t : std_logic_vector(31 downto 0) := (others => '0');
  signal temp_set    : std_logic                     := '0';
  signal delivered   : std_logic                     := '0';
begin  -- architecture Behavioral

  -- purpose: Process to generate the data switch signal from the data cycles integer and the adc_clk
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: data_valid
  switch_proc : process (adc_clk) is
  begin  -- process data_switch_proc
    if rising_edge(adc_clk) then
      if switch = '0' then
        switch <= '1';
      elsif switch = '1' then
        switch <= '0';
      end if;
    end if;
  end process switch_proc;

  -- purpose: Process to collect voltage values
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: data
  volt_collect : process (adc_clk) is
    variable counter : unsigned(2 downto 0)          := (others => '0');
    variable collate : std_logic_vector(15 downto 0) := (others => '0');
  begin  -- process data_collect
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        if switch = '1' then
          collate := v_in(7 downto 0) &
                     v_out(7 downto 0);
        elsif switch = '0' then
          data_hold_v <= "0" &
                         std_logic_vector(counter) &
                         v_in(13 downto 0) &
                         v_out(13 downto 0);
                         --collate;
        end if;
        counter := counter + 1;
      else
        counter := (others => '0');
      end if;
    end if;
  end process volt_collect;

  -- purpose: Process to collate the temperature, floating voltage and saturation current values after each temperature is collected
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: v_data
  var_collect : process (adc_clk) is
    variable counter : unsigned(3 downto 0) := (others => '0');
  begin  -- process var_collect
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        if Temp_valid = '1' then
          data_hold_t <= "1" &
                         std_logic_vector(counter) &
                         std_logic_vector(shift_right(signed(Temp), 2)(8 downto 0) &
                                          shift_right(signed(iSat), 2)(8 downto 0) &
                                          shift_right(signed(vFloat), 2)(8 downto 0));
          temp_set <= '1';
        end if;
        if delivered = '1' and temp_set = '1' then
          temp_set <= '0';
        end if;
        counter := counter + 1;
      else
        counter := (others => '0');
      end if;
    end if;
  end process var_collect;

  -- purpose: Process to set the data to ouput and the correct valid signal 
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: tdata, tvalid
  data_valid : process (adc_clk) is
  begin  -- process data_valid
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        if switch = '1' then
          tvalid <= '1';
          tdata  <= data_hold_v;
        elsif switch <= '0' and temp_set = '1' then
          tvalid    <= '1';
          tdata     <= data_hold_t;
          delivered <= '1';
        else
          tvalid    <= '0';
          delivered <= '0';
        end if;
      else
        tvalid <= '0';
      end if;
    end if;
  end process data_valid;

end architecture Behavioral;
