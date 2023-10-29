library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity wb_slave_arbiter is
  generic (
		RST_VECTOR_START: integer := 16#00#;
		RST_VECTOR_STOP: integer := 16#0F#;
		IRQ_TABKE_START: integer := 16#10#;
		IRQ_TABKE_STOP: integer := 16#19#;
		PERIPHERAL_START: integer := 16#0#;
		PERIPHERAL_DELIMETER: integer := 16#20#;
		PERIPHERAL_STOP: integer := 16#7FF#;
		BOOTLOADER_START: integer := 16#800#;
		BOOTLOADER_STOP: integer := 16#87FF#;
		FAST_RAM_START: integer := 16#8800#;
		FAST_RAM_STOP: integer := 16#11A7F#;
		SLOW_RAM_START: integer := 16#11A80#;
		SLOW_RAM_STOP: integer := 16#FFFFFFFF#;
		
		RSTV  : integer := 16#800#;
		IRQ0V : integer := 16#8400#; 
		IRQ1V : integer := 16#8500#;
		IRQ2V : integer := 16#8600#
	
  );
  port (
		 -- Master to slave signals
		 i_wb_cyc			: in	std_logic;
		 i_wb_stb			: in	std_logic;
		 i_wb_we				: in	std_logic;
		 i_wb_addr			: in	std_logic_vector(31 downto 0);
		 i_wb_data			: in	std_logic_vector(31 downto 0);
		 i_wb_sel			: in	std_logic_vector( 3 downto 0);
		 o_wb_stall			: out std_logic;
		 o_wb_ack			: out std_logic;
		 o_wb_data			: out std_logic_vector(31 downto 0);
		 
		-- Peripherals (mask with RST & IRQ)
		o_wb_peripheral_cyc		: out std_logic;
		o_wb_peripheral_stb		: out std_logic;
		o_wb_peripheral_we		: out std_logic;
		o_wb_peripheral_addr		: out std_logic_vector(31 downto 0);
		o_wb_peripheral_data		: out std_logic_vector(31 downto 0);
		o_wb_peripheral_sel		: out std_logic_vector(3 downto 0);
		i_wb_peripheral_stall	: in  std_logic;
		i_wb_peripheral_ack		: in  std_logic;
		i_wb_peripheral_data		: in  std_logic_vector(31 downto 0);
		
		-- BRAM Bootloader ROM
		o_wb_rom_cyc		: out std_logic;
		o_wb_rom_stb		: out std_logic;
		o_wb_rom_we			: out std_logic; -- ignore because read-only
		o_wb_rom_addr		: out std_logic_vector(31 downto 0);
		o_wb_rom_data		: out std_logic_vector(31 downto 0); -- ignore because read-only
		o_wb_rom_sel		: out std_logic_vector(3 downto 0);
		i_wb_rom_stall		: in  std_logic;
		i_wb_rom_ack		: in  std_logic;
		i_wb_rom_data		: in  std_logic_vector(31 downto 0);
		
		-- BRAM Fast RAM
		o_wb_fast_ram_cyc		: out std_logic;
		o_wb_fast_ram_stb		: out std_logic;
		o_wb_fast_ram_we		: out std_logic;
		o_wb_fast_ram_addr	: out std_logic_vector(31 downto 0);
		o_wb_fast_ram_data	: out std_logic_vector(31 downto 0);
		o_wb_fast_ram_sel		: out std_logic_vector(3 downto 0);
		i_wb_fast_ram_stall	: in  std_logic;
		i_wb_fast_ram_ack		: in  std_logic;
		i_wb_fast_ram_data	: in  std_logic_vector(31 downto 0);
		
		-- SDRAM Slow RAM
		o_wb_slow_ram_cyc		: out std_logic;
		o_wb_slow_ram_stb		: out std_logic;
		o_wb_slow_ram_we		: out std_logic;
		o_wb_slow_ram_addr	: out std_logic_vector(31 downto 0);
		o_wb_slow_ram_data	: out std_logic_vector(31 downto 0);
		o_wb_slow_ram_sel		: out std_logic_vector(3 downto 0);
		i_wb_slow_ram_stall	: in  std_logic;
		i_wb_slow_ram_ack		: in  std_logic;
		i_wb_slow_ram_data	: in  std_logic_vector(31 downto 0)

    );
end entity;

architecture rtl of wb_slave_arbiter is
	
	signal s_select_output : std_logic_vector(1 downto 0);
	signal s_peripheral_select : boolean;
	signal s_peripheral_out : std_logic_vector(31 downto 0);
	type t_a_addresses is array (0 to 31) of integer;
	constant a_addresses : t_a_addresses := (
	  0 => RSTV,
	  1 to 15 => 0,
	  16 =>  IRQ0V,
	  17 =>  IRQ1V,
	  18 =>  IRQ2V,
	  19 to 31 => 0
	);
	
begin

	--- Name					Start		End			Select bits	
	--- RST vector			0x00		0x0F			00
	--- IRQ table 			0x10		0x19			00
	--- Peripherals		0x20 		0x7FF			00
   --- BRAM Bootloader 	0x800 	0x87FF		01
	--- BRAM Fast RAM		0x8800 	0x11A7F		10
	--- SDRAM Slow RAM	0x11A80 	0xFFFFFFFF	11
	
	s_peripheral_select <= i_wb_addr >= PERIPHERAL_DELIMETER;
	s_peripheral_out <= std_logic_vector(to_unsigned(a_addresses(to_integer(unsigned(i_wb_addr))), 32)) when not s_peripheral_select else
							  i_wb_peripheral_data;
	s_select_output <= "00" when i_wb_addr <= PERIPHERAL_STOP else
							 "01" when i_wb_addr <= BOOTLOADER_STOP else
							 "10" when i_wb_addr <= FAST_RAM_STOP else
							 "11";
				
   -- Pass requested address with offset 
	o_wb_peripheral_addr <= i_wb_addr - PERIPHERAL_START;
	o_wb_rom_addr <= i_wb_addr - BOOTLOADER_START;
	o_wb_slow_ram_addr <= i_wb_addr - SLOW_RAM_START;
	o_wb_fast_ram_addr <= i_wb_addr - FAST_RAM_START;
	
	
	-- Pass write enable flag
	o_wb_peripheral_we <= i_wb_we when s_select_output = "00" else '0';
	o_wb_rom_we <= '0';
	o_wb_slow_ram_we <= i_wb_we when s_select_output = "10" else '0';
	o_wb_fast_ram_we <= i_wb_we when s_select_output = "11" else '0';
	
	-- Pass strobe
	o_wb_peripheral_stb <= i_wb_stb when s_select_output = "00" and s_peripheral_select else '0';
	o_wb_rom_stb <= i_wb_stb when s_select_output = "01" else '0';
	o_wb_fast_ram_stb <= i_wb_stb when s_select_output = "10" else '0';
	o_wb_slow_ram_stb <= i_wb_stb when s_select_output = "11" else '0';
	
	-- Pass bus cycle
	o_wb_peripheral_cyc <= i_wb_cyc when s_select_output = "00" and s_peripheral_select else '0';
	o_wb_rom_cyc <= i_wb_cyc when s_select_output = "01" else '0';
	o_wb_fast_ram_cyc <= i_wb_cyc when s_select_output = "10" else '0';
	o_wb_slow_ram_cyc <= i_wb_cyc when s_select_output = "11" else '0';
	
	-- Pass select mask
	o_wb_peripheral_sel <= i_wb_sel;
	o_wb_rom_sel <= i_wb_sel;
	o_wb_fast_ram_sel <= i_wb_sel;
	o_wb_slow_ram_sel <= i_wb_sel;
	
	-- Pass data to slave
	o_wb_peripheral_data <= i_wb_data;
	o_wb_rom_data <= (others => '0');
	o_wb_fast_ram_data <= i_wb_data;
	o_wb_slow_ram_data <= i_wb_data;
	
	-- Pass data to master
	o_wb_data <= s_peripheral_out when s_select_output = "00" else
					 i_wb_rom_data when s_select_output = "01" else
					 i_wb_fast_ram_data when s_select_output = "10" else
					 i_wb_slow_ram_data when s_select_output = "11" else
					 (others => '0');

end architecture;
