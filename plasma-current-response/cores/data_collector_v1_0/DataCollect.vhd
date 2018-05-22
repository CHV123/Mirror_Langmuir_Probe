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
    volt_valid : in std_logic;
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
  signal data_hold_v : std_logic_vector(31 downto 0) := (others => '0');
  signal data_hold_t : std_logic_vector(31 downto 0) := (others => '0');
  
  signal delivered_v : std_logic                     := '0';
  signal delivered_t : std_logic                     := '0';
  
  signal volt_stored : std_logic                     := '0';
  signal temp_stored : std_logic                     := '0';
  
begin  -- architecture Behavioral

  -- purpose: Process to collect voltage values
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: data
  volt_collect : process (adc_clk) is
    variable counter : unsigned(2 downto 0) := (others => '0');
  begin  -- process data_collect
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        if volt_valid = '1' then
          volt_stored <= '1';
          data_hold_v <= "0" &
                         std_logic_vector(counter) &
                         v_in(13 downto 0) &
                         v_out(13 downto 0);
          counter := counter + 1;
        else
          if delivered_v = '1' then
            volt_stored <= '0';
          end if;
        end if;
      else
        counter := (others => '0');
      end if;
    end if;
  end process volt_collect;

  -- purpose: Process to collect voltage values
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: data
  temp_collect : process (adc_clk) is
    variable counter : unsigned(3 downto 0) := (others => '0');
  begin  -- process data_collect
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        if Temp_valid = '1' then
          temp_stored <= '1';
          data_hold_t <= "1" &
                         std_logic_vector(counter) &
                         std_logic_vector(unsigned(Temp(8 downto 0))) &
                         std_logic_vector(shift_right(signed(iSat), 2)(8 downto 0)) &
                         std_logic_vector(signed(vFloat(8 downto 0)));
          counter := counter + 1;
        else
          if delivered_t = '1' then
            temp_stored <= '0';
          end if;
        end if;
      else
        counter := (others => '0');
      end if;
    end if;
  end process temp_collect;

  -- purpose: Process to set the data to ouput and the correct valid signal 
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: tdata, tvalid
  data_valid : process (adc_clk) is
  begin  -- process data_valid
    if rising_edge(adc_clk) then
      if clk_en = '1' then
        if temp_stored = '1' then
          if volt_stored = '1' then
            tdata <= data_hold_v;
            delivered_v <= '1';
            tvalid <= '1';
          else
            tdata <= data_hold_t;
            delivered_t <= '1';
            tvalid <= '1';
          end if;
        else
          if volt_stored = '1' then
            tdata <= data_hold_v;
            delivered_v <= '1';
            tvalid <= '1';
          else
            tvalid <= '0';
            delivered_v <= '0';
            delivered_t <= '0';
          end if;
        end if;
      else
        tvalid <= '0';
      end if;
    end if;
  end process data_valid;


end architecture Behavioral;