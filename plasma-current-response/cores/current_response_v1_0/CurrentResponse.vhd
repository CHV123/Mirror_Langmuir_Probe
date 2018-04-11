-------------------------------------------------------------------------------
-- Module to set 3 different voltages levels for inital MLP demonstration
-- Started on March 26th by Charlie Vincent
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CurrentResponse is
    -- adjustment for non-divisible periods

  port (
    adc_clk : in std_logic;             -- adc input clock
    T_electron_in : in signed(13 downto 0); 
    I_sat : in signed(13 downto 0);
    V_floating : in signed(13 downto 0);
    Expo_result : in signed(13 downto 0);
    Expo_result_tvalid : in std_logic;
    Bias_voltage : in signed(13 downto 0);
    Resistence : in signed(13 downto 0);


    V_LP : out signed(13 downto 0);
    V_LP_tvalid : out std_logic;
    T_electron_out : out signed(13 downto 0);
    T_electron_out_tvalid : out std_logic;
    V_curr : out signed(13 downto 0)
    );

end entity CurrentResponse;

architecture Behavioral of CurrentResponse is

begin  -- architecture Behavioral
T_electron_out_tvalid <= '1';
V_LP_tvalid <= '1';


	Pass_through : process(adc_clk)
	begin
		if (rising_edge(adc_clk)) then
			-- Passing electron temerature through to the Div block 
			T_electron_out <= T_electron_in;

			-- Calculate the diffrence in voltages
			V_LP <= Bias_voltage - V_floating;
		end if;
	end process;

	-- Take the input from Div and Expo blocks
    first_mltp : process(adc_clk)     
    variable V_curr_mask : integer := 0; 
    begin
    	if (rising_edge(adc_clk)) then
    		V_curr_mask := to_integer(Resistence)*to_integer(I_sat)*(1-to_integer(Expo_result));
    		V_curr <= shift_right(to_signed(V_curr_mask,42), 10)(13 downto 0);
    	end if; 
    end process;


end architecture Behavioral;
