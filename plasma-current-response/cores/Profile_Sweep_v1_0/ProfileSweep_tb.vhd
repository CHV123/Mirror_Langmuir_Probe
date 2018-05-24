-------------------------------------------------------------------------------
-- Test bench for the SetVolts vhdl module
-------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;

entity tb_ProfileSweep is

end entity tb_ProfileSweep;

architecture behaviour of tb_ProfileSweep is

  ---------------------- ProfileSweep Block Component-------------------------
  component ProfileSweep is
    port (
    adc_clk : in std_logic;             -- adc input clock
    reset : in std_logic;

    Profile_address : out std_logic_vector(13 downto 0)
      );
  end component ProfileSweep;

---------------------Signals for the ProfileSweep Block-----------------------
  -- input signals
  signal adc_clk : std_logic           := '0';
  signal Profile_address : std_logic_vector(13 downto 0) := (others => '0');
  signal reset : std_logic := '0';

  constant adc_clk_period : time := 8 ns; 
  
  


  
begin  -- architecture behaviour
  -- Instantiating test unit
  
 
  
  your_instance_name : ProfileSweep
    PORT MAP (
    	-- Inputs
      adc_clk => adc_clk,
      reset => reset,

  		-- Outputs
      Profile_address => Profile_address
    );
  
  
  -- Clock process definitions
  adc_clk_process : process
  begin
    adc_clk <= '0';
    wait for adc_clk_period/2;
    adc_clk <= '1';
    wait for adc_clk_period/2;
  end process;

  -- Stimulus process
  stim_proc : process
  begin
 	  reset <= '0';
    wait for adc_clk_period*10000;
    reset <= '1';
    wait for  adc_clk_period*1;
    
end process;









end architecture behaviour;
