library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity wb_slave_arbiter is
  port (
	 -- master 2 slave signals
	 i_wb_cyc			: in	std_logic;
	 i_wb_stb			: in	std_logic;
	 i_wb_we			: in	std_logic;
	 i_wb_addr			: in	std_logic_vector(31 downto 0);
	 i_wb_data			: in	std_logic_vector(31 downto 0);
	 i_wb_sel			: in	std_logic_vector( 3 downto 0);
	 o_wb_stall			: out std_logic;
	 o_wb_ack			: out std_logic;
	 o_wb_data			: out std_logic_vector(31 downto 0);
	 -- BRAM
	 o_wb_bram_cyc		: out std_logic;
	 o_wb_bram_stb		: out std_logic;
	 o_wb_bram_we		: out std_logic;
--	 o_wb_bram_addr		: out std_logic_vector(13 downto 0);		--changed
	 o_wb_bram_addr		: out std_logic_vector(31 downto 0);
	 o_wb_bram_data		: out std_logic_vector(31 downto 0);
	 o_wb_bram_sel		: out std_logic_vector( 3 downto 0);
	 i_wb_bram_stall	: in  std_logic;
	 i_wb_bram_ack		: in  std_logic;
	 i_wb_bram_data		: in  std_logic_vector(31 downto 0);
	 -- SDRAM
	 o_wb_sdram_cyc		: out std_logic;
	 o_wb_sdram_stb		: out std_logic;
	 o_wb_sdram_we		: out std_logic;
	 o_wb_sdram_addr	: out std_logic_vector(20 downto 0);
	 o_wb_sdram_data	: out std_logic_vector(31 downto 0);
	 o_wb_sdram_sel		: out std_logic_vector( 3 downto 0);
	 i_wb_sdram_stall	: in  std_logic;
	 i_wb_sdram_ack		: in  std_logic;
	 i_wb_sdram_data	: in  std_logic_vector(31 downto 0);
	 -- MM REG
	 o_wb_periph_cyc		: out std_logic;
	 o_wb_periph_stb		: out std_logic;
	 o_wb_periph_we		: out std_logic;
	 o_wb_periph_addr	: out std_logic_vector(31 downto 0);
	 o_wb_periph_data	: out std_logic_vector(31 downto 0);
	 o_wb_periph_sel		: out std_logic_vector( 3 downto 0);
	 i_wb_periph_stall	: in  std_logic;
	 i_wb_periph_ack		: in  std_logic;
	 i_wb_periph_data	: in  std_logic_vector(31 downto 0);
	 -- ROM
	 o_wb_rom_cyc		: out std_logic;
	 o_wb_rom_stb		: out std_logic;
	 o_wb_rom_we		: out std_logic;
	 o_wb_rom_addr	: out std_logic_vector(31 downto 0);
	 o_wb_rom_data	: out std_logic_vector(31 downto 0);
	 o_wb_rom_sel		: out std_logic_vector( 3 downto 0);
	 i_wb_rom_stall	: in  std_logic;
	 i_wb_rom_ack		: in  std_logic;
	 i_wb_rom_data	: in  std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of wb_slave_arbiter is
	
	type t_slave is (BROM, BRAM, SDRAM, MMAP, SEGFAULT);
	signal s_slave : t_slave;
	
begin

	-- BROM			0x000000 - 0x000FFF ( 4KiB)
	-- BRAM			0x001000 - 0x00BFFF (20KiB)
	-- Peripherals	0x008000 - 0x00BFFF (16KiB)
	-- SDRAM 		0x00C000 - 0x10BFFF ( 1MiB)

	s_slave <= BROM when i_wb_addr < 16#1000# else
				  BRAM when i_wb_addr < 16#8000# else
				  MMAP when i_wb_addr < 16#C000# else
				  SDRAM when i_wb_addr < 16#10C000# else
				  --BROM when i_wb_addr < 16#200000# else -- debug
				  SEGFAULT;

	-- Slave to Master outputs
	o_wb_stall <= i_wb_rom_stall when s_slave = BROM else
					  i_wb_bram_stall when s_slave = BRAM else
					  i_wb_periph_stall when s_slave = MMAP else
					  i_wb_sdram_stall when s_slave = SDRAM else
					  '0';
	o_wb_ack <= i_wb_rom_ack when s_slave = BROM else
					i_wb_bram_ack when s_slave = BRAM else
					i_wb_periph_ack when s_slave = MMAP else
					i_wb_sdram_ack when s_slave = SDRAM else
					'0';
	o_wb_data <= i_wb_rom_data when s_slave = BROM else
					 i_wb_bram_data when s_slave = BRAM else
					 i_wb_periph_data when s_slave = MMAP else
					 i_wb_sdram_data when s_slave = SDRAM else
					 (others => '0');
	
	-- BROM
	o_wb_rom_cyc <= i_wb_cyc when s_slave = BROM else '0';
	o_wb_rom_stb <= i_wb_stb when s_slave = BROM else '0';
	o_wb_rom_we <= i_wb_we when s_slave = BROM else '0';
	--o_wb_rom_addr <= i_wb_addr - 16#10C000# when s_slave = BROM else (others => '0'); -- debug
	o_wb_rom_addr <= i_wb_addr when s_slave = BROM else (others => '0');
	o_wb_rom_data <= i_wb_data when s_slave = BROM else (others => '0');
	o_wb_rom_sel <= i_wb_sel when s_slave = BROM else (others => '0');
    
	-- BRAM
	o_wb_bram_cyc <= i_wb_cyc when s_slave = BRAM else '0';
	o_wb_bram_stb <= i_wb_stb when s_slave = BRAM else '0';
	o_wb_bram_we <= i_wb_we when s_slave = BRAM else '0';
	--o_wb_bram_addr <= i_wb_addr when s_slave = BRAM else (others => '0'); -- debug
	o_wb_bram_addr <= i_wb_addr - 16#1000# when s_slave = BRAM else (others => '0');
	o_wb_bram_data <= i_wb_data when s_slave = BRAM else (others => '0');
	o_wb_bram_sel <= i_wb_sel when s_slave = BRAM else (others => '0');

	-- MMAP Peripherals
	o_wb_periph_cyc <= i_wb_cyc when s_slave = MMAP else '0';
	o_wb_periph_stb <= i_wb_stb when s_slave = MMAP else '0';
	o_wb_periph_we <= i_wb_we when s_slave = MMAP else '0';
	o_wb_periph_addr <= i_wb_addr - 16#8000# when s_slave = MMAP else (others => '0');
	o_wb_periph_data <= i_wb_data when s_slave = MMAP else (others => '0');
	o_wb_periph_sel <= i_wb_sel when s_slave = MMAP else (others => '0');

	-- SDRAM
	o_wb_sdram_cyc <= i_wb_cyc when s_slave = SDRAM else '0';
	o_wb_sdram_stb <= i_wb_stb when s_slave = SDRAM else '0';
	o_wb_sdram_we <= i_wb_we when s_slave = SDRAM else '0';
	o_wb_sdram_addr <= i_wb_addr(20 downto 0) when s_slave = SDRAM else (others => '0');
	o_wb_sdram_data <= i_wb_data when s_slave = SDRAM else (others => '0');
	o_wb_sdram_sel <= i_wb_sel when s_slave = SDRAM else (others => '0');

end architecture;
