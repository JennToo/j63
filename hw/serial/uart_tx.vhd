library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.math_pkg.all;

entity uart_tx is
  generic (
    clk_period  : time;
    baud_period : time
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    data_i       : in    std_logic_vector(7 downto 0);
    data_valid_i : in    std_logic;
    ready_o      : out   std_logic;
    uart_o       : out   std_logic
  );
end entity uart_tx;

architecture rtl of uart_tx is

  type state_t is (state_idle, state_writing_bits, state_stopping);

  constant cycles_per_baud  : integer := period_to_cycles(baud_period, clk_period, true);
  constant baud_timer_width : integer := clog2(cycles_per_baud);

  signal state       : state_t;
  signal baud_timer  : unsigned(baud_timer_width - 1 downto 0) := (others => '0');
  signal timer_ready : std_logic;
  signal data        : std_logic_vector(7 downto 0);
  signal bit_index   : unsigned(2 downto 0);

begin

  ready_o     <= '1' when state = state_idle  and timer_ready = '1' else
                 '0';
  timer_ready <= '1' when baud_timer = 0 else
                 '0';

  uart_sender_p : process (clk_i) is
  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        state      <= state_idle;
        baud_timer <= (others => '0');
        data       <= (others => '0');
        bit_index  <= (others => '0');
        uart_o     <= '1';
      else

        case (state) is

          when state_idle =>

            uart_o <= '1';
            if (data_valid_i = '1' and timer_ready = '1') then
              -- Start bit
              uart_o     <= '0';
              bit_index  <= (others => '0');
              state      <= state_writing_bits;
              baud_timer <= to_unsigned(cycles_per_baud, baud_timer_width);
              data       <= data_i;
            end if;

          when state_writing_bits =>

            if (timer_ready = '1') then
              uart_o    <= data(to_integer(bit_index));
              bit_index <= bit_index + 1;
              if (bit_index = 7) then
                state <= state_stopping;
              end if;
              baud_timer <= to_unsigned(cycles_per_baud, baud_timer_width);
            end if;

          when state_stopping =>

            if (timer_ready = '1') then
              uart_o     <= '1';
              state      <= state_idle;
              baud_timer <= to_unsigned(cycles_per_baud, baud_timer_width);
            end if;

        end case;

      end if;
      if (baud_timer > 0) then
        baud_timer <= baud_timer - 1;
      end if;
    end if;

  end process uart_sender_p;

end architecture rtl;

