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
    T_electron_in : in std_logic_vector(13 downto 0); 
    I_sat : in std_logic_vector(13 downto 0);
    V_floating : in std_logic_vector(13 downto 0);
    Expo_result : in std_logic_vector(13 downto 0);
    Expo_int_result : in std_logic_vector(13 Downto 0);
    Expo_result_tvalid : in std_logic;
    Bias_voltage : in std_logic_vector(13 downto 0);
    Resistence : in std_logic_vector(13 downto 0);
    Cap_Bias : in std_logic_vector(15 downto 0);
    Cap_Bias_tvalid: in std_logic;

    V_LP : out std_logic_vector(13 downto 0);
    V_LP_tvalid : out std_logic;
    T_electron_out : out std_logic_vector(13 downto 0);
    T_electron_out_tvalid : out std_logic;
    V_curr : out std_logic_vector(13 downto 0);
    Cap_charge : out std_logic_vector(15 downto 0);
    Cap_charge_tvalid : out std_logic;
    Curr_out : out std_logic_vector(13 downto 0)
    );

end entity CurrentResponse;

architecture Behavioral of CurrentResponse is
  signal V_curr_mask : integer := 0;
  signal V_curr_mask_hold_1 : integer := 0;
  signal V_curr_mask_hold_2 : integer := 0;

  signal Expo_int_result_pass_1 : std_logic_vector(13 downto 0) := (others => '0');
  signal Expo_int_result_pass_2 : std_logic_vector(13 downto 0) := (others => '0');
  signal Expo_int_result_pass_3 : std_logic_vector(13 downto 0) := (others => '0');

  signal Curr : signed(13 downto 0) := (others => '0');

 begin  -- architecture Behavioral

	Pass_through : process(adc_clk)
	variable T_electron_out_tvalid_mask : std_logic :='0';
	variable V_LP_tvalid_mask : std_logic :='0';
	begin
		if (rising_edge(adc_clk)) then
			-- Passing electron temerature through to the Div block 
			T_electron_out <= T_electron_in;
			if to_integer(signed(T_electron_in)) /= 0 then
			-- Calculate the diffrence in voltages
			T_electron_out_tvalid_mask := '1';
			V_LP_tvalid_mask := '1';
			end if;
			T_electron_out_tvalid <= T_electron_out_tvalid_mask;
			V_LP_tvalid <= V_LP_tvalid_mask;

            if Cap_Bias_tvalid = '0' then
            V_LP <= std_logic_vector(shift_right(signed(Bias_voltage), 3) - signed(V_floating));
            else
              V_LP <= std_logic_vector(shift_right(signed(Bias_voltage), 3) - to_signed(to_integer(signed(Cap_Bias)),V_floating'length) - signed(V_floating));  
            end if;
		end if;
	end process;



	-- Take the input from Div and Expo blocks
    first_mltp : process(adc_clk)     
    begin
       	if (rising_edge(adc_clk)) then
    		V_curr_mask_hold_1 <= to_integer(signed(Expo_result)) * 8;
            Expo_int_result_pass_1 <= Expo_int_result;
    	end if; 
    end process;

    -- Take the input from Div and Expo blocks
    second_mltp : process(adc_clk)     
    begin
        if (rising_edge(adc_clk)) then
            V_curr_mask_hold_2 <= to_integer(signed(I_sat))* V_curr_mask_hold_1;
            Expo_int_result_pass_2 <= Expo_int_result_pass_1;
        end if; 
    end process;

    third_mltp : process(adc_clk)     
    begin
        if (rising_edge(adc_clk)) then
            V_curr_mask <= to_integer(signed(Resistence))* V_curr_mask_hold_2;
            Expo_int_result_pass_3 <= Expo_int_result_pass_2;
        end if; 
    end process;

    -- Take the input from Div and Expo blocks
    fourth_mltp : process(adc_clk)     
    begin
        if (rising_edge(adc_clk)) then
            case to_integer(signed(Expo_int_result_pass_3))  is
                when 7 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 1)(13 downto 0));
                when 6 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 2)(13 downto 0));
                when 5 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 4)(13 downto 0));
                when 4 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 5)(13 downto 0));
                when 3 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 7)(13 downto 0));
                when 2 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 8)(13 downto 0));
                when 1 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 10)(13 downto 0));
                when 0 => V_curr <=   std_logic_vector(shift_right(to_signed(V_curr_mask,42), 12)(13 downto 0));
                when others => V_curr <=  std_logic_vector(shift_right(to_signed(V_curr_mask,42), 13)(13 downto 0));
            end case;
        end if; 
    end process;


    Current_mltp : process(adc_clk)     

    begin
        if (rising_edge(adc_clk)) then
            
            case to_integer(signed(Expo_int_result))  is
                when 7 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 1)(13 downto 0);
                when 6 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 2)(13 downto 0);
                when 5 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 4)(13 downto 0);
                when 4 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 5)(13 downto 0);
                when 3 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 7)(13 downto 0);
                when 2 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 8)(13 downto 0);
                when 1 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 10)(13 downto 0);
                when 0 => Curr <=   shift_right(to_signed(V_curr_mask_hold_2,42), 12)(13 downto 0);
                when others => Curr <=  shift_right(to_signed(V_curr_mask_hold_2,42), 13)(13 downto 0);
            end case;
            Curr_out <= std_logic_vector(Curr);
        end if; 
    end process;


    Current_mltp_two : process(adc_clk)
  	variable Charge_mask : signed(15 downto 0) := (others => '0');
  	variable Cap_charge_mask_tvalid : std_logic := '0';
    begin
        if (rising_edge(adc_clk)) then
           Charge_mask := Charge_mask + shift_left(Curr,3);
           Cap_charge <= std_logic_vector(Charge_mask);
           Cap_charge_mask_tvalid := '1';
           Cap_charge_tvalid <= Cap_charge_mask_tvalid;
        end if; 
    end process;



end architecture Behavioral;
