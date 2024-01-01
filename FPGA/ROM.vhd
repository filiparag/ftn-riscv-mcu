library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;
use IEEE.math_real.all;
use std.textio.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity ROM is
	generic (
		g_ROM_SIZE : positive := 2048
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
end ROM;

architecture Behavioral of ROM is

--	type ROM_BYTE_BANK is array (natural range 0 to g_ROM_SIZE - 1) of std_logic_vector(7 downto 0);
--
--	impure function bank_from_file(file_name : in string; bank: in natural) return ROM_BYTE_BANK is
--		file file_handle : text open read_mode is file_name;
--		variable file_line : line;
--		variable rom_line : bit_vector(o_wb_data'length-1 downto 0);
--		variable rom_bank : ROM_BYTE_BANK;
--	begin
--		for i in ROM_BYTE_BANK'range loop
--			if endfile(file_handle) then
--				report "ROM file ends after" & integer'image(i) & " rows." severity error;
--				rom_bank(i) := (others => '0');
--			else
--				readline(file_handle, file_line);
--				read(file_line , rom_line);
--				rom_bank(i) := to_stdlogicvector(rom_line((bank+1)*8-1 downto bank*8));
--			end if;
--		end loop;
--		return rom_bank;
--	end function;
--	
--	signal s_rom_bank0 : ROM_BYTE_BANK := bank_from_file("bootloader.rom", 0);
--	signal s_rom_bank1 : ROM_BYTE_BANK := bank_from_file("bootloader.rom", 1);
--	signal s_rom_bank2 : ROM_BYTE_BANK := bank_from_file("bootloader.rom", 2);
--	signal s_rom_bank3 : ROM_BYTE_BANK := bank_from_file("bootloader.rom", 3);
	
	signal s_wb_ack : std_logic;
	signal s_wb_stall : std_logic;
	
	constant c_rom_addr_len : positive := positive(ceil(log2(real(g_ROM_SIZE))));
	
	signal s_rom_addr : std_logic_vector(c_rom_addr_len - 1 downto 0);
	signal s_rom_data : std_logic_vector(31 downto 0);
	
begin

	altsyncram_component : altsyncram
	GENERIC MAP (
		address_aclr_a => "NONE",
		clock_enable_input_a => "BYPASS",
		clock_enable_output_a => "BYPASS",
		init_file => "../bootloader/build/bootloader.hex",
		intended_device_family => "MAX 10",
		lpm_hint => "ENABLE_RUNTIME_MOD=YES,INSTANCE_NAME=brom",
		lpm_type => "altsyncram",
		numwords_a => g_ROM_SIZE,
		operation_mode => "ROM",
		outdata_aclr_a => "NONE",
		outdata_reg_a => "CLOCK0",
		widthad_a => c_rom_addr_len,
		width_a => 32,
		width_byteena_a => 1
	)
	PORT MAP (
		address_a => s_rom_addr(c_rom_addr_len - 1 downto 0),
		clock0 => clk,
		q_a => s_rom_data
	);
	
	s_rom_addr <= i_wb_addr(c_rom_addr_len - 1 downto 0);
	
	--o_led <= s_rom_data(7 downto 0);

	wb_read : process(clk, rst_n)
	begin
		if(rst_n = '0') then
			o_wb_data <= (others => '0');
		elsif rising_edge(clk) then
			if i_wb_stb = '1' and i_wb_we = '0' then
				if i_wb_addr < g_ROM_SIZE then
					o_wb_data <= s_rom_data;
					o_led <= s_rom_data(7 downto 0);
				else
					o_wb_data <= (others => '0');
					o_led <= (others => '0');
				end if;
			end if;
		end if;
	end process;

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
