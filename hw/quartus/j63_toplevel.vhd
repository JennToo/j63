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
  signal clk_vga  : std_logic;
  signal rst_i    : std_logic;
  signal vga_hs_s : std_logic;
  signal vga_vs_s : std_logic;

  signal sram_we_i      : std_logic;
  signal sram_data_wr_i : std_logic_vector(15 downto 0);
  signal sram_data_rd_i : std_logic_vector(15 downto 0);

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
      clk_vga_i => clk_vga,
      rst_i     => rst_i,

      vga_hs_o     => vga_hs_s,
      vga_vs_o     => vga_vs_s,
      vga_blank_no => vga_blank_no,
      vga_sync_no  => vga_sync_no,
      vga_r_o      => vga_r_o,
      vga_g_o      => vga_g_o,
      vga_b_o      => vga_b_o,

      sram_addr_o => sram_addr_o,
      sram_data_o => sram_data_wr_i,
      sram_data_i => sram_data_rd_i,
      sram_we_o   => sram_we_i
    );

  sram_data_rd_i <= sram_dq_io;
  sram_dq_io     <= sram_data_wr_i when sram_we_i = '1' else
                    (others => 'Z');
  sram_ce_no     <= '0';
  sram_lb_no     <= '0';
  sram_ub_no     <= '0';
  sram_we_no     <= not sram_we_i;
  sram_oe_no     <= '0';

  -- TODO: Create a reset generator for startup
  rst_i <= '1';

  ledg_o <= "010101100";
  hex0_o <= (others => '1');
  hex1_o <= (others => '1');
  hex2_o <= (others => '1');
  hex3_o <= (others => '1');
  hex4_o <= (others => '1');
  hex5_o <= (others => '1');
  hex6_o <= (others => '1');
  hex7_o <= (others => '1');

end architecture rtl;
