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
    data_valid_o : out   std_logic
  );
end entity uart_rx;

architecture rtl of uart_rx is

  type state_t is (state_idle, state_reading_bits, state_stopping);

  constant cycles_per_double_baud : integer := period_to_cycles(baud_period / 2, clk_period, true);
  constant baud_timer_width       : integer := clog2(cycles_per_double_baud);

  signal baud_timer   : unsigned(baud_timer_width - 1 downto 0) := (others => '0');
  signal baud_periods : unsigned(1 downto 0)                    := (others => '0');
  signal bit_index    : unsigned(2 downto 0)                    := (others => '0');
  signal state        : state_t                                 := state_idle;
  signal ready        : std_logic;

begin

  ready <= '1' when baud_timer = 0 and baud_periods = 0 else
           '0';

  uart_receiver_p : process (clk_i, rst_i) is
  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        baud_timer   <= (others => '0');
        baud_periods <= (others => '0');
        bit_index    <= (others => '0');
        data_o       <= (others => '0');
        data_valid_o <= '0';
        state        <= state_idle;
      else
        data_valid_o <= '0';

        case (state) is

          when state_idle =>

            if (uart_i = '0') then
              -- Skip the start bit and center us in the first data bit
              baud_periods <= 2d"2";
              baud_timer   <= to_unsigned(cycles_per_double_baud, baud_timer_width);
              bit_index    <= (others => '0');
              state        <= state_reading_bits;
            end if;

          when state_reading_bits =>

            if (ready = '1') then
              baud_periods                  <= 2d"1";
              baud_timer                    <= to_unsigned(cycles_per_double_baud, baud_timer_width);
              data_o(to_integer(bit_index)) <= uart_i;
              if (bit_index = 7) then
                -- Carry us up to the stop bit and then skip it
                baud_periods <= 2d"2";
                state        <= state_stopping;
                data_valid_o <= '1';
              else
                bit_index <= bit_index + 1;
              end if;
            end if;

          when state_stopping =>

            if (ready = '1') then
              state <= state_idle;
            end if;

        end case;

        if (baud_periods > 0 and baud_timer = 0) then
          baud_timer   <= to_unsigned(cycles_per_double_baud, baud_timer_width);
          baud_periods <= baud_periods - 1;
        end if;
        if (baud_timer > 0) then
          baud_timer <= baud_timer - 1;
        end if;
      end if;
    end if;

  end process uart_receiver_p;

end architecture rtl;

