library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.test_pkg.all;

entity sim_vga is
  port (
    clk  : in    std_logic;
    arst : in    std_logic;

    vga_hs : in    std_logic;
    vga_vs : in    std_logic;
    vga_r  : in    std_logic_vector(7 downto 0);
    vga_g  : in    std_logic_vector(7 downto 0);
    vga_b  : in    std_logic_vector(7 downto 0)
  );
end entity sim_vga;

architecture behave of sim_vga is

  -- Timing data from http://tinyvga.com/vga-timing/640x480@60Hz
  constant vga_hs_pulse  : time := 3.8133068520357 us;
  constant vga_vs_pulse  : time := 0.063555114200596 ms;
  constant vga_line_len  : time := 31.777557100298 us;
  constant vga_frame_len : time := 16.683217477656 ms;
  constant epsilon       : time := 1 ns;

  signal vga_hs_d      : std_logic;
  signal vga_vs_d      : std_logic;
  signal vga_hs_start  : time;
  signal vga_vs_start  : time;
  signal seen_first_hs : std_logic;
  signal seen_first_vs : std_logic;

begin

  sync_verification : process (clk, arst) is

    variable time_difference : time;

  begin

    if (arst = '0') then
      vga_hs_d      <= '1';
      vga_vs_d      <= '1';
      seen_first_hs <= '0';
      seen_first_vs <= '0';
    elsif rising_edge(clk) then
      if (vga_hs = '0' and vga_hs_d = '1') then
        if (seen_first_hs = '0') then
          seen_first_hs <= '1';
        else
          time_difference := now - vga_hs_start;
          assert time_equal_ish(time_difference, vga_line_len, epsilon)
            report "Invalid HSYNC period " & time'image(time_difference)
            severity error;
        end if;
        vga_hs_start <= now;
      end if;
      if (vga_hs = '1' and vga_hs_d = '0') then
        time_difference := now - vga_hs_start;
        assert time_equal_ish(time_difference, vga_hs_pulse, epsilon)
          report "Invalid HSYNC pulse length " & time'image(time_difference)
          severity error;
      end if;
      if (vga_vs = '0' and vga_vs_d = '1') then
        if (seen_first_vs = '0') then
          seen_first_vs <= '1';
        else
          time_difference := now - vga_vs_start;
          assert time_equal_ish(time_difference, vga_frame_len, epsilon)
            report "Invalid VSYNC period " & time'image(time_difference)
            severity error;
        end if;
        vga_vs_start <= now;
      end if;
      if (vga_vs = '1' and vga_vs_d = '0') then
        time_difference := now - vga_vs_start;
        assert time_equal_ish(time_difference, vga_vs_pulse, epsilon)
          report "Invalid VSYNC pulse length " & time'image(time_difference)
          severity error;
      end if;
      vga_hs_d <= vga_hs;
      vga_vs_d <= vga_vs;
    end if;

  end process sync_verification;

end architecture behave;
