library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity MEM_BRAM is
	generic (
		g_RAM_SIZE : positive := 12288 -- 48KiB
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
		o_wb_data : out std_logic_vector(31 downto 0)
	);
end MEM_BRAM;

architecture Behavioral of MEM_BRAM is
	
	constant c_ram_addr_len : positive := positive(ceil(log2(real(g_RAM_SIZE))));
	
	signal s_wb_ack : std_logic;
	signal s_wb_stall : std_logic;
	
	signal s_ram_wren : std_logic;
	signal s_ram_rden : std_logic;
	signal s_ram_addr : std_logic_vector(c_ram_addr_len - 1 downto 0);
	signal s_ram_data : std_logic_vector(31 downto 0);
	
begin

	altsyncram_component : altsyncram
	GENERIC MAP (
		byte_size => 8,
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		--init_file => "../firmware/build/firmware.quartus.hex",
		intended_device_family => "MAX 10",
		lpm_hint => "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=BRAM",
		lpm_type => "altsyncram",
		numwords_a => g_RAM_SIZE,
		operation_mode => "SINGLE_PORT",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "UNREGISTERED",
		power_up_uninitialized => "FALSE",
		ram_block_type => "M9K",
		read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
		widthad_a => c_ram_addr_len,
		width_a => 32,
		width_byteena_a => 4
	)
	PORT MAP (
		address_a => s_ram_addr,
		byteena_a => i_wb_sel,
		clock0 => clk,
		data_a => i_wb_data,
		rden_a => s_ram_rden,
		wren_a => s_ram_wren,
		q_a => o_wb_data
	);

	s_ram_wren <= '1' when i_wb_stb = '1' and i_wb_we = '1' else '0';
	s_ram_rden <= '1' when i_wb_stb = '1' and i_wb_we = '0' else '0';
	
	s_ram_addr <= i_wb_addr(c_ram_addr_len - 1 + 2 downto 2) when i_wb_addr < g_RAM_SIZE * 4 else
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
