-------------------------------------------------------------------------------
-- Module to calculate the floating potential of a langmuir probe for use in
-- the MLP instrument.
-- Started on March 26th by Charlie Vincent
-- period + adjust
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vFloatCalc is
  generic (
    Temp_guess	 : integer := 20;
    iSat_guess	 : integer := 50;
    vFloat_guess : integer := 0);
  port (
    adc_clk	  : in std_logic;	-- adc input clock
    iSat	  : in std_logic_vector(15 downto 0);  -- Floating Voltage input
    Temp	  : in std_logic_vector(15 downto 0);  -- Temperature input
    BRAMret	  : in std_logic_vector(13 downto 0);  -- data returned by BRAM
    volt_in	  : in std_logic_vector(13 downto 0);  -- Voltage input
    clk_en	  : in std_logic;	-- Clock Enable to set period start
    divider_tdata : in std_logic_vector(31 downto 0);
    divider_tuser : in std_logic_vector(1 downto 0);

    divisor_tdata   : out std_logic_vector(15 downto 0);
    divisor_tvalid  : out std_logic;
    dividend_tdata  : out std_logic_vector(15 downto 0);
    dividend_tvalid : out std_logic;
    dividend_tuser  : out std_logic_vector(1 downto 0);
    BRAM_addr	    : out std_logic_vector(13 downto 0);  -- BRAM address out
    vFloat	    : out std_logic_vector(15 downto 0);  -- Saturation current
    data_valid	    : out std_logic);  -- valid to propagate to float and temp block

end entity vFloatCalc;

architecture Behavioral of vFloatCalc is

  signal exp_count : integer range 0 to 31 := 0;
  signal exp_en	   : std_logic		   := '0';
  signal exp_ret   : signed(13 downto 0)   := (others => '0');
  signal index	   : unsigned(1 downto 0)  := (others => '0');
  signal div0	   : std_logic		   := '0';
  signal diff_set  : std_logic		   := '0';
  signal tot_lat   : integer range 0 to 31 := 0;
  signal waitBRAM  : std_logic		   := '0';  -- Signal to indicate when
						    -- to wait for the bram return
  signal storeSig  : signed(15 downto 0)   := (others => '0');

  signal vFloat_mask : signed(29 downto 0) := to_signed(vFloat_guess, 30);

  signal addr_mask_store : integer := 0;
  signal int_store	 : integer := 0;
  signal rem_store	 : integer := 0;

begin  -- architecture Behavioral

  index	 <= unsigned(divider_tuser);
  vFloat <= std_logic_vector(vFloat_mask(15 downto 0));

  -- purpose: Process to calculate Saturation current
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: saturation current
  vFloat_proc : process (adc_clk) is
  begin
    if rising_edge(adc_clk) then
      if exp_en = '1' then
	vFloat_mask <= shift_right(0 - (storeSig * signed(BRAMret)), 7);
	data_valid  <= '1';
      else
	data_valid <= '0';
      end if;
    end if;
  end process vFloat_proc;

  -- purpose: process to set the divisor and dividend for the divider
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: divisor, dividend, tUser
  div_proc : process (adc_clk) is
  begin	 -- process diff_proc
    if rising_edge(adc_clk) then
      if clk_en = '1' then
	if unsigned(iSat) > 0 then
	  divisor_tdata <= "00" & std_logic_vector(to_signed(to_integer(signed(iSat)), 14));
	else
	  divisor_tdata <= "00" & std_logic_vector(to_signed(iSat_guess, 14));
	end if;
	dividend_tdata	<= "00" & std_logic_vector(to_signed(to_integer(signed(volt_in)), 14));
	dividend_tuser	<= std_logic_vector(to_unsigned(1, dividend_tuser'length));
	dividend_tvalid <= '1';
	divisor_tvalid	<= '1';
	diff_set	<= '1';
	storeSig	<= signed(Temp);
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
    variable divider_rem : signed(12 downto 0) := (others => '0');
    variable addr_mask	 : integer	       := 0;
  begin	 -- process BRAM_proc
    if rising_edge(adc_clk) then
      if index = to_unsigned(1, index'length) then
	-- Extracting the integer part and the fractional part returned by the
	-- divider core to use in the bram address mapping
	divider_rem := signed(divider_tdata(12 downto 0));
	divider_int := signed(divider_tdata(26 downto 13));
	int_store   <= to_integer(divider_int);
	rem_store   <= to_integer(divider_rem);
	if divider_int = to_signed(-1, 14) then
	  addr_mask := 0;
	elsif divider_int = to_signed(0, 14) then
	  addr_mask := 4096 + to_integer(divider_rem);
	elsif divider_int = to_signed(1, 14) then
	  addr_mask := 8192 + to_integer(divider_rem);
	elsif divider_int = to_signed(2, 14) then
	  addr_mask := 12288 + to_integer(divider_rem);
	else
	  if divider_int < to_signed(-1, 14) then
	    addr_mask := 0;
	  elsif divider_int >= to_signed(3, 14) then
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
