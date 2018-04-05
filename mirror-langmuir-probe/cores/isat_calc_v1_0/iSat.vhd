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

  port (
    adc_clk : in std_logic;              -- adc input clock
    vFloat  : in signed(13 downto 0);    -- Floating Voltage input
    temp    : in signed(13 downto 0);    -- Temperature input
    outBRAM : in unsigned(13 downto 0);  -- data returned by BRAM
    volt_in : in signed(13 downto 0);    -- Voltage input
    volt1   : in signed(13 downto 0);    -- Fist bias voltage in cycle
    clk_en  : in std_logic;              -- Clock Enable to set period start

    iSat : out signed(13 downto 0);     -- Saturation current
    Prop : out std_logic);  -- valid to propagate to float and temp block
    
end entity iSatCalc;

architecture Behavioral of iSatCalc is

  -- Divider generator core entity instantiantion
  ------------------- Divider core
  component div_gen_0
    port (
      aclk : IN STD_LOGIC;
      s_axis_divisor_tvalid : IN STD_LOGIC;
        s_axis_divisor_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        s_axis_dividend_tvalid : IN STD_LOGIC;
        s_axis_dividend_tuser : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axis_dividend_tdata : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        m_axis_dout_tvalid : OUT STD_LOGIC;
        m_axis_dout_tuser : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axis_dout_tdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0)
      );
  end component;
  -- Divider core ------------------

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

  -- Divider signals--------------------------------------
  -- Input
  signal divisor        : std_logic_vector(15 downto 0)           := (others => '0');
  signal dividend       : std_logic_vector(15 downto 0)           := (others => '0');
  signal tvalid         : std_logic                     := '1';
  signal tuser          : std_logic_vector(2 downto 0)  := (others => '0');
  -- Output
  signal divider_dout   : std_logic_vector(31 downto 0) := (others => '0');
  signal divider_tvalid : std_logic                     := '0';
  signal divider_tuser  : std_logic_vector(2 downto 0)  := (others => '0');

begin  -- architecture Behavioral

  index <= unsigned(divider_tuser);
  
  ------------------ Divider core
  Divider_core : div_gen_0
    port map (
      aclk                   => adc_clk,
      s_axis_divisor_tvalid  => tvalid,
      s_axis_divisor_tdata   => divisor,
      s_axis_dividend_tvalid => tvalid,
      s_axis_dividend_tdata  => dividend,
      s_axis_dividend_tuser  => tuser,
      m_axis_dout_tvalid     => divider_tvalid,
      m_axis_dout_tdata      => divider_dout,
      m_axis_dout_tuser      => divider_tuser
      );
  -- Divider core ---------------

  -- purpose: Process to calculate Saturation current
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: saturation current
  iSat_proc : process (adc_clk) is
  begin
    if rising_edge(adc_clk) then
      if index = to_unsigned(2, 3) then
        iSat <= signed(divider_dout(31 downto 16));
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
        divisor  <= std_logic_vector(volt1 - vFloat);
        dividend <= std_logic_vector(temp);
        tUser    <= std_logic_vector(to_unsigned(1, tUser'length));
        diff_set <= '1';
        storeSig <= volt_in;
      else
        diff_set <= '0';
      end if;
      if index = to_unsigned(1, 3) then
        waitBRAM <= '1';
      else
        waitBRAM <= '0';
      end if;
      if exp_en = '1' then
        divisor  <= std_logic_vector(storeSig);
        dividend <= std_logic_vector(outBRAM);
        tUser    <= std_logic_vector(to_unsigned(2, tUser'length));
      end if;
      if clk_en = '0' and exp_en = '0' then
        tUser <= std_logic_vector(to_unsigned(0, tUser'length));
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
