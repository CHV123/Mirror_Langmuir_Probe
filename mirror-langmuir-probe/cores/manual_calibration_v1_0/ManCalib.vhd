-------------------------------------------------------------------------------
-- Title      : Manual Calibration module for MLP instrument
-- Project    : 
-------------------------------------------------------------------------------
-- File       : ManCalib.vhd
-- Author     : root  <root@cmodws122.psfc.mit.edu>
-- Company    : 
-- Created    : 2018-05-03
-- Last update: 2018-05-04
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Module to adjust the voltage inputs such that they match the
-- output of the paired instrument
-------------------------------------------------------------------------------
-- Copyright (c) 2018 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2018-05-03  1.0      CharlieV        Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Calibrate is

  port (
    adc_clk  : in  std_logic;
    clk_rst  : in  std_logic;
    scale    : in  std_logic_vector(13 downto 0);
    offset   : in  std_logic_vector(13 downto 0);
    volt_in  : in  std_logic_vector(13 downto 0);
    volt_out : out std_logic_vector(13 downto 0)
    );

end entity Calibrate;

architecture behaviour of Calibrate is

  signal scale_proxy : signed(13 downto 0) := to_signed(1024, 14);
  signal offset_proxy : signed(13 downto 0) := to_signed(0, 14);

begin  -- architecture behaviour

  -- purpose: Process to apply the scaling and offset to the input voltage
  -- type   : sequential
  -- inputs : adc_clk, clk_rst, volt_in, scale, offset
  -- outputs: volt_out
  apply_proc : process (adc_clk) is
    variable volt_proxy : signed(27 downto 0) := (others => '0');
  begin  -- process apply_proc
    if rising_edge(adc_clk) then        -- rising clock edge
      if clk_rst = '1' then             -- synchronous reset (active high)
        volt_out <= (others => '0');
      else
        volt_proxy := shift_right(scale_proxy*signed(volt_in), 10);
        volt_out   <= std_logic_vector(volt_proxy(13 downto 0) + offset_proxy);
      end if;
    end if;
  end process apply_proc;

  -- purpose: Process to set the scale and offset values and reset them to defaults
  -- type   : sequential
  -- inputs : adc_clk, clk_rst, scale
  -- outputs: scale_proxy, offset_proxy
  proxy_proc: process (adc_clk) is
  begin  -- process proxy_proc
    if rising_edge(adc_clk) then       -- rising clock edge
      if clk_rst = '1' then             -- synchronous reset (active high)
        scale_proxy <= to_signed(1025, 14);
        offset_proxy <= to_signed(0, 14);
      else
        if scale = std_logic_vector(to_signed(0, 14)) then
          scale_proxy <= scale_proxy;
        else          
          scale_proxy <= signed(scale);
        end if;
        if offset = std_logic_vector(to_signed(0, 14)) then
          offset_proxy <= offset_proxy;
        else          
          offset_proxy <= signed(offset);
        end if;
      end if;
    end if;
  end process proxy_proc;
end architecture behaviour;