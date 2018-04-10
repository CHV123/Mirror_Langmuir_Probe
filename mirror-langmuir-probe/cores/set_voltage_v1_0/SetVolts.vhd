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
    period  : integer := 25;		  -- level duration
    negBias : integer := -3;
    posBias : integer := 1
    );
  port (
    adc_clk    : in std_logic;		  -- adc input clock
    period_in  : in unsigned(31 downto 0);
    Temp       : in signed(13 downto 0);  -- Temperature sets the voltage bias
    Temp_valid : in std_logic;

    volt_out  : out signed(13 downto 0);
    iSat_en   : out std_logic;
    vFloat_en : out std_logic;
    Temp_en   : out std_logic;
    volt1     : out signed(13 downto 0);
    volt2     : out signed(13 downto 0)
    );

end entity SetVolts;

architecture Behavioral of SetVolts is
  signal output	    : signed(13 downto 0)	   := (others => '0');	-- mask for the output voltage
  signal counter    : integer			   := 0;  -- counter for setting the voltage levels
  signal level	    : integer range 0 to 2	   := 0;  -- counter for registering the voltage levels
  signal TempMask   : signed(13 downto 0)	   := (others => '0');
  signal volt_ready : std_logic_vector(1 downto 0) := (others => '0');

  signal period_mask : integer := period;

  constant latency : integer := 22;

begin  -- architecture Behavioral

  -- Process to define the level period
  period_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      if to_integer(period_in) > period then
	period_mask <= period;
      else
	period_mask <= period;
      end if;
    end if;
  end process;

  -- purpose: Process to check when temperature calculation is ready
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: TempMask
  temp_check_proc : process (adc_clk) is
  begin	 -- process temp_check_proc
    if rising_edge(adc_clk) then
      if Temp_valid = '1' then
	TempMask <= Temp;
      end if;
    end if;
  end process temp_check_proc;

  -- purpose: process to set which calculation to do
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: iSat_en, vFloat_en, Temp_en
  calc_proc : process (adc_clk) is
    variable change_en	 : std_logic_vector(1 downto 0) := "00";
    variable iSat_mask	 : std_logic			:= '0';
    variable vFloat_mask : std_logic			:= '0';
    variable Temp_mask	 : std_logic			:= '0';
  begin	 -- process calc_proc
    if rising_edge(adc_clk) then
      if volt_ready = "01" then
	if iSat_mask = '0' and change_en = "00" then
	  iSat_en   <= '1';
	  iSat_mask := '1';
	  change_en := "01";
	else
	  iSat_en   <= '0';
	  iSat_mask := '0';
	end if;
      elsif volt_ready = "10" then
	if vFloat_mask = '0' and change_en = "01" then
	  vFloat_en   <= '1';
	  vFloat_mask := '1';
	  change_en   := "10";
	else
	  vFloat_en   <= '0';
	  vFloat_mask := '0';
	end if;
      elsif volt_ready = "11" then
	if Temp_mask = '0' and change_en = "10" then
	  Temp_en   <= '1';
	  Temp_mask := '1';
	  change_en := "00";
	else
	  Temp_en   <= '0';
	  Temp_mask := '0';
	end if;
      else
	Temp_en	  <= '0';
	iSat_en	  <= '0';
	vFloat_en <= '0';
      end if;
    end if;
  end process calc_proc;

  -- Process to advance bias counter
  level_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      counter <= counter + 1;
      if level = 2 then
	if Temp_valid = '1' then
	  level	  <= 0;
	  counter <= 0;
	end if;	 -- end of counter descision
      else
	if counter = period_mask then
	  level	  <= level + 1;
	  counter <= 0;
	end if;	 -- end of counter decision
      end if;  -- end of level descision
    end if;  -- end of rising edge
  end process;

  -- Setting the output to various voltage levels
  set_proc : process(adc_clk)
    variable outMask : signed(27 downto 0) := (others => '0');
  begin
    if rising_edge(adc_clk) then
      case level is
	when 0 =>
	  outMask    := to_signed(NegBias * to_integer(TempMask), 28);
	  output     <= outMask(13 downto 0);
	  volt1	     <= outMask(13 downto 0);
	  volt_ready <= "01";
	when 1 =>
	  outMask    := to_signed(PosBias * to_integer(TempMask), 28);
	  output     <= outMask(13 downto 0);
	  volt2	     <= outMask(13 downto 0);
	  volt_ready <= "10";
	when 2 =>
	  output     <= (others => '0');
	  volt_ready <= "11";
	when others =>
	  output     <= (others => '0');
	  volt_ready <= "00";
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
