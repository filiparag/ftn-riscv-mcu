library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity MEM_BROM is
	generic (
		g_ROM_SIZE : positive := 1024 -- 4KiB
	);
	port (
		clk : in std_logic;
		rst_n : in std_logic;
		i_wb_cyc : in std_logic;
		i_wb_stb : in std_logic;
		i_wb_we : in std_logic;
		i_wb_addr : in std_logic_vector(31 downto 0);
		i_wb_data : in std_logic_vector(31 downto 0);
		i_wb_sel : in std_logic_vector(3 downto 0);
		o_wb_stall : out std_logic;
		o_wb_ack : out std_logic;
		o_wb_data : out std_logic_vector(31 downto 0);

		-- LEDs
		o_led : out std_logic_vector(7 downto 0)
	);
end MEM_BROM;

architecture Behavioral of MEM_BROM is

	constant c_rom_addr_len : positive := positive(ceil(log2(real(g_ROM_SIZE))));

	signal s_wb_ack : std_logic;
	signal s_wb_stall : std_logic;

	signal s_rom_rden : std_logic;
	signal s_rom_addr : std_logic_vector(c_rom_addr_len - 1 downto 0);
	signal s_rom_data : std_logic_vector(31 downto 0);

begin

	altsyncram_component : altsyncram
	GENERIC MAP (
		address_aclr_a => "NONE",
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		init_file => "../bootloader/build/bootloader.quartus.hex",
		intended_device_family => "MAX 10",
		lpm_hint => "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=BROM",
		lpm_type => "altsyncram",
		numwords_a => g_ROM_SIZE,
		operation_mode => "ROM",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		widthad_a => c_rom_addr_len,
		width_a => 32,
		width_byteena_a => 1
	)
	PORT MAP (
		address_a => s_rom_addr(c_rom_addr_len - 1 downto 0),
		clock0 => clk,
		rden_a => s_rom_rden,
		q_a => o_wb_data
	);

	s_rom_rden <= '1' when i_wb_stb = '1' and i_wb_we = '0' else '0';

	s_rom_addr <= i_wb_addr(c_rom_addr_len - 1 + 2 downto 2) when i_wb_addr < g_ROM_SIZE * 4 else
					  (others => '0');

	wb_ack : process(clk, rst_n)
   begin
      if rising_edge(clk) then
         if rst_n = '0' then
            s_wb_ack <= '0';
         else
            if i_wb_stb = '1' and i_wb_cyc = '1' then
               s_wb_ack <= '1' and not s_wb_stall;
            else
               s_wb_ack <= '0';
            end if;
         end if;
      end if;
   end process;

	s_wb_stall <= '0';

	o_wb_ack <= s_wb_ack and i_wb_stb;
	o_wb_stall <= s_wb_stall;

end Behavioral;
