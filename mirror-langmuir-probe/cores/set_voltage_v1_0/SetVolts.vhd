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
    period     : integer := 38;
    Temp_guess : integer := 1000;
    negBias    : integer := -3;
    posBias    : integer := 1
    );
  port (
    adc_clk    : in std_logic;		-- adc input clock
    period_in  : in std_logic_vector(31 downto 0);
    Temp       : in std_logic_vector(15 downto 0);  -- Temperature sets the voltage bias
    Temp_valid : in std_logic;
    --vFloat_valid : in std_logic;
    --iSat_valid   : in std_logic;

    volt_out  : out std_logic_vector(13 downto 0);
    iSat_en   : out std_logic;
    vFloat_en : out std_logic;
    Temp_en   : out std_logic;
    volt1     : out std_logic_vector(13 downto 0);
    volt2     : out std_logic_vector(13 downto 0)
    );

end entity SetVolts;

architecture Behavioral of SetVolts is
  signal output	    : signed(13 downto 0)	   := (others => '0');	-- mask for the output voltage
  signal counter    : integer			   := 0;  -- counter for setting the voltage levels
  signal level	    : integer range 0 to 2	   := 0;  -- counter for registering the voltage levels
  signal TempMask   : signed(15 downto 0)	   := to_signed(Temp_guess, 16);
  signal volt_ready : std_logic_vector(1 downto 0) := (others => '0');

  signal period_mask : integer := period;

  constant latency : integer := 22;

begin  -- architecture Behavioral

  -- Process to define the level period
  period_proc : process(adc_clk)
  begin
    if rising_edge(adc_clk) then
      if to_integer(unsigned(period_in)) > period then
	period_mask <= to_integer(unsigned(period_in));
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
	if signed(Temp) > to_signed(0, Temp'length) then
	  TempMask <= signed(Temp);
	else
	  TempMask <= to_signed(Temp_guess, TempMask'length);
	end if;
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
	if Temp_mask = '0' and change_en = "01" then
	  Temp_en   <= '1';
	  Temp_mask := '1';
	  change_en := "10";
	else
	  Temp_en   <= '0';
	  Temp_mask := '0';
	end if;
      elsif volt_ready = "11" then
	if vFloat_mask = '0' and change_en = "10" then
	  vFloat_en   <= '1';
	  vFloat_mask := '1';
	  change_en   := "00";
	else
	  vFloat_en   <= '0';
	  vFloat_mask := '0';
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
	if counter = period_mask - 1 then
	  counter <= 0;
	  level	  <= 0;
	end if;
      else
	if counter = period_mask - 1 then
	  level	  <= level + 1;
	  counter <= 0;
	end if;	 -- end of counter decision
      end if;
    end if;  -- end of rising edge
  end process;

  -- purpose: Process to set when each calculation module is enabled
  -- type   : combinational
  -- inputs : adc_clk
  -- outputs: volt_ready
  en_calc_proc : process (adc_clk) is
  begin	 -- process en_calc_proc
    if counter = period_mask - 3 then
      case level is
	when 0	    => volt_ready <= "01";
	when 1	    => volt_ready <= "10";
	when 2	    => volt_ready <= "11";
	when others => null;
      end case;
    end if;
  end process en_calc_proc;


  -- Setting the output to various voltage levels
  set_proc : process(adc_clk)
    variable outMask	: signed(27 downto 0) := (others => '0');
    variable level_prev : integer	      := 0;
  begin
    if rising_edge(adc_clk) then
      if level_prev /= level then
	if level = 0 then
	  outMask := to_signed(NegBias * to_integer(TempMask), 28);
	  volt1	  <= std_logic_vector(outMask(13 downto 0));
	elsif level = 1 then
	  outMask := to_signed(PosBias * to_integer(TempMask), 28);
	  volt2	  <= std_logic_vector(outMask(13 downto 0));
	elsif level = 2 then
	  outMask := to_signed(0, 28);
	end if;
      end if;
      output	 <= outMask(13 downto 0);
      level_prev := level;
    end if;
  end process;

  volt_out <= std_logic_vector(output);

end architecture Behavioral;
