library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_uart_rx is
end entity tb_uart_rx;

architecture behave of tb_uart_rx is

  constant clk_period  : time := 10 ns;   -- 100 MHz
  constant baud_period : time := 4340 ns; -- 230.400 kHz

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal uart       : std_logic := '1';
  signal data       : std_logic_vector(7 downto 0);
  signal data_valid : std_logic;
  signal data_error : std_logic;

  signal stored_data       : std_logic_vector(7 downto 0);
  signal stored_data_valid : std_logic;
  signal clear_stored_data : std_logic;

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
      data_valid_o => data_valid,
      error_o      => data_error
    );

  clk <= not clk after clk_period / 2;

  data_capture_p : process (clk) is
  begin

    if rising_edge(clk) then
      if (rst = '1') then
        stored_data_valid <= '0';
      else
        if (data_valid = '1') then
          stored_data       <= data;
          stored_data_valid <= '1';
        end if;
        if (clear_stored_data = '1') then
          stored_data_valid <= '0';
          stored_data       <= (others => 'U');
        end if;
      end if;
    end if;

  end process data_capture_p;

  error_watcher_p : process (clk) is
  begin

    if rising_edge(clk) then
      if (rst = '0') then
        assert data_error = '0'
          report "Data error detected"
          severity failure;
      end if;
    end if;

  end process error_watcher_p;

  stimulus_p : process is

    procedure uart_write (
      constant byte : in std_logic_vector(7 downto 0)
    ) is
    begin

      clear_stored_data <= '1';
      wait until rising_edge(clk);
      clear_stored_data <= '0';

      -- Start bit
      uart <= '0';
      wait for baud_period;

      -- Data
      for i in 0 to 7 loop

        uart <= byte(i);
        wait for baud_period;

      end loop;

      -- Stop bit
      uart <= '1';
      wait for baud_period;

      assert stored_data_valid = '1'
        severity failure;
      assert stored_data = byte
        severity failure;

    end procedure uart_write;

  begin

    clear_stored_data <= '0';
    uart              <= '0';

    rst <= '1';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    rst <= '0';
    wait until rising_edge(clk);

    uart_write(8x"55");
    uart_write(8x"AA");
    uart_write(8x"6E");
    uart_write(8x"AE");
    wait for clk_period * 20;
    uart_write(8x"9F");
    uart_write(8x"00");
    uart_write(8x"FF");

    wait for baud_period;

    finish;

  end process stimulus_p;

end architecture behave;
