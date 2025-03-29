library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity wb_arbiter is
  generic (
    addr_width : natural;
    data_width : natural
  );
  port (
    clk_i : in    std_logic;
    rst_i : in    std_logic;

    a_wb_cyc_i   : in    std_logic;
    a_wb_dat_i   : in    std_logic_vector(data_width - 1 downto 0);
    a_wb_dat_o   : out   std_logic_vector(data_width - 1 downto 0);
    a_wb_ack_o   : out   std_logic;
    a_wb_addr_i  : in    std_logic_vector(addr_width - 1 downto 0);
    a_wb_stall_o : out   std_logic;
    a_wb_sel_i   : in    std_logic_vector((data_width / 8) - 1 downto 0);
    a_wb_stb_i   : in    std_logic;
    a_wb_we_i    : in    std_logic;

    b_wb_cyc_i   : in    std_logic;
    b_wb_dat_i   : in    std_logic_vector(data_width - 1 downto 0);
    b_wb_dat_o   : out   std_logic_vector(data_width - 1 downto 0);
    b_wb_ack_o   : out   std_logic;
    b_wb_addr_i  : in    std_logic_vector(addr_width - 1 downto 0);
    b_wb_stall_o : out   std_logic;
    b_wb_sel_i   : in    std_logic_vector((data_width / 8) - 1 downto 0);
    b_wb_stb_i   : in    std_logic;
    b_wb_we_i    : in    std_logic;

    target_wb_cyc_o   : out   std_logic;
    target_wb_dat_i   : in    std_logic_vector(data_width - 1 downto 0);
    target_wb_dat_o   : out   std_logic_vector(data_width - 1 downto 0);
    target_wb_ack_i   : in    std_logic;
    target_wb_addr_o  : out   std_logic_vector(addr_width - 1 downto 0);
    target_wb_stall_i : in    std_logic;
    target_wb_sel_o   : out   std_logic_vector((data_width / 8) - 1 downto 0);
    target_wb_stb_o   : out   std_logic;
    target_wb_we_o    : out   std_logic
  );
end entity wb_arbiter;

architecture rtl of wb_arbiter is

  signal a_active   : std_logic;
  signal a_active_d : std_logic;

begin

  keepalive_p : process (clk_i, rst_i) is
  begin

    if rising_edge(clk_i) then
      if (rst_i = '1') then
        a_active_d <= '0';
      else
        a_active_d <= a_active;
      end if;
    end if;

  end process keepalive_p;

  -- Controller A gets the bus under two circumstances:
  -- 1) It is the only one asking for it
  -- 2) It had it last cycle, and continues to ask for it
  a_active <= '1' when (a_wb_cyc_i = '1' and b_wb_cyc_i = '0') or (a_active_d = '1' and a_wb_cyc_i = '1') else
              '0';

  a_wb_dat_o   <= target_wb_dat_i when a_active = '1' else
                  (others => '0');
  a_wb_ack_o   <= target_wb_ack_i when a_active = '1' else
                  '0';
  a_wb_stall_o <= target_wb_stall_i when a_active = '1' else
                  '1';
  b_wb_dat_o   <= target_wb_dat_i when a_active = '0' else
                  (others => '0');
  b_wb_ack_o   <= target_wb_ack_i when a_active = '0' else
                  '0';
  b_wb_stall_o <= target_wb_stall_i when a_active = '0' else
                  '1';

  target_wb_cyc_o  <= a_wb_cyc_i when a_active = '1' else
                      b_wb_cyc_i;
  target_wb_dat_o  <= a_wb_dat_i when a_active = '1' else
                      b_wb_dat_i;
  target_wb_addr_o <= a_wb_addr_i when a_active = '1' else
                      b_wb_addr_i;
  target_wb_sel_o  <= a_wb_sel_i when a_active = '1' else
                      b_wb_sel_i;
  target_wb_stb_o  <= a_wb_stb_i when a_active = '1' else
                      b_wb_stb_i;
  target_wb_we_o   <= a_wb_we_i when a_active = '1' else
                      b_wb_we_i;

end architecture rtl;

