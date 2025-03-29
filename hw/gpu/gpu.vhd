library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.gpu_pkg.all;

entity gpu is
  port (
    clk_sys_i : in    std_logic;
    rst_sys_i : in    std_logic;
    clk_vga_i : in    std_logic;
    rst_vga_i : in    std_logic;

    vga_hs_o     : out   std_logic;
    vga_vs_o     : out   std_logic;
    vga_blank_no : out   std_logic;
    vga_sync_no  : out   std_logic;
    vga_r_o      : out   std_logic_vector(7 downto 0);
    vga_g_o      : out   std_logic_vector(7 downto 0);
    vga_b_o      : out   std_logic_vector(7 downto 0);

    vram_wb_cyc_o   : out   std_logic;
    vram_wb_dat_i   : in    std_logic_vector(15 downto 0);
    vram_wb_dat_o   : out   std_logic_vector(15 downto 0);
    vram_wb_ack_i   : in    std_logic;
    vram_wb_addr_o  : out   std_logic_vector(19 downto 0);
    vram_wb_stall_i : in    std_logic;
    vram_wb_sel_o   : out   std_logic_vector(1 downto 0);
    vram_wb_stb_o   : out   std_logic;
    vram_wb_we_o    : out   std_logic
  );
end entity gpu;

architecture rtl of gpu is

  -- sys-clock side
  signal active_frame       : std_logic;
  signal fb_front_addr_base : unsigned(19 downto 0);
  signal fb_back_addr_base  : unsigned(19 downto 0);

  signal fifo_data_in         : std_logic_vector(17 downto 0);
  signal fifo_new_line_in     : std_logic;
  signal fifo_new_frame_in    : std_logic;
  signal fifo_put             : std_logic;
  signal fifo_write_full      : std_logic;
  signal fifo_write_half_full : std_logic;
  signal fifo_write_count     : std_logic_vector(7 downto 0);
  signal fb_cursor_y          : unsigned(fb_height_log2 - 1 downto 0);
  signal sys_pixel_doubler    : std_logic;

  signal fifo_dma_wb_cyc    : std_logic;
  signal fifo_dma_wb_dat_rd : std_logic_vector(15 downto 0);
  signal fifo_dma_wb_dat_wr : std_logic_vector(15 downto 0);
  signal fifo_dma_wb_ack    : std_logic;
  signal fifo_dma_wb_addr   : std_logic_vector(19 downto 0);
  signal fifo_dma_wb_stall  : std_logic;
  signal fifo_dma_wb_sel    : std_logic_vector(1 downto 0);
  signal fifo_dma_wb_stb    : std_logic;
  signal fifo_dma_wb_we     : std_logic;

  signal fifo_dma_addr     : unsigned(19 downto 0);
  signal fifo_dma_word_cnt : std_logic_vector(19 downto 0);
  signal fifo_dma_start    : std_logic;
  signal fifo_dma_done     : std_logic;

  -- vga-clock side
  signal vga_hblank           : std_logic;
  signal vga_vblank           : std_logic;
  signal vga_pixel_out        : wide_pixel_t;
  signal vga_start_of_frame   : std_logic;
  signal vga_start_of_frame_d : std_logic;
  signal vga_pixel_doubler    : std_logic;

  signal fifo_take           : std_logic;
  signal fifo_data_out       : std_logic_vector(17 downto 0);
  signal fifo_wide_pixel_out : wide_pixel_t;
  signal fifo_new_line_out   : std_logic;
  signal fifo_new_frame_out  : std_logic;
  signal fifo_read_empty     : std_logic;

begin

  active_frame       <= '0';
  fb_front_addr_base <= fb_frame_addr_0 when active_frame = '0' else
                        fb_frame_addr_1;
  fb_back_addr_base  <= fb_frame_addr_1 when active_frame = '0' else
                        fb_frame_addr_0;

  u_vram_arbiter : entity work.wb_arbiter
    generic map (
      addr_width => 20,
      data_width => 16
    )
    port map (
      clk_i => clk_sys_i,
      rst_i => rst_sys_i,

      a_wb_cyc_i   => fifo_dma_wb_cyc,
      a_wb_dat_i   => fifo_dma_wb_dat_wr,
      a_wb_dat_o   => fifo_dma_wb_dat_rd,
      a_wb_ack_o   => fifo_dma_wb_ack,
      a_wb_addr_i  => fifo_dma_wb_addr,
      a_wb_stall_o => fifo_dma_wb_stall,
      a_wb_sel_i   => fifo_dma_wb_sel,
      a_wb_stb_i   => fifo_dma_wb_stb,
      a_wb_we_i    => fifo_dma_wb_we,

      b_wb_cyc_i   => '0',
      b_wb_dat_i   => (others => '0'),
      b_wb_dat_o   => open,
      b_wb_ack_o   => open,
      b_wb_addr_i  => (others => '0'),
      b_wb_stall_o => open,
      b_wb_sel_i   => (others => '0'),
      b_wb_stb_i   => '0',
      b_wb_we_i    => '0',

      target_wb_cyc_o   => vram_wb_cyc_o,
      target_wb_dat_i   => vram_wb_dat_i,
      target_wb_dat_o   => vram_wb_dat_o,
      target_wb_ack_i   => vram_wb_ack_i,
      target_wb_addr_o  => vram_wb_addr_o,
      target_wb_stall_i => vram_wb_stall_i,
      target_wb_sel_o   => vram_wb_sel_o,
      target_wb_stb_o   => vram_wb_stb_o,
      target_wb_we_o    => vram_wb_we_o
    );

  u_vga_fifo : entity work.vga_fb_fifo
    port map (
      wrclk   => clk_sys_i,
      data    => fifo_data_in,
      wrreq   => fifo_put,
      wrfull  => fifo_write_full,
      wrusedw => fifo_write_count,

      rdclk   => clk_vga_i,
      rdreq   => fifo_take,
      q       => fifo_data_out,
      rdempty => fifo_read_empty
    );

  --------------------------------------
  -- Push pixel data from VRAM into FIFO
  --------------------------------------
  u_fifo_dma : entity work.wb_dma_to_fifo
    generic map (
      addr_width     => 20,
      data_width     => 16,
      fifo_cnt_width => 8,
      fifo_cnt_max   => 128
    )
    port map (
      clk_i => clk_sys_i,
      rst_i => rst_sys_i,

      dma_addr_i     => std_logic_vector(fifo_dma_addr),
      dma_word_cnt_i => fifo_dma_word_cnt,
      dma_start_i    => fifo_dma_start,
      dma_done_o     => fifo_dma_done,

      wb_cyc_o   => fifo_dma_wb_cyc,
      wb_dat_i   => fifo_dma_wb_dat_rd,
      wb_dat_o   => fifo_dma_wb_dat_wr,
      wb_ack_i   => fifo_dma_wb_ack,
      wb_addr_o  => fifo_dma_wb_addr,
      wb_stall_i => fifo_dma_wb_stall,
      wb_sel_o   => fifo_dma_wb_sel,
      wb_stb_o   => fifo_dma_wb_stb,
      wb_we_o    => fifo_dma_wb_we,

      fifo_cnt_i  => fifo_write_count,
      fifo_data_o => fifo_data_in(15 downto 0),
      fifo_put_o  => fifo_put
    );

  fifo_data_in(17 downto 16) <= fifo_new_frame_in & fifo_new_line_in;
  fifo_write_half_full       <= fifo_write_count(5);
  fifo_dma_word_cnt          <= std_logic_vector(to_unsigned(fb_width, 20));

  fifo_pusher_p : process (clk_sys_i, rst_sys_i) is
  begin

    if rising_edge(clk_sys_i) then
      if (rst_sys_i = '1') then
        fifo_new_line_in  <= '0';
        fifo_new_frame_in <= '0';
        fifo_dma_addr     <= (others => '0');
        fifo_dma_start    <= '0';
        fb_cursor_y       <= (others => '0');
        sys_pixel_doubler <= '0';
      else
        fifo_dma_start <= '0';

        -- Once we write the first pixel of a line, clear these
        if (fifo_put = '1') then
          fifo_new_line_in  <= '0';
          fifo_new_frame_in <= '0';
        end if;

        -- Start a new line of pixels whenever the DMA finishes
        if (fifo_dma_done = '1' and fifo_write_half_full = '0') then
          if (sys_pixel_doubler = '0') then
            if (fb_cursor_y = 0) then
              fifo_new_frame_in <= '1';
              fifo_dma_addr     <= fb_front_addr_base;
            else
              fifo_dma_addr <= fifo_dma_addr + fb_width;
            end if;

            if (fb_cursor_y < fb_height - 1) then
              fb_cursor_y <= fb_cursor_y + 1;
            else
              fb_cursor_y <= (others => '0');
            end if;
          end if;
          fifo_new_line_in  <= '1';
          fifo_dma_start    <= '1';
          sys_pixel_doubler <= not sys_pixel_doubler;
        end if;
      end if;
    end if;

  end process fifo_pusher_p;

  -------------------------------------------
  -- Pull pixel data from FIFO and display it
  -------------------------------------------
  fifo_take                 <= '1' when fifo_read_empty = '0' and
                                        vga_start_of_frame_d = fifo_new_frame_out and
                                        vga_pixel_doubler = '1' and
                                        vga_blank_no = '1' else
                               '0';
  fifo_wide_pixel_out.red   <= fifo_data_out(15 downto 11) & "000";
  fifo_wide_pixel_out.green <= fifo_data_out(10 downto 5) & "00";
  fifo_wide_pixel_out.blue  <= fifo_data_out(4 downto 0) & "000";
  fifo_new_line_out         <= fifo_data_out(16);
  fifo_new_frame_out        <= fifo_data_out(17);

  vga_sync_no  <= '0';
  vga_blank_no <= not (vga_hblank or vga_vblank);
  vga_r_o      <= vga_pixel_out.red;
  vga_g_o      <= vga_pixel_out.green;
  vga_b_o      <= vga_pixel_out.blue;

  vga_doubler_p : process (clk_vga_i) is
  begin

    if rising_edge(clk_vga_i) then
      if (rst_vga_i = '1') then
        vga_pixel_doubler    <= '0';
        vga_start_of_frame_d <= '0';
      else
        vga_pixel_doubler    <= not vga_pixel_doubler;
        vga_start_of_frame_d <= vga_start_of_frame;
        if (vga_start_of_frame = '1') then
          vga_pixel_doubler <= '1';
        end if;
      end if;
    end if;

  end process vga_doubler_p;

  u_vga : entity work.vga
    port map (
      clk_i => clk_vga_i,
      rst_i => rst_vga_i,

      start_of_frame_o => vga_start_of_frame,

      pixel_i  => fifo_wide_pixel_out,
      pixel_o  => vga_pixel_out,
      hsync_o  => vga_hs_o,
      vsync_o  => vga_vs_o,
      hblank_o => vga_hblank,
      vblank_o => vga_vblank
    );

end architecture rtl;
