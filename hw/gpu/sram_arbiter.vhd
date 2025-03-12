library ieee;
  use ieee.std_logic_1164.all;

entity sram_arbiter is
  port (
    clk  : in    std_logic;
    arst : in    std_logic;

    a_sram_addr    : in    std_logic_vector(19 downto 0);
    a_sram_data_wr : in    std_logic_vector(15 downto 0);
    a_sram_we      : in    std_logic;
    a_req          : in    std_logic;
    a_ack          : out   std_logic;

    b_sram_addr    : in    std_logic_vector(19 downto 0);
    b_sram_data_wr : in    std_logic_vector(15 downto 0);
    b_sram_we      : in    std_logic;
    b_req          : in    std_logic;
    b_ack          : out   std_logic;

    priority_a_0_b_1 : in    std_logic;

    sram_addr    : out   std_logic_vector(19 downto 0);
    sram_data_wr : out   std_logic_vector(15 downto 0);
    sram_we      : out   std_logic
  );
end entity sram_arbiter;

architecture rtl of sram_arbiter is

  signal a_ack_i : std_logic;
  signal b_ack_i : std_logic;

begin

  a_ack_i <= '1' when (a_req = '1' and priority_a_0_b_1 = '0') else
             '0';
  b_ack_i <= '1' when (b_req = '1' and priority_a_0_b_1 = '1') else
             '0';
  a_ack   <= a_ack_i;
  b_ack   <= b_ack_i;

  sram_addr    <= a_sram_addr when (a_ack_i = '1') else
                  b_sram_addr;
  sram_data_wr <= a_sram_data_wr when (a_ack_i = '1') else
                  b_sram_data_wr;
  sram_we      <= a_sram_we when (a_ack_i = '1') else
                  b_sram_we;

end architecture rtl;
