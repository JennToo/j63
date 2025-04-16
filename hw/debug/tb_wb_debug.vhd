library std;
  use std.env.all;

library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity tb_wb_debug is
end entity tb_wb_debug;

architecture behave of tb_wb_debug is

  constant clk_period : time := 10 ns;

  signal clk : std_logic := '0';
  signal rst : std_logic := '1';

  signal wb_cyc    : std_logic;
  signal wb_dat_rd : std_logic_vector(15 downto 0);
  signal wb_dat_wr : std_logic_vector(15 downto 0);
  signal wb_ack    : std_logic;
  signal wb_addr   : std_logic_vector(19 downto 0);
  signal wb_stall  : std_logic;
  signal wb_sel    : std_logic_vector(1 downto 0);
  signal wb_stb    : std_logic;
  signal wb_we     : std_logic;

  signal cmd          : std_logic_vector(7 downto 0);
  signal cmd_valid    : std_logic;
  signal data_consume : std_logic;
  signal data         : std_logic_vector(7 downto 0);
  signal data_valid   : std_logic;

  signal read_value : std_logic_vector(31 downto 0);

begin

  clk <= not clk after clk_period / 2;

  u_wb_debug : entity work.wb_debug
    generic map (
      addr_width => 20,
      data_width => 16
    )
    port map (
      clk_i => clk,
      rst_i => rst,

      wb_cyc_o   => wb_cyc,
      wb_dat_i   => wb_dat_rd,
      wb_dat_o   => wb_dat_wr,
      wb_ack_i   => wb_ack,
      wb_addr_o  => wb_addr,
      wb_stall_i => wb_stall,
      wb_sel_o   => wb_sel,
      wb_stb_o   => wb_stb,
      wb_we_o    => wb_we,

      cmd_i          => cmd,
      cmd_valid_i    => cmd_valid,
      data_consume_i => data_consume,
      data_o         => data,
      data_valid_o   => data_valid
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

  begin

    data_consume <= '0';
    cmd          <= (others => '0');
    cmd_valid    <= '0';

    rst <= '1';
    wait for clk_period;
    rst <= '0';

    write_reg('1', 32x"5544AB07");
    read_reg('1', read_value);
    assert read_value = 32x"5544AB07"
      severity failure;
    read_reg('0', read_value);
    assert read_value = 32x"0"
      severity failure;

    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    finish;

  end process stimulus_p;

end architecture behave;

