library ieee;
  use ieee.std_logic_1164.all;
  use work.gpu_pkg.all;

entity gpu is
  port (
    clk_sys : in    std_logic;
    clk_vga : in    std_logic;
    arst    : in    std_logic;

    vga_hs      : out   std_logic;
    vga_vs      : out   std_logic;
    vga_blank_n : out   std_logic;
    vga_sync_n  : out   std_logic;
    vga_r       : out   std_logic_vector(7 downto 0);
    vga_g       : out   std_logic_vector(7 downto 0);
    vga_b       : out   std_logic_vector(7 downto 0)
  );
end entity gpu;

architecture rtl of gpu is

  signal vga_hblank    : std_logic;
  signal vga_vblank    : std_logic;
  signal vga_pixel_in  : wide_pixel_t;
  signal vga_pixel_out : wide_pixel_t;

begin

  vga_sync_n  <= '0';
  vga_blank_n <= not (vga_hblank or vga_vblank);
  vga_r       <= vga_pixel_out.red;
  vga_g       <= vga_pixel_out.green;
  vga_b       <= vga_pixel_out.blue;
  -- Temp hacks
  vga_pixel_in.red   <= (others => '0');
  vga_pixel_in.green <= (others => '1');
  vga_pixel_in.blue  <= (others => '0');

  u_vga : entity work.vga
    port map (
      clk  => clk_vga,
      arst => arst,

      pixel_i => vga_pixel_in,
      pixel_o => vga_pixel_out,
      hsync   => vga_hs,
      vsync   => vga_vs,
      hblank  => vga_hblank,
      vblank  => vga_vblank
    );

end architecture rtl;

