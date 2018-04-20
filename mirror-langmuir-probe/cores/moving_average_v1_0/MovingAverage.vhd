-------------------------------------------------------------------------------
-- Module to calculate a moving average for the MLP input voltage 
-- April 19th by Charlie Vincent
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity MoveAve is
  generic (
    Samples : integer range 0 to 5 := 5
    );
  port (
    adc_clk : in std_logic;		-- adc input clock
    volt_in : in std_logic_vector(13 downto 0);
    clk_rst : in std_logic;

    volt_out : out std_logic_vector(13 downto 0);
    );

end entity MoveAve;

architecture Behavioral of MoveAve is

  signal scale : integer range 0 to 63 := 0;
  signal full  : std_logic		:= '0';	 -- signal to specify wether the full range of values has been stored or not
  signal sum   : signed(13 downto 0)	:= (others => '0');

begin  -- architecture Behavioral

  -- purpose: Process to set the scale of smoothing. Higher means more smoothing
  -- type   : combinational
  -- inputs : Samples
  -- outputs: scale
  scale_proc : process (Samples) is
  begin	 -- process scale_proc
    case Samples is
      when 0	  => scale <= 1;
      when 1	  => scale <= 2;
      when 2	  => scale <= 4;
      when 3	  => scale <= 8;
      when 4	  => scale <= 16;
      when 5	  => scale <= 32;
      when others => null;
    end case;
  end process scale_proc;

  -- purpose: Process to sum the requisite number of values for the moving average
  -- type   : sequential
  -- inputs : adc_clk, clk_rst, volt_in
  -- outputs: volt_sum
  sum_proc : process (adc_clk) is
    variable counter : integer range 0 to 63 := 0;
    variable full_prev : std_logic := '0';
    variable sum_store : signed(13 downto 0) := (others <= '0');
  begin	 -- process sum_proc
    if rising_edge(adc_clk) then	-- rising clock edge
      if clk_rst = '1' then		-- synchronous reset (active high)
	full <= '0';
	sum <= (others => '0');
	counter <= 0;
      else
	if counter /= scale then
	  if counter = 0 then
	    sum_store := signed(shift_right(volt_in, Samples));
	  end if;
	  sum <= sum + signed(shift_right(volt_in, Samples));
	  counter <= counter + 1;
	else
	  full <= '1';
	  
	end if;
      end if;
      full_prev := full;
    end if;
  end process sum_proc;

end architecture Behavioral;
