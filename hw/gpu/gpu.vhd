library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
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
  signal vga_pixel_out : wide_pixel_t;

  -- sys-clock side
  signal vga_fifo_data_in         : std_logic_vector(17 downto 0);
  signal vga_fifo_pixel_in        : pixel_t;
  signal vga_fifo_new_line_in     : std_logic;
  signal vga_fifo_new_frame_in    : std_logic;
  signal vga_fifo_put             : std_logic;
  signal vga_fifo_write_full      : std_logic;
  signal vga_fifo_write_half_full : std_logic;
  signal vga_fifo_write_count     : std_logic_vector(6 downto 0);
  signal vga_fifo_feed_cursor_x   : unsigned(vga_width_log2 - 1 downto 0);
  signal vga_fifo_feed_cursor_y   : unsigned(vga_height_log2 - 1 downto 0);

  -- vga-clock side
  signal vga_fifo_take           : std_logic;
  signal vga_fifo_data_out       : std_logic_vector(17 downto 0);
  signal vga_fifo_wide_pixel_out : wide_pixel_t;
  signal vga_fifo_new_line_out   : std_logic;
  signal vga_fifo_new_frame_out  : std_logic;
  signal vga_fifo_read_empty     : std_logic;

begin

  vga_sync_n  <= '0';
  vga_blank_n <= not (vga_hblank or vga_vblank);
  vga_r       <= vga_pixel_out.red;
  vga_g       <= vga_pixel_out.green;
  vga_b       <= vga_pixel_out.blue;

  vga_fifo_data_in         <= vga_fifo_new_frame_in & vga_fifo_new_line_in &
                              vga_fifo_pixel_in.red & vga_fifo_pixel_in.green & vga_fifo_pixel_in.blue;
  vga_fifo_write_half_full <= vga_fifo_write_count(5);

  vga_fifo_take                 <= not vga_fifo_read_empty and vga_blank_n;
  vga_fifo_wide_pixel_out.red   <= vga_fifo_data_out(15 downto 11) & "000";
  vga_fifo_wide_pixel_out.green <= vga_fifo_data_out(10 downto 5) & "00";
  vga_fifo_wide_pixel_out.blue  <= vga_fifo_data_out(4 downto 0) & "000";
  vga_fifo_new_line_out         <= vga_fifo_data_out(16);
  vga_fifo_new_frame_out        <= vga_fifo_data_out(17);

  u_vga : entity work.vga
    port map (
      clk  => clk_vga,
      arst => arst,

      sync_frame_start => vga_fifo_new_frame_out,

      pixel_i => vga_fifo_wide_pixel_out,
      pixel_o => vga_pixel_out,
      hsync   => vga_hs,
      vsync   => vga_vs,
      hblank  => vga_hblank,
      vblank  => vga_vblank
    );

  u_vga_fifo : entity work.vga_fb_fifo
    port map (
      wrclk   => clk_sys,
      data    => vga_fifo_data_in,
      wrreq   => vga_fifo_put,
      wrfull  => vga_fifo_write_full,
      wrusedw => vga_fifo_write_count,

      rdclk   => clk_vga,
      rdreq   => vga_fifo_take,
      q       => vga_fifo_data_out,
      rdempty => vga_fifo_read_empty
    );

  vga_fifo_pusher_p : process (clk_sys, arst) is
  begin

    if (arst = '0') then
      vga_fifo_pixel_in.red   <= (others => '0');
      vga_fifo_pixel_in.green <= (others => '0');
      vga_fifo_pixel_in.blue  <= (others => '0');
      vga_fifo_put            <= '0';
      vga_fifo_feed_cursor_x  <= (others => '0');
      vga_fifo_feed_cursor_y  <= (others => '0');
      vga_fifo_new_line_in    <= '1';
      vga_fifo_new_frame_in   <= '1';
    elsif rising_edge(clk_sys) then
      vga_fifo_put <= '0';
      -- TODO: A better strategy may be hysterisys. Wait until FIFO is at half
      --       capacity, and then burst up to full in low-priority mode once
      --       over half. This allows the FIFO feeder to soak up unused SRAM BW
      if (vga_fifo_write_half_full = '0') then
        vga_fifo_pixel_in.red   <= std_logic_vector(vga_fifo_feed_cursor_x(4 downto 0));
        vga_fifo_pixel_in.green <= (others => '1');
        vga_fifo_pixel_in.blue  <= std_logic_vector(vga_fifo_feed_cursor_y(4 downto 0));
        vga_fifo_put            <= '1';
        vga_fifo_new_line_in    <= '0';
        vga_fifo_new_frame_in   <= '0';
        if (vga_fifo_feed_cursor_x < vga_width - 1) then
          vga_fifo_feed_cursor_x <= vga_fifo_feed_cursor_x + 1;
        else
          vga_fifo_feed_cursor_x <= (others => '0');
          vga_fifo_new_line_in   <= '1';

          if (vga_fifo_feed_cursor_y < vga_height - 1) then
            vga_fifo_feed_cursor_y <= vga_fifo_feed_cursor_y + 1;
          else
            vga_fifo_feed_cursor_y <= (others => '0');
            vga_fifo_new_frame_in  <= '1';
          end if;
        end if;
      end if;
    end if;

  end process vga_fifo_pusher_p;

end architecture rtl;
