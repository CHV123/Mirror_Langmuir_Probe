-------------------------------------------------------------------------------
-- Test bench for the SetVolts vhdl module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_FullTest is

end entity tb_FullTest;

architecture behaviour of tb_FullTest is
  ----------------------PCR Moduels Block Component 
component Current_response_test is
	port (
		clk : in STD_LOGIC := '0';
		Isat : in STD_LOGIC_vector(13 downto 0);
		Resistence : in STD_LOGIC_vector(13 downto 0);
		Temp : in STD_LOGIC_vector(13 downto 0);
		Vf : in STD_LOGIC_vector(13 downto 0);
		Bias : in STD_LOGIC_vector(13 downto 0);
		Capacitance : in STD_LOGIC_vector(15 downto 0);
        Capacitance_tvalid : in std_logic;
		Current : out STD_LOGIC_vector(13 downto 0)
	);
end component Current_response_test;

signal  input_clk : std_logic := '0';
signal  Isat : STD_LOGIC_vector(13 downto 0) := (others => '0');
signal  Resistence : STD_LOGIC_vector(13 downto 0) := (others => '0');
signal  Temp : STD_LOGIC_vector(13 downto 0) := (others => '0');
signal  Vf : STD_LOGIC_vector(13 downto 0) := (others => '0');
signal  Bias : STD_LOGIC_vector(13 downto 0) := (others => '0');
signal  Capacitance : STD_LOGIC_vector(15 downto 0) := (others => '0');
signal  Capacitance_tvalid : std_logic := '0';
        
signal  Current : STD_LOGIC_vector(13 downto 0) := (others => '0');

constant adc_clk_period : time := 8 ns; 

begin  -- architecture behaviour
  
instance_name : Current_response_test
port map (
	clk => input_clk,
	Isat => Isat,
	Resistence => Resistence,
	Temp => Temp,
	Vf => Vf,
	Bias => Bias,

	Current => Current,
	Capacitance_tvalid => Capacitance_tvalid,
	Capacitance => Capacitance
);



	-- Clock process definitions
  adc_clk_process : process
  begin
    input_clk <= '1';
    wait for adc_clk_period/2;
    input_clk <= '0';
    wait for adc_clk_period/2;
  end process;


stm_proc : process
begin
	wait for adc_clk_period*100;
	Isat <= STD_LOGIC_vector(to_signed(2,Isat'length));
	Resistence <= STD_LOGIC_vector(to_signed(50,Resistence'length));
	Temp <= STD_LOGIC_vector(to_signed(100,Temp'length));
	Vf <= STD_LOGIC_vector(to_signed(0,Vf'length));
	Capacitance <= STD_LOGIC_vector(to_signed(100,Capacitance'length));
	Capacitance_tvalid <= '1';
	Bias <= STD_LOGIC_vector(to_signed(-300,Bias'length));
	wait for adc_clk_period*100;
	Bias <= STD_LOGIC_vector(to_signed(100,Bias'length));
	wait for adc_clk_period*100;
	Bias <= STD_LOGIC_vector(to_signed(0,Bias'length));



end process;

end architecture behaviour;
