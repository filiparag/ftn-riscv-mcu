library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all;

entity wb_slave_arbiter is
  generic (
		
		INIT_SIZE:		positive := 16#20#; 		-- Reset and IRQ vectors
		PERIPH_SIZE:	positive := 16#800#; 	-- Memory-mapped peripherals (including init size)
		BOOT_SIZE:		positive := 16#4000#; 	-- Bootloader
		FW_SIZE:			positive := 16#D280#; 	-- Firmware
		SDRAM_SIZE:		positive := 16#100000#; -- SD RAM (including previous)
		
		RST_VEC  : integer := 16#0800#; -- Jump to bootloader start
		IRQ0_VEC : integer := 16#0C00#;
		IRQ1_VEC : integer := 16#0D00#;
		IRQ2_VEC : integer := 16#0E00#
	
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
		o_wb_periph_cyc		: out std_logic;
		o_wb_periph_stb		: out std_logic;
		o_wb_periph_we			: out std_logic;
		o_wb_periph_addr		: out std_logic_vector(31 downto 0);
		o_wb_periph_data		: out std_logic_vector(31 downto 0);
		o_wb_periph_sel		: out std_logic_vector(3 downto 0);
		i_wb_periph_stall		: in  std_logic;
		i_wb_periph_ack		: in  std_logic;
		i_wb_periph_data		: in  std_logic_vector(31 downto 0);
		
		-- BRAM Bootloader
		o_wb_boot_cyc		: out std_logic;
		o_wb_boot_stb		: out std_logic;
		o_wb_boot_we		: out std_logic; -- ignore because read-only
		o_wb_boot_addr		: out std_logic_vector(31 downto 0);
		o_wb_boot_data		: out std_logic_vector(31 downto 0); -- ignore because read-only
		o_wb_boot_sel		: out std_logic_vector(3 downto 0);
		i_wb_boot_stall	: in  std_logic;
		i_wb_boot_ack		: in  std_logic;
		i_wb_boot_data		: in  std_logic_vector(31 downto 0);
		
		-- BRAM Firmware
		o_wb_fw_cyc		: out std_logic;
		o_wb_fw_stb		: out std_logic;
		o_wb_fw_we		: out std_logic;
		o_wb_fw_addr	: out std_logic_vector(31 downto 0);
		o_wb_fw_data	: out std_logic_vector(31 downto 0);
		o_wb_fw_sel		: out std_logic_vector(3 downto 0);
		i_wb_fw_stall	: in  std_logic;
		i_wb_fw_ack		: in  std_logic;
		i_wb_fw_data	: in  std_logic_vector(31 downto 0);
		
		-- SDRAM Memory
		o_wb_sdram_cyc		: out std_logic;
		o_wb_sdram_stb		: out std_logic;
		o_wb_sdram_we		: out std_logic;
		o_wb_sdram_addr	: out std_logic_vector(31 downto 0);
		o_wb_sdram_data	: out std_logic_vector(31 downto 0);
		o_wb_sdram_sel		: out std_logic_vector(3 downto 0);
		i_wb_sdram_stall	: in  std_logic;
		i_wb_sdram_ack		: in  std_logic;
		i_wb_sdram_data	: in  std_logic_vector(31 downto 0)

    );
end entity;

--- NAME					START		END			SELECTOR
--- RST vector			0x00		0x0F			00
--- IRQ table 			0x10		0x19			00
--- Peripherals		0x20 		0x7FF			00
--- BRAM Bootloader 	0x800 	0x47FF		01
--- BRAM Firmware		0x4800 	0x11A7F		10
--- SDRAM Memory		0x11A80 	0xFFFFFFFF	11

architecture rtl of wb_slave_arbiter is
	
	signal s_select_output : 		std_logic_vector(1 downto 0);
	signal s_peripheral_select : 	boolean;
	signal s_peripheral_out : 		std_logic_vector(31 downto 0);
	type t_a_addresses is array (0 to 31) of integer;
	constant a_addresses : t_a_addresses := ( -- Init region virtual memory data
	  0 => RST_VEC,
	  1 to 15 => 0,
	  16 =>  IRQ0_VEC,
	  17 =>  IRQ1_VEC,
	  18 =>  IRQ2_VEC,
	  19 to 31 => 0
	);
	
	constant PERIPH_START:	positive := INIT_SIZE; 							-- 0x20
	constant PERIPH_END: 	positive := PERIPH_SIZE - 1; 					-- 0x7FF
	constant BOOT_START: 	positive := PERIPH_SIZE; 						-- 0x800
	constant BOOT_END: 		positive := BOOT_START + BOOT_SIZE - 1; 	-- 0x47FF
	constant FW_START:		positive := BOOT_END + 1; 						-- 0x4800
	constant FW_END: 			positive := FW_START + FW_SIZE - 1; 		-- 0x11A7F
	constant SDRAM_START:	positive := FW_END + 1; 						-- 0x11A80
	constant SDRAM_END: 		positive := SDRAM_SIZE; 						-- 0x100000
	
begin
	
	-- Virtual init region and memory-mapped peripherals share address space
	s_peripheral_select <= i_wb_addr >= PERIPH_START;
	s_peripheral_out <= std_logic_vector(to_unsigned(a_addresses(to_integer(unsigned(i_wb_addr))), 32)) when not s_peripheral_select else
							  i_wb_periph_data;
							  
	-- Select correct data based on address	  
	s_select_output <= "00" when i_wb_addr <= PERIPH_END else
							 "01" when i_wb_addr <= BOOT_END else
							 "10" when i_wb_addr <= FW_END else
							 "11";
				
   -- Pass requested address with offset 
	o_wb_periph_addr <= i_wb_addr - PERIPH_START;
	o_wb_boot_addr <= i_wb_addr - BOOT_START;
	o_wb_fw_addr <= i_wb_addr - FW_START;
	o_wb_sdram_addr <= i_wb_addr - SDRAM_START;
	
	-- Pass write enable flag
	o_wb_periph_we <= i_wb_we when s_select_output = "00" else '0';
	o_wb_boot_we <= '0'; -- read only
	o_wb_fw_we <= i_wb_we when s_select_output = "10" else '0';
	o_wb_sdram_we <= i_wb_we when s_select_output = "11" else '0';
	
	-- Pass strobe
	o_wb_periph_stb <= i_wb_stb when s_select_output = "00" and s_peripheral_select else '0';
	o_wb_boot_stb <= i_wb_stb when s_select_output = "01" else '0';
	o_wb_fw_stb <= i_wb_stb when s_select_output = "10" else '0';
	o_wb_sdram_stb <= i_wb_stb when s_select_output = "11" else '0';
	
	-- Pass bus cycle
	o_wb_periph_cyc <= i_wb_cyc when s_select_output = "00" and s_peripheral_select else '0';
	o_wb_boot_cyc <= i_wb_cyc when s_select_output = "01" else '0';
	o_wb_fw_cyc <= i_wb_cyc when s_select_output = "10" else '0';
	o_wb_sdram_cyc <= i_wb_cyc when s_select_output = "11" else '0';
	
	-- Pass select mask
	o_wb_periph_sel <= i_wb_sel;
	o_wb_boot_sel <= i_wb_sel;
	o_wb_fw_sel <= i_wb_sel;
	o_wb_sdram_sel <= i_wb_sel;
	
	-- Pass data to slave
	o_wb_periph_data <= i_wb_data;
	o_wb_boot_data <= (others => '0'); -- read only
	o_wb_fw_data <= i_wb_data;
	o_wb_sdram_data <= i_wb_data;
	
	-- Pass data to master
	o_wb_data <= s_peripheral_out when s_select_output = "00" else
					 i_wb_boot_data when s_select_output = "01" else
					 i_wb_fw_data when s_select_output = "10" else
					 i_wb_sdram_data when s_select_output = "11" else
					 (others => '0');

end architecture;
