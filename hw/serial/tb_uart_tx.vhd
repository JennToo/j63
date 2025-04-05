library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_uart_tx is
end entity tb_uart_tx;

architecture behave of tb_uart_tx is

  constant clk_period  : time := 10 ns;   -- 100 MHz
  constant baud_period : time := 4340 ns; -- 230.400 kHz

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal data       : std_logic_vector(7 downto 0);
  signal data_valid : std_logic;
  signal ready      : std_logic;
  signal uart       : std_logic;

begin

  clk <= not clk after clk_period / 2;

  u_uart_tx : entity work.uart_tx
    generic map (
      clk_period  => clk_period,
      baud_period => baud_period
    )
    port map (
      clk_i => clk,
      rst_i => rst,

      data_i       => data,
      data_valid_i => data_valid,
      ready_o      => ready,
      uart_o       => uart
    );

  stimulus_p : process is

    procedure uart_read (
      constant byte : in std_logic_vector(7 downto 0)
    ) is
    begin

      assert ready = '1'
        severity failure;
      assert uart = '1'
        severity failure;

      data       <= byte;
      data_valid <= '1';
      wait until rising_edge(clk);
      data_valid <= '0';
      -- Center onto the signal
      wait for baud_period / 2;

      -- Start bit
      assert uart = '0'
        severity failure;
      assert ready = '0'
        severity failure;
      wait for baud_period;

      -- Data
      for i in 0 to 7 loop

        assert uart = byte(i)
          severity failure;
        assert ready = '0'
          severity failure;
        wait for baud_period;

      end loop;

      -- Stop bit
      assert uart = '1'
        severity failure;
      assert ready = '0'
        severity failure;
      wait for baud_period;

      assert uart = '1'
        severity failure;
      assert ready = '1'
        severity failure;

    end procedure uart_read;

  begin

    data_valid <= '0';
    data       <= (others => '0');

    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    uart_read(8x"55");
    uart_read(8x"AA");
    uart_read(8x"6E");
    uart_read(8x"AE");
    wait for clk_period * 20;
    uart_read(8x"9F");
    uart_read(8x"00");
    uart_read(8x"FF");

    finish;

  end process stimulus_p;

end architecture behave;
