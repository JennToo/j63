library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use work.wb_pkg.all;

entity tb_wb_debug is
end entity tb_wb_debug;

architecture behave of tb_wb_debug is

  constant clk_period : time      := 10 ns;
  constant addr_reg   : std_logic := '1';
  constant data_reg   : std_logic := '0';

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal wb_controller : wb_controller_t
         (
          addr(19 downto 0),
          dat(15 downto 0),
          sel(1 downto 0)
        );
  signal wb_target     : wb_target_t
         (
          dat(15 downto 0)
        );

  signal sram_addr    : std_logic_vector(19 downto 0);
  signal sram_data_wr : std_logic_vector(15 downto 0);
  signal sram_data_rd : std_logic_vector(15 downto 0);
  signal sram_we      : std_logic;

  signal cmd          : std_logic_vector(7 downto 0);
  signal cmd_valid    : std_logic;
  signal data_consume : std_logic;
  signal data         : std_logic_vector(7 downto 0);
  signal data_valid   : std_logic;

  signal read_value : std_logic_vector(31 downto 0);

begin

  clk <= not clk after clk_period / 2;

  u_wb_debug : entity work.wb_debug
    port map (
      clk_i => clk,
      rst_i => rst,

      wb_controller_o => wb_controller,
      wb_target_i     => wb_target,

      cmd_i          => cmd,
      cmd_valid_i    => cmd_valid,
      data_consume_i => data_consume,
      data_o         => data,
      data_valid_o   => data_valid
    );

  u_sim_sram : entity work.sim_sram
    port map (
      clk_i => clk,
      rst_i => rst,

      sram_addr_i => sram_addr,
      sram_data_i => sram_data_wr,
      sram_data_o => sram_data_rd,
      sram_we_i   => sram_we
    );

  u_wb_sram : entity work.wb_sram
    generic map (
      addr_width => 20,
      data_width => 16
    )
    port map (
      clk_i => clk,
      rst_i => rst,

      wb_controller_i => wb_controller,
      wb_target_o     => wb_target,

      sram_addr_o => sram_addr,
      sram_dat_o  => sram_data_wr,
      sram_dat_i  => sram_data_rd,
      sram_sel_o  => open,
      sram_we_o   => sram_we
    );

  stimulus_p : process is

    procedure send_byte (
      byte : in std_logic_vector(7 downto 0)
    ) is begin

      wait until rising_edge(clk);
      cmd       <= byte;
      cmd_valid <= '1';
      wait until rising_edge(clk);
      cmd       <= (others => '0');
      cmd_valid <= '0';

    end procedure send_byte;

    procedure write_reg (
      constant a1_d0 : in std_logic;
      constant value : in std_logic_vector(31 downto 0)
    ) is begin

      send_byte("00" & "100" & a1_d0 & "10");
      send_byte(value(31 downto 24));
      send_byte(value(23 downto 16));
      send_byte(value(15 downto 8));
      send_byte(value(7 downto 0));

    end procedure write_reg;

    procedure read_reg (
      constant a1_d0 : in std_logic;
      signal value   : out std_logic_vector(31 downto 0)
    ) is begin

      data_consume <= '0';
      send_byte("00" & "100" & a1_d0 & "01");

      wait until data_valid = '1' for 10 * clk_period;
      assert data_valid = '1'
        severity failure;
      value(31 downto 24) <= data;
      data_consume        <= '1';
      wait until rising_edge(clk);
      data_consume        <= '0';
      wait until rising_edge(clk);

      assert data_valid = '1'
        severity failure;
      value(23 downto 16) <= data;
      data_consume        <= '1';
      wait until rising_edge(clk);
      data_consume        <= '0';
      wait until rising_edge(clk);

      assert data_valid = '1'
        severity failure;
      value(15 downto 8) <= data;
      data_consume       <= '1';
      wait until rising_edge(clk);
      data_consume       <= '0';
      wait until rising_edge(clk);

      assert data_valid = '1'
        severity failure;
      value(7 downto 0) <= data;
      data_consume      <= '1';
      wait until rising_edge(clk);
      data_consume      <= '0';
      wait until rising_edge(clk);

      wait until data_valid = '0' for 10 * clk_period;
      assert data_valid = '0'
        severity failure;

    end procedure read_reg;

    procedure execute (
      constant w1_r0 : in std_logic;
      constant inc_a : in std_logic;

      constant byte_sel : in std_logic_vector(3 downto 0)
    ) is begin

      send_byte(byte_sel & inc_a & w1_r0 & "11");
      -- TODO: Remove hacks
      wait until rising_edge(clk);
      wait until rising_edge(clk);
      wait until rising_edge(clk);

    end procedure execute;

  begin

    data_consume <= '0';
    cmd          <= (others => '0');
    cmd_valid    <= '0';

    rst <= '1';
    wait for clk_period;
    rst <= '0';

    write_reg(addr_reg, 32x"1000");
    write_reg(data_reg, 32x"1155AD");
    execute('1', '0', "1111");
    write_reg(data_reg, 32x"0");
    read_reg(addr_reg, read_value);
    assert read_value = 32x"1000"
      severity failure;
    execute('0', '1', "1111");
    read_reg(addr_reg, read_value);
    assert read_value = 32x"1001"
      severity failure;
    read_reg(data_reg, read_value);
    assert read_value = 32x"55AD"
      severity failure;

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    finish;

  end process stimulus_p;

end architecture behave;

