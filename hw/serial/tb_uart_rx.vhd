library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_uart_rx is
end entity tb_uart_rx;

architecture behave of tb_uart_rx is

  constant clk_period  : time := 10 ns;   -- 100 MHz
  constant baud_period : time := 4340 ns; -- 230400 kHz

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal uart       : std_logic := '1';
  signal data       : std_logic_vector(7 downto 0);
  signal data_valid : std_logic;

begin

  u_uart_rx : entity work.uart_rx
    generic map (
      clk_period  => clk_period,
      baud_period => baud_period
    )
    port map (
      clk_i => clk,
      rst_i => rst,

      uart_i       => uart,
      data_o       => data,
      data_valid_o => data_valid
    );

  clk <= not clk after clk_period / 2;

  stimulus_p : process is
  begin

    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    uart <= '0';
    wait for baud_period;
    uart <= '1';
    wait for baud_period;
    wait for baud_period;
    uart <= '0';
    wait for baud_period;
    uart <= '1';
    wait for baud_period;
    uart <= '0';
    wait for baud_period;
    wait for baud_period;
    uart <= '1';
    wait for baud_period;
    uart <= '0';
    wait for baud_period;
    uart <= '1';
    wait for baud_period;

    finish;

  end process stimulus_p;

end architecture behave;
