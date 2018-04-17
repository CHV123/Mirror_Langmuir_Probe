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

entity TempCalc is
  generic (
    Temp_guess	 : integer := 20;
    iSat_guess	 : integer := -20;
    vFloat_guess : integer := 0);
  port (
    adc_clk	  : in std_logic;	-- adc input clock
    vFloat	  : in std_logic_vector(15 downto 0);  -- Floating Voltage input
    iSat	  : in std_logic_vector(15 downto 0);  -- Temperature input
    BRAMret	  : in std_logic_vector(15 downto 0);  -- data returned by BRAM
    volt_in	  : in std_logic_vector(13 downto 0);  -- Voltage input
    volt2	  : in std_logic_vector(13 downto 0);
    clk_en	  : in std_logic;	-- Clock Enable to set period start
    divider_tdata : in std_logic_vector(31 downto 0);
    divider_tuser : in std_logic_vector(1 downto 0);

    divisor_tdata   : out std_logic_vector(15 downto 0);
    divisor_tvalid  : out std_logic;
    dividend_tdata  : out std_logic_vector(15 downto 0);
    dividend_tvalid : out std_logic;
    dividend_tuser  : out std_logic_vector(1 downto 0);
    BRAM_addr	    : out std_logic_vector(13 downto 0);  -- BRAM address out
    Temp	    : out std_logic_vector(15 downto 0);  -- Saturation current
    data_valid	    : out std_logic);  -- valid to propagate to float and temp block

end entity TempCalc;

architecture Behavioral of TempCalc is

  signal exp_count : integer range 0 to 31 := 0;
  signal exp_en	   : std_logic		   := '0';
  signal exp_ret   : signed(13 downto 0)   := (others => '0');
  signal index	   : unsigned(1 downto 0)  := (others => '0');
  signal div0	   : std_logic		   := '0';
  signal diff_set  : std_logic		   := '0';
  signal tot_lat   : integer range 0 to 31 := 0;
  signal waitBRAM  : std_logic		   := '0';  -- Signal to indicate when
						    -- to wait for the bram return
  signal storeSig1 : signed(15 downto 0)   := (others => '0');
  signal storeSig2 : signed(13 downto 0)   := (others => '0');

  signal Temp_mask : signed(31 downto 0) := to_signed(Temp_guess, 32);

  signal addr_mask_store : integer := 0;
  signal int_store	 : integer := 0;
  signal rem_store	 : integer := 0;

begin  -- architecture Behavioral

  index <= unsigned(divider_tuser);
  Temp	<= std_logic_vector(Temp_mask(15 downto 0));

  -- purpose: Process to calculate Saturation current
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: saturation current
  temp_proc : process (adc_clk) is
  begin
    if rising_edge(adc_clk) then
      if exp_en = '1' then
	Temp_mask  <= shift_right((storeSig2 - storeSig1) * signed(BRAMret), 1);
	data_valid <= '1';
      else
	data_valid <= '0';
      end if;
    end if;
  end process temp_proc;

  -- purpose: process to set the divisor and dividend for the divider
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: divisor, dividend, tUser
  div_proc : process (adc_clk) is
  begin	 -- process diff_proc
    if rising_edge(adc_clk) then
      if clk_en = '1' then
	divisor_tdata	<= std_logic_vector(to_signed(to_integer(signed(iSat)), dividend_tdata'length));
	dividend_tdata	<= std_logic_vector(to_signed(to_integer(signed(volt_in)), divisor_tdata'length));
	dividend_tuser	<= std_logic_vector(to_unsigned(1, dividend_tuser'length));
	dividend_tvalid <= '1';
	divisor_tvalid	<= '1';
	diff_set	<= '1';
	storeSig1	<= signed(vFloat);
	storeSig2	<= signed(volt2);
      else
	divisor_tdata	<= (others => '0');
	dividend_tdata	<= (others => '0');
	dividend_tuser	<= (others => '0');
	dividend_tvalid <= '0';
	divisor_tvalid	<= '0';
	diff_set	<= '0';
      end if;
    end if;
  end process div_proc;

  -- purpose: process to set the BRAM address for data data retrieval.
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: BRAM_addr, waitBRAM
  BRAM_proc : process (adc_clk) is
    variable divider_int : signed(13 downto 0) := (others => '0');
    variable divider_rem : signed(11 downto 0) := (others => '0');
    variable addr_mask	 : integer	       := 0;
  begin	 -- process BRAM_proc
    if rising_edge(adc_clk) then
      if index = to_unsigned(1, index'length) then
	-- Extracting the integer part and the fractional part returned by the
	-- divider core to use in the bram address mapping
	divider_rem := signed(divider_tdata(11 downto 0));
	divider_int := signed(divider_tdata(25 downto 12));
	int_store   <= to_integer(divider_int);
	rem_store   <= to_integer(divider_rem);
	if divider_int = to_signed(-1, 14) then
	  addr_mask := 0;
	elsif divider_int = to_signed(0, 14) then
	  addr_mask := 2048 + to_integer(divider_rem);
	elsif divider_int = to_signed(1, 14) then
	  addr_mask := 4096 + to_integer(divider_rem);
	elsif divider_int = to_signed(2, 14) then
	  addr_mask := 6144 + to_integer(divider_rem);
	elsif divider_int = to_signed(3, 14) then
	  addr_mask := 8192 + to_integer(divider_rem);
	elsif divider_int = to_signed(4, 14) then
	  addr_mask := 10240 + to_integer(divider_rem);
	elsif divider_int = to_signed(5, 14) then
	  addr_mask := 12288 + to_integer(divider_rem);
	elsif divider_int = to_signed(6, 14) then
	  addr_mask := 14336 + to_integer(divider_rem);
	else
	  if divider_int < to_signed(-1, 14) then
	    addr_mask := 0;
	  elsif divider_int >= to_signed(7, 14) then
	    addr_mask := 16383;
	  end if;
	end if;
	addr_mask_store <= addr_mask;
	BRAM_addr	<= std_logic_vector(to_unsigned(addr_mask, 14));
	waitBRAM	<= '1';
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
  begin	 -- process collect_proc
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
	exp_en	  <= '0';
      end if;
    end if;
  end process collect_proc;

end architecture Behavioral;
