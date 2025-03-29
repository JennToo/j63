library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.gpu_pkg.all;

entity gpu is
  port (
    clk_sys_i : in    std_logic;
    clk_vga_i : in    std_logic;
    rst_i     : in    std_logic;

    vga_hs_o     : out   std_logic;
    vga_vs_o     : out   std_logic;
    vga_blank_no : out   std_logic;
    vga_sync_no  : out   std_logic;
    vga_r_o      : out   std_logic_vector(7 downto 0);
    vga_g_o      : out   std_logic_vector(7 downto 0);
    vga_b_o      : out   std_logic_vector(7 downto 0);

    sram_addr_o : out   std_logic_vector(19 downto 0);
    sram_data_o : out   std_logic_vector(15 downto 0);
    sram_data_i : in    std_logic_vector(15 downto 0);
    sram_we_o   : out   std_logic
  );
end entity gpu;

architecture rtl of gpu is

  signal vga_hblank    : std_logic;
  signal vga_vblank    : std_logic;
  signal vga_pixel_out : wide_pixel_t;

  -- sys-clock side
  signal vga_fifo_data_in         : std_logic_vector(17 downto 0);
  signal vga_fifo_new_line_in     : std_logic;
  signal vga_fifo_new_frame_in    : std_logic;
  signal vga_fifo_put             : std_logic;
  signal vga_fifo_write_full      : std_logic;
  signal vga_fifo_write_half_full : std_logic;
  signal vga_fifo_write_count     : std_logic_vector(6 downto 0);
  signal vga_fifo_feed_cursor_x   : unsigned(vga_width_log2 - 1 downto 0);
  signal vga_fifo_feed_cursor_y   : unsigned(vga_height_log2 - 1 downto 0);
  signal fb_cursor_x              : std_logic_vector(fb_width_log2 - 1 downto 0);
  signal fb_cursor_y              : std_logic_vector(fb_height_log2 - 1 downto 0);

  -- vga-clock side
  signal vga_fifo_take           : std_logic;
  signal vga_fifo_data_out       : std_logic_vector(17 downto 0);
  signal vga_fifo_wide_pixel_out : wide_pixel_t;
  signal vga_fifo_new_line_out   : std_logic;
  signal vga_fifo_new_frame_out  : std_logic;
  signal vga_fifo_read_empty     : std_logic;

begin

  vga_sync_no  <= '0';
  vga_blank_no <= not (vga_hblank or vga_vblank);
  vga_r_o      <= vga_pixel_out.red;
  vga_g_o      <= vga_pixel_out.green;
  vga_b_o      <= vga_pixel_out.blue;

  vga_fifo_data_in         <= vga_fifo_new_frame_in & vga_fifo_new_line_in &
                              sram_data_i;
  vga_fifo_write_half_full <= vga_fifo_write_count(5);

  vga_fifo_take                 <= not vga_fifo_read_empty and vga_blank_no;
  vga_fifo_wide_pixel_out.red   <= vga_fifo_data_out(15 downto 11) & "000";
  vga_fifo_wide_pixel_out.green <= vga_fifo_data_out(10 downto 5) & "00";
  vga_fifo_wide_pixel_out.blue  <= vga_fifo_data_out(4 downto 0) & "000";
  vga_fifo_new_line_out         <= vga_fifo_data_out(16);
  vga_fifo_new_frame_out        <= vga_fifo_data_out(17);

  sram_we_o   <= '0';
  fb_cursor_x <= std_logic_vector(vga_fifo_feed_cursor_x(vga_width_log2 - 1 downto 1));
  fb_cursor_y <= std_logic_vector(vga_fifo_feed_cursor_y(vga_height_log2 - 1 downto 1));
  sram_addr_o <= "000" & fb_cursor_y & fb_cursor_x;

  u_vga : entity work.vga
    port map (
      clk_i => clk_vga_i,
      rst_i => rst_i,

      sync_frame_start_i => vga_fifo_new_frame_out,

      pixel_i  => vga_fifo_wide_pixel_out,
      pixel_o  => vga_pixel_out,
      hsync_o  => vga_hs_o,
      vsync_o  => vga_vs_o,
      hblank_o => vga_hblank,
      vblank_o => vga_vblank
    );

  u_vga_fifo : entity work.vga_fb_fifo
    port map (
      wrclk   => clk_sys_i,
      data    => vga_fifo_data_in,
      wrreq   => vga_fifo_put,
      wrfull  => vga_fifo_write_full,
      wrusedw => vga_fifo_write_count,

      rdclk   => clk_vga_i,
      rdreq   => vga_fifo_take,
      q       => vga_fifo_data_out,
      rdempty => vga_fifo_read_empty
    );

  vga_fifo_pusher_p : process (clk_sys_i, rst_i) is
  begin

    if rising_edge(clk_sys_i) then
      if (rst_i = '1') then
        vga_fifo_put           <= '0';
        vga_fifo_feed_cursor_x <= (others => '0');
        vga_fifo_feed_cursor_y <= (others => '0');
        vga_fifo_new_line_in   <= '1';
        vga_fifo_new_frame_in  <= '1';
      else
        vga_fifo_put <= '0';
        -- TODO: A better strategy may be hysterisys. Wait until FIFO is at half
        --       capacity, and then burst up to full in low-priority mode once
        --       over half. This allows the FIFO feeder to soak up unused SRAM BW
        if (vga_fifo_write_half_full = '0') then
          vga_fifo_put          <= '1';
          vga_fifo_new_line_in  <= '0';
          vga_fifo_new_frame_in <= '0';
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
    end if;

  end process vga_fifo_pusher_p;

end architecture rtl;
