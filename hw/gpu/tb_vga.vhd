library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use work.gpu_pkg.all;

entity tb_vga is
end entity tb_vga;

architecture behave of tb_vga is

  -- 25.175 MHz
  constant clk_period : time := 39.72194638 ns;
  constant epsilon    : time := 1 ns;

  -- Timing data from http://tinyvga.com/vga-timing/640x480@60Hz
  constant hsync_pulse : time := 3.8133068520357 us;
  constant vsync_pulse : time := 0.063555114200596 ms;

  signal clk  : std_logic := '0';
  signal arst : std_logic;

  signal pixel_i : wide_pixel_t;
  signal pixel_o : wide_pixel_t;

  signal hsync  : std_logic;
  signal vsync  : std_logic;
  signal hblank : std_logic;
  signal vblank : std_logic;

  signal last_hsync  : std_logic;
  signal last_vsync  : std_logic;
  signal hsync_start : time;
  signal vsync_start : time;

begin

  clk <= not clk after clk_period / 2;

  vga_0 : entity work.vga
    port map (
      clk     => clk,
      arst    => arst,
      pixel_i => pixel_i,
      pixel_o => pixel_o,
      hsync   => hsync,
      vsync   => vsync,
      hblank  => hblank,
      vblank  => vblank
    );

  sync_verification : process (clk, arst) is

    variable time_difference : time;

  begin

    if (arst = '0') then
      last_hsync <= '1';
      last_vsync <= '1';
    elsif rising_edge(clk) then
      if (hsync = '0' and last_hsync = '1') then
        hsync_start <= now;
      end if;
      if (hsync = '1' and last_hsync = '0') then
        time_difference := now - hsync_start;
        assert time_difference - hsync_pulse < epsilon
          report "Invalid HSYNC pulse length " & time'image(time_difference)
          severity error;
      end if;
      if (vsync = '0' and last_vsync = '1') then
        hsync_start <= now;
      end if;
      if (vsync = '1' and last_vsync = '0') then
        time_difference := now - vsync_start;
        assert time_difference - vsync_pulse < epsilon
          report "Invalid VSYNC pulse length " & time'image(time_difference)
          severity error;
      end if;
      last_hsync <= hsync;
      last_vsync <= vsync;
    end if;

  end process sync_verification;

  stimulus : process is
  begin

    arst <= '0';
    wait for 1 ns;
    arst <= '1';

    -- A bit over 2 frames
    wait for 35 ms;

    finish;

  end process stimulus;

end architecture behave;
