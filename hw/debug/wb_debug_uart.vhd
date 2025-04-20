library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wb_debug_uart is
  generic (
    clk_period  : time;
    baud_period : time;

    addr_width : natural;
    data_width : natural
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    wb_cyc_o   : out   std_logic;
    wb_dat_i   : in    std_logic_vector(data_width - 1 downto 0);
    wb_dat_o   : out   std_logic_vector(data_width - 1 downto 0);
    wb_ack_i   : in    std_logic;
    wb_addr_o  : out   std_logic_vector(addr_width - 1 downto 0);
    wb_stall_i : in    std_logic;
    wb_sel_o   : out   std_logic_vector((data_width / 8) - 1 downto 0);
    wb_stb_o   : out   std_logic;
    wb_we_o    : out   std_logic;

    uart_rxd_i : in    std_logic;
    uart_txd_o : out   std_logic
  );
end entity wb_debug_uart;

architecture rtl of wb_debug_uart is

  signal cmd       : std_logic_vector(7 downto 0);
  signal cmd_valid : std_logic;

  signal data_consume : std_logic;
  signal data         : std_logic_vector(7 downto 0);
  signal data_valid   : std_logic;

  signal tx_ready : std_logic;

begin

  u_debug : entity work.wb_debug
    generic map (
      addr_width => addr_width,
      data_width => data_width
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,

      wb_cyc_o   => wb_cyc_o,
      wb_dat_i   => wb_dat_i,
      wb_dat_o   => wb_dat_o,
      wb_ack_i   => wb_ack_i,
      wb_addr_o  => wb_addr_o,
      wb_stall_i => wb_stall_i,
      wb_sel_o   => wb_sel_o,
      wb_stb_o   => wb_stb_o,
      wb_we_o    => wb_we_o,

      cmd_i          => cmd,
      cmd_valid_i    => cmd_valid,
      data_consume_i => data_consume,
      data_o         => data,
      data_valid_o   => data_valid
    );

  u_rx : entity work.uart_rx
    generic map (
      clk_period  => clk_period,
      baud_period => baud_period
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,

      uart_i       => uart_rxd_i,
      data_o       => cmd,
      error_o      => open,
      data_valid_o => cmd_valid
    );

  data_consume <= tx_ready and data_valid;

  u_tx : entity work.uart_tx
    generic map (
      clk_period  => clk_period,
      baud_period => baud_period
    )
    port map (
      clk_i => clk_i,
      rst_i => rst_i,

      data_i       => data,
      data_valid_i => data_valid,
      ready_o      => tx_ready,
      uart_o       => uart_txd_o
    );

end architecture rtl;

