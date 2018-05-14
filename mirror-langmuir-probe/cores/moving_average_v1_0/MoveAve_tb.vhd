-------------------------------------------------------------------------------
-- Title      : Testbench for design "MoveAve"
-- Project    : 
-------------------------------------------------------------------------------
-- File       : MoveAve_tb.vhd
-- Author     : Vincent  <charlesv@cmodws122.psfc.mit.edu>
-- Company    : 
-- Created    : 2018-04-25
-- Last update: 2018-05-14
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-04-25  1.0      charlesv	Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------

entity MoveAve_tb is

end entity MoveAve_tb;

-------------------------------------------------------------------------------

architecture behaviour of MoveAve_tb is

  -- component ports
  signal adc_clk  : std_logic                     := '0';
  signal volt_in  : std_logic_vector(13 downto 0) := (others => '0');
  signal clk_rst  : std_logic                     := '0';
  signal volt_out : std_logic_vector(13 downto 0);

  -- clock
  constant Clk_period : time := 10 ns;
  signal Clk : std_logic := '1';

  -- Simulation signals
  signal switch : std_logic := '0';

begin  -- architecture behaviour

  -- component instantiation
  DUT: entity work.MoveAve
    port map (
      adc_clk  => adc_clk,
      volt_in  => volt_in,
      clk_rst  => clk_rst,
      volt_out => volt_out);

  -- clock generation
  Clk <= not Clk after Clk_period/2;
  adc_clk <= Clk;

  -- waveform generation
  WaveGen_Proc: process
  begin
    -- insert signal assignments here
    --if switch = '0' then
    --  volt_in <= std_logic_vector(signed(volt_in) + 3);
    --else
    --  volt_in <= std_logic_vector(signed(volt_in) - 2);
    --end if;
    wait until Clk = '1';
  end process WaveGen_Proc;

  -- purpose: Process to switch between addition and subtraction
  -- type   : combinational
  -- inputs : 
  -- outputs: switch
  switch_proc: process is
  begin  -- process switch_proc
    wait for Clk_period * 45;
    volt_in <= std_logic_vector(to_signed(40, 14));
    wait for Clk_period * 45;
    volt_in <= std_logic_vector(to_signed(0, 14));
    wait for Clk_period * 45;
    volt_in <= std_logic_vector(to_signed(-120, 14));
  end process switch_proc;  

end architecture behaviour;

-------------------------------------------------------------------------------

configuration MoveAve_tb_behaviour_cfg of MoveAve_tb is
  for behaviour
  end for;
end MoveAve_tb_behaviour_cfg;

-------------------------------------------------------------------------------
