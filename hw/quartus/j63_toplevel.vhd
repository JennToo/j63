library ieee;
  use ieee.std_logic_1164.all;

entity j63_toplevel is
  port (
    clock_50   : in    std_logic;
    clock2_50  : in    std_logic;
    clock3_50  : in    std_logic;
    sma_clkin  : in    std_logic;
    sma_clkout : out   std_logic;

    key  : in    std_logic_vector(3 downto 0);
    sw   : in    std_logic_vector(17 downto 0);
    ledg : out   std_logic_vector(8  downto 0);
    ledr : out   std_logic_vector(17 downto 0);
    hex0 : out   std_logic_vector(6 downto 0);
    hex1 : out   std_logic_vector(6 downto 0);
    hex2 : out   std_logic_vector(6 downto 0);
    hex3 : out   std_logic_vector(6 downto 0);
    hex4 : out   std_logic_vector(6 downto 0);
    hex5 : out   std_logic_vector(6 downto 0);
    hex6 : out   std_logic_vector(6 downto 0);
    hex7 : out   std_logic_vector(6 downto 0);

    ex_io : inout std_logic_vector(6 downto 0);

    lcd_blon : out   std_logic;
    lcd_data : inout std_logic_vector(7 downto 0);
    lcd_en   : out   std_logic;
    lcd_on   : out   std_logic;
    lcd_rs   : out   std_logic;
    lcd_rw   : out   std_logic;

    uart_cts : in    std_logic;
    uart_rts : out   std_logic;
    uart_rxd : in    std_logic;
    uart_txd : out   std_logic;

    ps2_clk  : inout std_logic;
    ps2_clk2 : inout std_logic;
    ps2_dat  : inout std_logic;
    ps2_dat2 : inout std_logic;

    sd_clk  : out   std_logic;
    sd_cmd  : inout std_logic;
    sd_dat  : inout std_logic_vector(3 downto 0);
    sd_wp_n : in    std_logic;

    vga_clk     : out   std_logic;
    vga_hs      : out   std_logic;
    vga_vs      : out   std_logic;
    vga_blank_n : out   std_logic;
    vga_sync_n  : out   std_logic;
    vga_r       : out   std_logic_vector(7 downto 0);
    vga_g       : out   std_logic_vector(7 downto 0);
    vga_b       : out   std_logic_vector(7 downto 0);

    aud_adcdat  : in    std_logic;
    aud_adclrck : inout std_logic;
    aud_bclk    : inout std_logic;
    aud_dacdat  : out   std_logic;
    aud_daclrck : inout std_logic;
    aud_xck     : out   std_logic;

    eep_i2c_sclk : out   std_logic;
    eep_i2c_sdat : inout std_logic;

    i2c_sclk : out   std_logic;
    i2c_sdat : inout std_logic;

    enet0_gtx_clk : out   std_logic;
    enet0_int_n   : in    std_logic;
    enet0_link100 : in    std_logic;
    enet0_mdc     : out   std_logic;
    enet0_mdio    : inout std_logic;
    enet0_rst_n   : out   std_logic;
    enet0_rx_clk  : in    std_logic;
    enet0_rx_col  : in    std_logic;
    enet0_rx_crs  : in    std_logic;
    enet0_rx_data : in    std_logic_vector(3 downto 0);
    enet0_rx_dv   : in    std_logic;
    enet0_rx_er   : in    std_logic;
    enet0_tx_clk  : in    std_logic;
    enet0_tx_data : out   std_logic_vector(3 downto 0);
    enet0_tx_en   : out   std_logic;
    enet0_tx_er   : out   std_logic;
    enetclk_25    : in    std_logic;

    enet1_gtx_clk : out   std_logic;
    enet1_int_n   : in    std_logic;
    enet1_link100 : in    std_logic;
    enet1_mdc     : out   std_logic;
    enet1_mdio    : inout std_logic;
    enet1_rst_n   : out   std_logic;
    enet1_rx_clk  : in    std_logic;
    enet1_rx_col  : in    std_logic;
    enet1_rx_crs  : in    std_logic;
    enet1_rx_data : in    std_logic_vector(3 downto 0);
    enet1_rx_dv   : in    std_logic;
    enet1_rx_er   : in    std_logic;
    enet1_tx_clk  : in    std_logic;
    enet1_tx_data : out   std_logic_vector(3 downto 0);
    enet1_tx_en   : out   std_logic;
    enet1_tx_er   : out   std_logic;

    td_clk27   : in    std_logic;
    td_data    : in    std_logic_vector(7 downto 0);
    td_hs      : in    std_logic;
    td_reset_n : out   std_logic;
    td_vs      : in    std_logic;

    otg_addr  : out   std_logic_vector(1 downto 0);
    otg_cs_n  : out   std_logic;
    otg_data  : inout std_logic_vector(15 downto 0);
    otg_int   : in    std_logic;
    otg_rd_n  : out   std_logic;
    otg_rst_n : out   std_logic;
    otg_we_n  : out   std_logic;

    irda_rxd : in    std_logic;

    dram_addr  : out   std_logic_vector(12 downto 0);
    dram_ba    : out   std_logic_vector(1 downto 0);
    dram_cas_n : out   std_logic;
    dram_cke   : out   std_logic;
    dram_clk   : out   std_logic;
    dram_cs_n  : out   std_logic;
    dram_dq    : inout std_logic_vector(31 downto 0);
    dram_dqm   : out   std_logic_vector(3 downto 0);
    dram_ras_n : out   std_logic;
    dram_we_n  : out   std_logic;

    sram_addr : out   std_logic_vector(19 downto 0);
    sram_ce_n : out   std_logic;
    sram_dq   : inout std_logic_vector(15 downto 0);
    sram_lb_n : out   std_logic;
    sram_oe_n : out   std_logic;
    sram_ub_n : out   std_logic;
    sram_we_n : out   std_logic;

    fl_addr  : out   std_logic_vector(22 downto 0);
    fl_ce_n  : out   std_logic;
    fl_dq    : inout std_logic_vector(7 downto 0);
    fl_oe_n  : out   std_logic;
    fl_rst_n : out   std_logic;
    fl_ry    : in    std_logic;
    fl_we_n  : out   std_logic;
    fl_wp_n  : out   std_logic
  );
end entity j63_toplevel;

architecture rtl of j63_toplevel is

  signal clk_sys  : std_logic;
  signal clk_vga  : std_logic;
  signal arst     : std_logic;
  signal vga_hs_i : std_logic;
  signal vga_vs_i : std_logic;

begin

  -- The system clock (100 MHz) is too dissimilar to the VGA clock (25.175 MHz)
  -- to use the same PLL. The SRAM on the DE2 board is rated for 100 MHz operation
  u_sys_pll : entity work.sys_pll
    port map (
      inclk0 => clock_50,
      c0     => clk_sys,
      locked => open
    );

  u_vga_pll : entity work.vga_pll
    port map (
      inclk0 => clock_50,
      c0     => clk_vga,
      locked => open
    );

  vga_clk <= clk_vga;
  vga_hs  <= vga_hs_i when sw(17) else
             '1';
  vga_vs  <= vga_vs_i when sw(17) else
             '1';

  u_gpu : entity work.gpu
    port map (
      clk_sys => clk_sys,
      clk_vga => clk_vga,
      arst    => arst,

      vga_hs      => vga_hs_i,
      vga_vs      => vga_vs_i,
      vga_blank_n => vga_blank_n,
      vga_sync_n  => vga_sync_n,
      vga_r       => vga_r,
      vga_g       => vga_g,
      vga_b       => vga_b
    );

  -- TODO: Create a reset generator for startup
  arst <= '1';

  ledg <= "010101100";
  hex0 <= (others => '1');
  hex1 <= (others => '1');
  hex2 <= (others => '1');
  hex3 <= (others => '1');
  hex4 <= (others => '1');
  hex5 <= (others => '1');
  hex6 <= (others => '1');
  hex7 <= (others => '1');

end architecture rtl;
