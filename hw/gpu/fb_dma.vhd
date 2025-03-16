library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.gpu_pkg.all;

entity fb_dma is
  port (
    clk_sys_i : in    std_logic;
    clk_vga_i : in    std_logic;
    rst_i     : in    std_logic;

    -- VRAM interface
    vram_wb_cyc_o   : out   std_logic;
    vram_wb_dat_o   : out   std_logic_vector(15 downto 0);
    vram_wb_dat_i   : in    std_logic_vector(15 downto 0);
    vram_wb_ack_i   : in    std_logic;
    vram_wb_addr_o  : out   std_logic_vector(19 downto 0);
    vram_wb_stall_i : in    std_logic;
    vram_wb_sel_o   : out   std_logic_vector(1 downto 0);
    vram_wb_stb_o   : out   std_logic;
    vram_wb_we_o    : out   std_logic;

    -- Video interface
    vga_blank_ni : in    std_logic;
    new_frame_o  : out   std_logic;
    pixel_o      : out   wide_pixel_t
  );
end entity fb_dma;

architecture rtl of fb_dma is
  constant fifo_depth : natural := 128;

  type feeder_state_t is (idle, feeding);

  -- sys-clock side
  signal vga_fifo_data_in         : std_logic_vector(17 downto 0);
  signal vga_fifo_new_line_in     : std_logic;
  signal vga_fifo_new_frame_in    : std_logic;
  signal vga_fifo_put             : std_logic;
  signal vga_fifo_write_full      : std_logic;
  signal vga_fifo_write_half_full : std_logic;
  signal vga_fifo_write_count     : std_logic_vector(6 downto 0);
  signal vga_fifo_feed_cursor_x   : unsigned(fb_width_log2 - 1 downto 0);
  signal vga_fifo_feed_cursor_y   : unsigned(vga_height_log2 - 1 downto 0);
  signal request_cursor_x         : unsigned(fb_width_log2 - 1 downto 0);
  signal request_cursor_y         : unsigned(fb_height_log2 - 1 downto 0);
  signal request_count            : unsigned(6 downto 0);
  signal feeder_state             : feeder_state_t;

  -- vga-clock side
  signal vga_fifo_take         : std_logic;
  signal vga_fifo_data_out     : std_logic_vector(17 downto 0);
  signal vga_fifo_new_line_out : std_logic;
  signal vga_fifo_read_empty   : std_logic;

begin

  vga_fifo_data_in         <= vga_fifo_new_frame_in & vga_fifo_new_line_in &
                              vram_wb_dat_i;
  vga_fifo_write_half_full <= vga_fifo_write_count(5);

  vga_fifo_take         <= not vga_fifo_read_empty and vga_blank_ni;
  pixel_o.red           <= vga_fifo_data_out(15 downto 11) & "000";
  pixel_o.green         <= vga_fifo_data_out(10 downto 5) & "00";
  pixel_o.blue          <= vga_fifo_data_out(4 downto 0) & "000";
  vga_fifo_new_line_out <= vga_fifo_data_out(16);
  new_frame_o           <= vga_fifo_data_out(17);

  -- Always read, two bytes
  vram_wb_sel_o  <= "11";
  vram_wb_we_o   <= '0';
  vram_wb_addr_o <= "000" & std_logic_vector(request_cursor_x) & STD_LOGIC_VECTOR(request_cursor_y);

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

  wb_driver_p : process (clk_sys_i, rst_i) is
  begin

    if (rst_i = '0') then
      feeder_state <= idle;
      vram_wb_cyc_o <= '0';
      vram_wb_stb_o <= '0';
      request_count <= d"0";
    elsif rising_edge(clk_sys_i) then
      if (vga_fifo_write_half_full = '0' and feeder_state = idle) then
        feeder_state <= feeding;
        vram_wb_cyc_o <= '1';
        vram_wb_stb_o <= '1';
        request_count <= to_unsigned(fifo_depth, 7) - unsigned(vga_fifo_write_count);
      end if;
    end if;

  end process wb_driver_p;

  vga_fifo_pusher_p : process (clk_sys_i, rst_i) is
  begin

    if (rst_i = '0') then
      vga_fifo_put           <= '0';
      vga_fifo_feed_cursor_x <= (others => '0');
      vga_fifo_feed_cursor_y <= (others => '0');
      vga_fifo_new_line_in   <= '1';
      vga_fifo_new_frame_in  <= '1';
    elsif rising_edge(clk_sys_i) then
      vga_fifo_put <= '0';
      -- On ACK, save data and advance the cursor
      if (vram_wb_ack_i = '1') then
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

  end process vga_fifo_pusher_p;

end architecture rtl;
