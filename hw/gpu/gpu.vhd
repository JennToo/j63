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
  signal vga_blank_n   : std_logic;

  signal dma_wide_pixel : wide_pixel_t;
  signal dma_new_frame  : std_logic;

  signal fb_dma_wb_cyc    : std_logic;
  signal fb_dma_wb_dat_wr : std_logic_vector(15 downto 0);
  signal fb_dma_wb_dat_rd : std_logic_vector(15 downto 0);
  signal fb_dma_wb_ack    : std_logic;
  signal fb_dma_wb_addr   : std_logic_vector(19 downto 0);
  signal fb_dma_wb_stall  : std_logic;
  signal fb_dma_wb_sel    : std_logic_vector(1 downto 0);
  signal fb_dma_wb_stb    : std_logic;
  signal fb_dma_wb_we     : std_logic;

begin

  vga_sync_no  <= '0';
  vga_blank_n  <= not (vga_hblank or vga_vblank);
  vga_r_o      <= vga_pixel_out.red;
  vga_g_o      <= vga_pixel_out.green;
  vga_b_o      <= vga_pixel_out.blue;
  vga_blank_no <= vga_blank_n;

  u_vga : entity work.vga
    port map (
      clk_i => clk_vga_i,
      rst_i => rst_i,

      sync_frame_start_i => dma_new_frame,
      pixel_i            => dma_wide_pixel,
      pixel_o            => vga_pixel_out,
      hsync_o            => vga_hs_o,
      vsync_o            => vga_vs_o,
      hblank_o           => vga_hblank,
      vblank_o           => vga_vblank
    );

  u_fb_dma : entity work.fb_dma
    port map (
      clk_sys_i => clk_sys_i,
      clk_vga_i => clk_vga_i,
      rst_i     => rst_i,

      sram_addr_o => sram_addr_o,
      sram_data_o => sram_data_o,
      sram_data_i => sram_data_i,
      sram_we_o   => sram_we_o,

      vga_blank_ni => vga_blank_n,
      new_frame_o  => dma_new_frame,
      pixel_o      => dma_wide_pixel
    );

  u_wb_vram : entity work.wb_sram
    generic map (
      addr_width => 20,
      data_width => 16
    )
    port map (
      clk_i => clk_sys_i,
      rst_i => rst_i,

      wb_cyc_i   => fb_dma_wb_cyc,
      wb_dat_i   => fb_dma_wb_dat_wr,
      wb_dat_o   => fb_dma_wb_dat_rd,
      wb_ack_o   => fb_dma_wb_ack,
      wb_addr_i  => fb_dma_wb_addr,
      wb_stall_o => fb_dma_wb_stall,
      wb_sel_i   => fb_dma_wb_sel,
      wb_stb_i   => fb_dma_wb_stb,
      wb_we_i    => fb_dma_wb_we,

      sram_addr_o => sram_addr_o,
      sram_dat_o  => sram_data_o,
      sram_dat_i  => sram_data_i,
      sram_sel_o  => open,
      sram_we_o   => sram_we_o
    );

end architecture rtl;
