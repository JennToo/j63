library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.math_pkg.all;

package gpu_pkg is

  constant vga_width       : natural := 640;
  constant vga_height      : natural := 480;
  constant vga_width_log2  : natural := clog2(vga_width);
  constant vga_height_log2 : natural := clog2(vga_height);
  constant fb_width        : natural := 320;
  constant fb_height       : natural := 240;
  constant fb_width_log2   : natural := clog2(fb_width);
  constant fb_height_log2  : natural := clog2(fb_height);
  constant fb_frame        : natural := fb_width * fb_height;

  constant fb_frame_addr_0 : unsigned(19 downto 0) := 20x"0";
  constant fb_frame_addr_1 : unsigned(19 downto 0) := fb_frame_addr_0 + fb_frame;
  constant fb_zbuf_addr    : unsigned(19 downto 0) := fb_frame_addr_1 + fb_frame;

  type pixel_t is record
    red   : std_logic_vector(4 downto 0);
    green : std_logic_vector(5 downto 0);
    blue  : std_logic_vector(4 downto 0);
  end record pixel_t;

  type wide_pixel_t is record
    red   : std_logic_vector(7 downto 0);
    green : std_logic_vector(7 downto 0);
    blue  : std_logic_vector(7 downto 0);
  end record wide_pixel_t;

  constant c_fault_wide_pixel : wide_pixel_t :=
  (
    red   => (others => '1'),
    green => (others => '0'),
    blue  => (others => '1')
  );

  type cursor_direction_t is (inc_x, dec_x, inc_y);

end package gpu_pkg;
