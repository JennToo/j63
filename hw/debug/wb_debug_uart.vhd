library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.wb_pkg.all;

entity wb_debug_uart is
  generic (
    clk_period  : time;
    baud_period : time
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    wb_controller_o : out   wb_controller_t;
    wb_target_i     : in    wb_target_t;

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
    port map (
      clk_i => clk_i,
      rst_i => rst_i,

      wb_controller_o => wb_controller_o,
      wb_target_i     => wb_target_i,

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
