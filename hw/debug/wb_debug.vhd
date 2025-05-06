library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.math_pkg.all;
  use work.wb_pkg.all;

entity wb_debug is
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    wb_controller_o : out   wb_controller_t;
    wb_target_i     : in    wb_target_t;

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

  signal cmd_byte_sel : std_logic_vector(3 downto 0);
  signal sel          : std_logic_vector(wb_controller_o.sel'range);

begin

  wb_controller_o.dat  <= data(wb_controller_o.dat'range);
  wb_controller_o.addr <= address(wb_controller_o.addr'range);
  wb_controller_o.sel  <= sel;

  cmd_byte_sel <= cmd_i(byte_sel_hi downto byte_sel_lo);

  cmd_p : process (clk_i) is

    variable byte_index : natural;

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

        wb_controller_o.cyc <= '0';
        wb_controller_o.stb <= '0';
        wb_controller_o.we  <= '0';
        sel                 <= (others => '0');
      else

        case (state) is

          when state_idle =>

            if (cmd_valid_i = '1') then

              case (cmd_i(opcode_hi downto opcode_lo)) is

                when op_nop =>

                when op_reg_read =>

                  byte_pointer <= unsigned(cmd_i(len_hi downto len_lo)) - 1;
                  state        <= state_read_reg;

                  byte_index := to_integer(unsigned(cmd_i(len_hi downto len_lo)) - 1);
                  if (cmd_i(a1_d0) = '1') then
                    get_byte32(address, byte_index, data_o);
                  else
                    get_byte32(data, byte_index, data_o);
                  end if;
                  data_valid_o <= '1';
                  active_cmd   <= cmd_i;

                when op_reg_write =>

                  byte_pointer <= unsigned(cmd_i(len_hi downto len_lo));
                  state        <= state_write_reg;
                  active_cmd   <= cmd_i;

                when op_execute =>

                  wb_controller_o.cyc <= '1';
                  wb_controller_o.stb <= '1';
                  wb_controller_o.we  <= cmd_i(w1_r0);
                  sel                 <= cmd_byte_sel(wb_controller_o.sel'range);
                  active_cmd          <= cmd_i;
                  if (wb_target_i.stall = '1') then
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
                byte_index   := to_integer(byte_pointer - 1);
                if (active_cmd(a1_d0) = '1') then
                  get_byte32(address, byte_index, data_o);
                else
                  get_byte32(data, byte_index, data_o);
                end if;
                data_valid_o <= '1';
              end if;
            end if;

          when state_write_reg =>

            if (cmd_valid_i = '1') then
              byte_pointer <= byte_pointer - 1;
              byte_index   := to_integer(byte_pointer) - 1;
              if (active_cmd(a1_d0) = '1') then
                set_byte32(address, byte_index, cmd_i, address);
              else
                set_byte32(data, byte_index, cmd_i, data);
              end if;
              if (byte_pointer = 1) then
                state <= state_idle;
              end if;
            end if;

          when state_execute_start =>

            if (wb_target_i.stall = '0') then
              state <= state_execute_wait;
            end if;

          when state_execute_wait =>

            -- TODO: Maybe this should generate an ACK of some kind on the
            --       debug bus. That would allow the debug controller to wait between
            --       commands, since it would know when the execute command is done.
            if (wb_target_i.ack = '1') then
              wb_controller_o.cyc <= '0';
              wb_controller_o.stb <= '0';
              state               <= state_idle;
              if (active_cmd(w1_r0) = '0') then
                data <= std_logic_vector(resize(unsigned(wb_target_i.dat), 32));
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
