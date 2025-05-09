library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.math_pkg.all;

entity uart_rx is
  generic (
    clk_period  : time;
    baud_period : time
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    uart_i       : in    std_logic;
    data_o       : out   std_logic_vector(7 downto 0);
    error_o      : out   std_logic;
    data_valid_o : out   std_logic
  );
end entity uart_rx;

architecture rtl of uart_rx is

  type state_t is (state_idle, state_starting, state_reading_bits, state_stopping);

  constant cycles_per_baud      : integer := period_to_cycles(baud_period, clk_period, true);
  constant cycles_per_half_baud : integer := cycles_per_baud / 2;
  constant baud_timer_width     : integer := clog2(cycles_per_baud);

  signal baud_timer : unsigned(baud_timer_width - 1 downto 0) := (others => '0');
  signal bit_index  : unsigned(2 downto 0)                    := (others => '0');
  signal state      : state_t                                 := state_idle;
  signal ready      : std_logic;

begin

  ready <= '1' when baud_timer = 0 else
           '0';

  uart_receiver_p : process (clk_i, rst_i) is
  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        baud_timer   <= (others => '0');
        bit_index    <= (others => '0');
        data_o       <= (others => '0');
        data_valid_o <= '0';
        error_o      <= '0';
        state        <= state_idle;
      else
        data_valid_o <= '0';
        error_o      <= '0';

        case (state) is

          when state_idle =>

            if (ready = '1') then
              if (uart_i = '0') then
                baud_timer <= to_unsigned(cycles_per_half_baud, baud_timer_width);
                state      <= state_starting;
              end if;
            end if;

          when state_starting =>

            if (ready = '1') then
              if (uart_i = '0') then
                bit_index  <= (others => '0');
                baud_timer <= to_unsigned(cycles_per_baud, baud_timer_width);
                state      <= state_reading_bits;
              else
                error_o <= '1';
                state   <= state_idle;
              end if;
            end if;

          when state_reading_bits =>

            if (ready = '1') then
              baud_timer                    <= to_unsigned(cycles_per_baud, baud_timer_width);
              data_o(to_integer(bit_index)) <= uart_i;
              if (bit_index = 7) then
                state <= state_stopping;
              else
                bit_index <= bit_index + 1;
              end if;
            end if;

          when state_stopping =>

            if (ready = '1') then
              baud_timer <= to_unsigned(cycles_per_half_baud, baud_timer_width);
              state      <= state_idle;

              if (uart_i = '1') then
                data_valid_o <= '1';
              else
                error_o <= '1';
              end if;
            end if;

        end case;

        if (baud_timer > 0) then
          baud_timer <= baud_timer - 1;
        end if;
      end if;
    end if;

  end process uart_receiver_p;

end architecture rtl;

