library ieee;
  use ieee.std_logic_1164.all;

entity j63_toplevel is
  port (
    clock_50_i  : in    std_logic;
    clock2_50_i : in    std_logic;
    clock3_50_i : in    std_logic;
    sma_clk_i   : in    std_logic;
    sma_clk_o   : out   std_logic;

    key_i  : in    std_logic_vector(3 downto 0);
    sw_i   : in    std_logic_vector(17 downto 0);
    ledg_o : out   std_logic_vector(8  downto 0);
    ledr_o : out   std_logic_vector(17 downto 0);
    hex0_o : out   std_logic_vector(6 downto 0);
    hex1_o : out   std_logic_vector(6 downto 0);
    hex2_o : out   std_logic_vector(6 downto 0);
    hex3_o : out   std_logic_vector(6 downto 0);
    hex4_o : out   std_logic_vector(6 downto 0);
    hex5_o : out   std_logic_vector(6 downto 0);
    hex6_o : out   std_logic_vector(6 downto 0);
    hex7_o : out   std_logic_vector(6 downto 0);

    ex_io : inout std_logic_vector(6 downto 0);

    lcd_blon_o  : out   std_logic;
    lcd_data_io : inout std_logic_vector(7 downto 0);
    lcd_en_o    : out   std_logic;
    lcd_on_o    : out   std_logic;
    lcd_rs_o    : out   std_logic;
    lcd_rw_o    : out   std_logic;

    uart_cts_i : in    std_logic;
    uart_rts_o : out   std_logic;
    uart_rxd_i : in    std_logic;
    uart_txd_o : out   std_logic;

    ps2_clk_io  : inout std_logic;
    ps2_clk2_io : inout std_logic;
    ps2_dat_io  : inout std_logic;
    ps2_dat2_io : inout std_logic;

    sd_clk_o  : out   std_logic;
    sd_cmd_io : inout std_logic;
    sd_dat_io : inout std_logic_vector(3 downto 0);
    sd_wp_ni  : in    std_logic;

    vga_clk_o    : out   std_logic;
    vga_hs_o     : out   std_logic;
    vga_vs_o     : out   std_logic;
    vga_blank_no : out   std_logic;
    vga_sync_no  : out   std_logic;
    vga_r_o      : out   std_logic_vector(7 downto 0);
    vga_g_o      : out   std_logic_vector(7 downto 0);
    vga_b_o      : out   std_logic_vector(7 downto 0);

    aud_adcdat_i   : in    std_logic;
    aud_adclrck_io : inout std_logic;
    aud_bclk_io    : inout std_logic;
    aud_dacdat_o   : out   std_logic;
    aud_daclrck_io : inout std_logic;
    aud_xck_o      : out   std_logic;

    eep_i2c_sclk_o  : out   std_logic;
    eep_i2c_sdat_io : inout std_logic;

    i2c_sclk_o  : out   std_logic;
    i2c_sdat_io : inout std_logic;

    enet0_gtx_clk_o  : out   std_logic;
    enet0_int_ni     : in    std_logic;
    enet0_link100i_i : in    std_logic;
    enet0_mdc_o      : out   std_logic;
    enet0_mdio_io    : inout std_logic;
    enet0_rst_no     : out   std_logic;
    enet0_rx_clk_i   : in    std_logic;
    enet0_rx_col_i   : in    std_logic;
    enet0_rx_crs_i   : in    std_logic;
    enet0_rx_data_i  : in    std_logic_vector(3 downto 0);
    enet0_rx_dv_i    : in    std_logic;
    enet0_rx_er_i    : in    std_logic;
    enet0_tx_clk_i   : in    std_logic;
    enet0_tx_data_o  : out   std_logic_vector(3 downto 0);
    enet0_tx_en_o    : out   std_logic;
    enet0_tx_er_o    : out   std_logic;
    enetclk_25_i     : in    std_logic;

    enet1_gtx_clk_o : out   std_logic;
    enet1_int_ni    : in    std_logic;
    enet1_link100_i : in    std_logic;
    enet1_mdc_o     : out   std_logic;
    enet1_mdio_io   : inout std_logic;
    enet1_rst_no    : out   std_logic;
    enet1_rx_clk_i  : in    std_logic;
    enet1_rx_col_i  : in    std_logic;
    enet1_rx_crs_i  : in    std_logic;
    enet1_rx_data_i : in    std_logic_vector(3 downto 0);
    enet1_rx_dv_i   : in    std_logic;
    enet1_rx_er_i   : in    std_logic;
    enet1_tx_clk_i  : in    std_logic;
    enet1_tx_data_o : out   std_logic_vector(3 downto 0);
    enet1_tx_en_o   : out   std_logic;
    enet1_tx_er_o   : out   std_logic;

    td_clk27_i  : in    std_logic;
    td_data_i   : in    std_logic_vector(7 downto 0);
    td_hs_i     : in    std_logic;
    td_reset_no : out   std_logic;
    td_vs_i     : in    std_logic;

    otg_addr_o  : out   std_logic_vector(1 downto 0);
    otg_cs_no   : out   std_logic;
    otg_data_io : inout std_logic_vector(15 downto 0);
    otg_int_i   : in    std_logic;
    otg_rd_no   : out   std_logic;
    otg_rst_no  : out   std_logic;
    otg_we_no   : out   std_logic;

    irda_rxd_i : in    std_logic;

    dram_addr_o : out   std_logic_vector(12 downto 0);
    dram_ba_o   : out   std_logic_vector(1 downto 0);
    dram_cas_no : out   std_logic;
    dram_cke_o  : out   std_logic;
    dram_clk_o  : out   std_logic;
    dram_cs_no  : out   std_logic;
    dram_dq_io  : inout std_logic_vector(31 downto 0);
    dram_dqm_io : out   std_logic_vector(3 downto 0);
    dram_ras_no : out   std_logic;
    dram_we_no  : out   std_logic;

    sram_addr_o : out   std_logic_vector(19 downto 0);
    sram_ce_no  : out   std_logic;
    sram_dq_io  : inout std_logic_vector(15 downto 0);
    sram_lb_no  : out   std_logic;
    sram_oe_no  : out   std_logic;
    sram_ub_no  : out   std_logic;
    sram_we_no  : out   std_logic;

    fl_addr_o : out   std_logic_vector(22 downto 0);
    fl_ce_no  : out   std_logic;
    fl_dq_io  : inout std_logic_vector(7 downto 0);
    fl_oe_no  : out   std_logic;
    fl_rst_no : out   std_logic;
    fl_ry_i   : in    std_logic;
    fl_we_no  : out   std_logic;
    fl_wp_no  : out   std_logic
  );
end entity j63_toplevel;

architecture rtl of j63_toplevel is

  signal clk_sys  : std_logic;
  signal rst_sys  : std_logic;
  signal clk_vga  : std_logic;
  signal rst_vga  : std_logic;
  signal vga_hs_s : std_logic;
  signal vga_vs_s : std_logic;

  signal uart_rxd_sync : std_logic;

  signal sram_we      : std_logic;
  signal sram_data_wr : std_logic_vector(15 downto 0);
  signal sram_data_rd : std_logic_vector(15 downto 0);

  signal vram_wb_cyc    : std_logic;
  signal vram_wb_dat    : std_logic_vector(15 downto 0);
  signal vram_wb_dat_rd : std_logic_vector(15 downto 0);
  signal vram_wb_dat_wr : std_logic_vector(15 downto 0);
  signal vram_wb_ack    : std_logic;
  signal vram_wb_addr   : std_logic_vector(19 downto 0);
  signal vram_wb_stall  : std_logic;
  signal vram_wb_sel    : std_logic_vector(1 downto 0);
  signal vram_wb_stb    : std_logic;
  signal vram_wb_we     : std_logic;

begin

  -- The system clock (100 MHz) is too dissimilar to the VGA clock (25.175 MHz)
  -- to use the same PLL. The SRAM on the DE2 board is rated for 100 MHz operation
  u_sys_pll : entity work.sys_pll
    port map (
      inclk0 => clock_50_i,
      c0     => clk_sys,
      locked => open
    );

  u_vga_pll : entity work.vga_pll
    port map (
      inclk0 => clock_50_i,
      c0     => clk_vga,
      locked => open
    );

  vga_clk_o <= clk_vga;
  vga_hs_o  <= vga_hs_s when sw_i(17) else
               '1';
  vga_vs_o  <= vga_vs_s when sw_i(17) else
               '1';

  u_gpu : entity work.gpu
    port map (
      clk_sys_i => clk_sys,
      rst_sys_i => rst_sys,
      clk_vga_i => clk_vga,
      rst_vga_i => rst_vga,

      vga_hs_o     => vga_hs_s,
      vga_vs_o     => vga_vs_s,
      vga_blank_no => vga_blank_no,
      vga_sync_no  => vga_sync_no,
      vga_r_o      => vga_r_o,
      vga_g_o      => vga_g_o,
      vga_b_o      => vga_b_o,

      vram_wb_cyc_o   => vram_wb_cyc,
      vram_wb_dat_i   => vram_wb_dat_rd,
      vram_wb_dat_o   => vram_wb_dat_wr,
      vram_wb_ack_i   => vram_wb_ack,
      vram_wb_addr_o  => vram_wb_addr,
      vram_wb_stall_i => vram_wb_stall,
      vram_wb_sel_o   => vram_wb_sel,
      vram_wb_stb_o   => vram_wb_stb,
      vram_wb_we_o    => vram_wb_we
    );

  u_wb_vram : entity work.wb_sram
    generic map (
      addr_width => 20,
      data_width => 16
    )
    port map (
      clk_i => clk_sys,
      rst_i => rst_sys,

      wb_cyc_i   => vram_wb_cyc,
      wb_dat_i   => vram_wb_dat_wr,
      wb_dat_o   => vram_wb_dat_rd,
      wb_ack_o   => vram_wb_ack,
      wb_addr_i  => vram_wb_addr,
      wb_stall_o => vram_wb_stall,
      wb_sel_i   => vram_wb_sel,
      wb_stb_i   => vram_wb_stb,
      wb_we_i    => vram_wb_we,

      sram_addr_o => sram_addr_o,
      sram_dat_o  => sram_data_wr,
      sram_dat_i  => sram_data_rd,
      sram_sel_o  => open,
      sram_we_o   => sram_we
    );

  sram_data_rd <= sram_dq_io;
  sram_dq_io   <= sram_data_wr when sram_we = '1' else
                  (others => 'Z');
  sram_ce_no   <= '0';
  sram_lb_no   <= '0';
  sram_ub_no   <= '0';
  sram_we_no   <= not sram_we;
  sram_oe_no   <= '0';

  u_reset_gen : entity work.reset_gen
    port map (
      async_rst_ni => key_i(0),
      clk_vga_i    => clk_vga,
      clk_sys_i    => clk_sys,
      rst_vga_o    => rst_vga,
      rst_sys_o    => rst_sys
    );

  -- Temp hacks to test UART on hardware
  u_uart_rx : entity work.uart_rx
    generic map (
      clk_period  => 10 ns,
      baud_period => 4340 ns
    )
    port map (
      clk_i => clk_sys,
      rst_i => rst_sys,

      uart_i       => uart_rxd_sync,
      data_o       => ledg_o(7 downto 0),
      data_valid_o => open
    );

  u_sync_rxd : entity work.sync_bit
    port map (
      clk_dest_i => clk_sys,
      bit_i      => uart_rxd_i,
      bit_o      => uart_rxd_sync
    );

  uart_rts_o <= '1';

  ledg_o(8) <= key_i(0);
  hex0_o    <= (others => '1');
  hex1_o    <= (others => '1');
  hex2_o    <= (others => '1');
  hex3_o    <= (others => '1');
  hex4_o    <= (others => '1');
  hex5_o    <= (others => '1');
  hex6_o    <= (others => '1');
  hex7_o    <= (others => '1');

end architecture rtl;
