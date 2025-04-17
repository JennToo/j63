library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.math_pkg.all;

entity wb_debug is
  generic (
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

    cmd_i          : in    std_logic_vector(7 downto 0);
    cmd_valid_i    : in    std_logic;
    data_consume_i : in    std_logic;
    data_o         : out   std_logic_vector(7 downto 0);
    data_valid_o   : out   std_logic
  );
end entity wb_debug;

architecture rtl of wb_debug is

  type state_t is (state_idle, state_read_reg, state_write_reg, state_execute_start, state_execute_wait);

  constant op_nop       : std_logic_vector(1 downto 0) := "00";
  constant op_reg_read  : std_logic_vector(1 downto 0) := "01";
  constant op_reg_write : std_logic_vector(1 downto 0) := "10";
  constant op_execute   : std_logic_vector(1 downto 0) := "11";

  constant opcode_lo   : natural := 0;
  constant opcode_hi   : natural := 1;
  constant a1_d0       : natural := 2;
  constant len_lo      : natural := 3;
  constant len_hi      : natural := 5;
  constant w1_r0       : natural := 2;
  constant auto_inc_a  : natural := 3;
  constant byte_sel_lo : natural := 4;
  constant byte_sel_hi : natural := 7;

  signal address : std_logic_vector(31 downto 0);
  signal data    : std_logic_vector(31 downto 0);

  signal active_cmd   : std_logic_vector(7 downto 0);
  signal byte_pointer : unsigned(2 downto 0);
  signal state        : state_t;

begin

  wb_dat_o  <= data(data_width - 1 downto 0);
  wb_addr_o <= address(addr_width - 1 downto 0);

  cmd_p : process (clk_i) is

    variable byte_range_v : range_t;

  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        byte_pointer <= (others => '0');
        state        <= state_idle;
        active_cmd   <= (others => '0');

        address <= (others => '0');
        data    <= (others => '0');

        data_o       <= (others => '0');
        data_valid_o <= '0';

        wb_cyc_o <= '0';
        wb_stb_o <= '0';
        wb_we_o  <= '0';
        wb_sel_o <= (others => '0');
      else

        case (state) is

          when state_idle =>

            if (cmd_valid_i = '1') then

              case (cmd_i(opcode_hi downto opcode_lo)) is

                when op_nop =>

                when op_reg_read =>

                  byte_pointer <= unsigned(cmd_i(len_hi downto len_lo)) - 1;
                  state        <= state_read_reg;

                  byte_range_v := byte_range(to_integer(unsigned(cmd_i(len_hi downto len_lo)) - 1));
                  if (cmd_i(a1_d0) = '1') then
                    data_o <= address(byte_range_v.high downto byte_range_v.low);
                  else
                    data_o <= data(byte_range_v.high downto byte_range_v.low);
                  end if;
                  data_valid_o <= '1';
                  active_cmd   <= cmd_i;

                when op_reg_write =>

                  byte_pointer <= unsigned(cmd_i(len_hi downto len_lo));
                  state        <= state_write_reg;
                  active_cmd   <= cmd_i;

                when op_execute =>

                  wb_cyc_o   <= '1';
                  wb_stb_o   <= '1';
                  wb_we_o    <= cmd_i(w1_r0);
                  wb_sel_o   <= cmd_i(byte_sel_hi downto byte_sel_lo);
                  active_cmd <= cmd_i;
                  if (wb_stall_i = '1') then
                    state <= state_execute_start;
                  else
                    state <= state_execute_wait;
                  end if;

                when others =>

              end case;

            end if;

          when state_read_reg =>

            if (data_consume_i = '1') then
              if (byte_pointer = 0) then
                state        <= state_idle;
                data_valid_o <= '0';
              else
                byte_pointer <= byte_pointer - 1;
                byte_range_v := byte_range(to_integer(byte_pointer - 1));
                if (active_cmd(a1_d0) = '1') then
                  data_o <= address(byte_range_v.high downto byte_range_v.low);
                else
                  data_o <= data(byte_range_v.high downto byte_range_v.low);
                end if;
                data_valid_o <= '1';
              end if;
            end if;

          when state_write_reg =>

            if (cmd_valid_i = '1') then
              byte_pointer <= byte_pointer - 1;
              byte_range_v := byte_range(to_integer(byte_pointer) - 1);
              if (active_cmd(a1_d0) = '1') then
                address(byte_range_v.high downto byte_range_v.low) <= cmd_i;
              else
                data(byte_range_v.high downto byte_range_v.low) <= cmd_i;
              end if;
              if (byte_pointer = 1) then
                state <= state_idle;
              end if;
            end if;

          when state_execute_start =>

            if (wb_stall_i = '0') then
              state <= state_execute_wait;
            end if;

          when state_execute_wait =>

            -- TODO: Maybe this should generate an ACK of some kind on the
            --       debug bus. That would allow the debug controller to wait between
            --       commands, since it would know when the execute command is done.
            if (wb_ack_i = '1') then
              wb_cyc_o <= '0';
              wb_stb_o <= '0';
              state    <= state_idle;
              if (active_cmd(w1_r0) = '0') then
                data <= wb_dat_i;
              end if;
              if (active_cmd(auto_inc_a) = '1') then
                address <= std_logic_vector(unsigned(address) + 1);
              end if;
            end if;

        end case;

      end if;
    end if;

  end process cmd_p;

end architecture rtl;

