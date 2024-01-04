library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity wb_slave_arbiter is
  port (
	 -- Master to slave signals
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
	 -- MMAP
	 o_wb_mmap_cyc		: out std_logic;
	 o_wb_mmap_stb		: out std_logic;
	 o_wb_mmap_we		: out std_logic;
	 o_wb_mmap_addr	: out std_logic_vector(31 downto 0);
	 o_wb_mmap_data	: out std_logic_vector(31 downto 0);
	 o_wb_mmap_sel		: out std_logic_vector( 3 downto 0);
	 i_wb_mmap_stall	: in  std_logic;
	 i_wb_mmap_ack		: in  std_logic;
	 i_wb_mmap_data	: in  std_logic_vector(31 downto 0);
	 -- BROM
	 o_wb_brom_cyc		: out std_logic;
	 o_wb_brom_stb		: out std_logic;
	 o_wb_brom_we		: out std_logic;
	 o_wb_brom_addr	: out std_logic_vector(31 downto 0);
	 o_wb_brom_data	: out std_logic_vector(31 downto 0);
	 o_wb_brom_sel		: out std_logic_vector( 3 downto 0);
	 i_wb_brom_stall	: in  std_logic;
	 i_wb_brom_ack		: in  std_logic;
	 i_wb_brom_data	: in  std_logic_vector(31 downto 0)
    );
end entity;

architecture rtl of wb_slave_arbiter is

	-- Firmware		0x00000 .. 0x07FFC ( 32KiB)
	-- Dynamic		0x08000 .. 0x087FC (  2KiB)
	-- Stack			0x08800 .. 0x0BFFC ( 14KiB)
	-- Peripherals	0x0C000 .. 0x0FFFC ( 16KiB)
	-- Bootloader	0x10000 .. 0x10FFC (  4KiB)
	-- SDRAM			0x11000 .. 0xFFFFC (956KiB)

	constant ADDR_BRAM_START	:	integer := 16#00000#;
	constant ADDR_MMAP_START	:	integer := 16#0C000#;
	constant ADDR_BROM_START	:	integer := 16#10000#;
	constant ADDR_SDRAM_START	:	integer := 16#11000#;
	constant ADDR_SDRAM_END		:	integer := 16#FFFFF#;
	
	type t_slave is (BROM, BRAM, SDRAM, MMAP, SEGFAULT);
	signal s_slave : t_slave;
	
begin

	-- Slave --
	s_slave <=	BRAM when i_wb_addr < ADDR_MMAP_START else
					MMAP when i_wb_addr < ADDR_BROM_START else
					BROM when i_wb_addr < ADDR_SDRAM_START else
					SDRAM when i_wb_addr <= ADDR_SDRAM_END else
					SEGFAULT;

	-- Slave to Master outputs --
	o_wb_stall <= i_wb_brom_stall when s_slave = BROM else
					  i_wb_bram_stall when s_slave = BRAM else
					  i_wb_mmap_stall when s_slave = MMAP else
					  i_wb_sdram_stall when s_slave = SDRAM else '0';
	o_wb_ack <= i_wb_brom_ack when s_slave = BROM else
					i_wb_bram_ack when s_slave = BRAM else
					i_wb_mmap_ack when s_slave = MMAP else
					i_wb_sdram_ack when s_slave = SDRAM else '0';
	o_wb_data <= i_wb_brom_data when s_slave = BROM else
					 i_wb_bram_data when s_slave = BRAM else
					 i_wb_mmap_data when s_slave = MMAP else
					 i_wb_sdram_data when s_slave = SDRAM else (others => '0');
	
	-- BROM --
	o_wb_brom_cyc <= i_wb_cyc when s_slave = BROM else '0';
	o_wb_brom_stb <= i_wb_stb when s_slave = BROM else '0';
	o_wb_brom_we <= i_wb_we when s_slave = BROM else '0';
	o_wb_brom_addr <= i_wb_addr - ADDR_BROM_START when s_slave = BROM else (others => '0');
	o_wb_brom_data <= i_wb_data when s_slave = BROM else (others => '0');
	o_wb_brom_sel <= i_wb_sel when s_slave = BROM else (others => '0');
    
	-- BRAM --
	o_wb_bram_cyc <= i_wb_cyc when s_slave = BRAM else '0';
	o_wb_bram_stb <= i_wb_stb when s_slave = BRAM else '0';
	o_wb_bram_we <= i_wb_we when s_slave = BRAM else '0';
	o_wb_bram_addr <= i_wb_addr - ADDR_BRAM_START when s_slave = BRAM else (others => '0');
	o_wb_bram_data <= i_wb_data when s_slave = BRAM else (others => '0');
	o_wb_bram_sel <= i_wb_sel when s_slave = BRAM else (others => '0');

	-- MMAP peripherals --
	o_wb_mmap_cyc <= i_wb_cyc when s_slave = MMAP else '0';
	o_wb_mmap_stb <= i_wb_stb when s_slave = MMAP else '0';
	o_wb_mmap_we <= i_wb_we when s_slave = MMAP else '0';
	o_wb_mmap_addr <= i_wb_addr - ADDR_MMAP_START when s_slave = MMAP else (others => '0');
	o_wb_mmap_data <= i_wb_data when s_slave = MMAP else (others => '0');
	o_wb_mmap_sel <= i_wb_sel when s_slave = MMAP else (others => '0');

	-- SDRAM --
	o_wb_sdram_cyc <= i_wb_cyc when s_slave = SDRAM else '0';
	o_wb_sdram_stb <= i_wb_stb when s_slave = SDRAM else '0';
	o_wb_sdram_we <= i_wb_we when s_slave = SDRAM else '0';
	o_wb_sdram_addr <= i_wb_addr(20 downto 0) - ADDR_SDRAM_START when s_slave = SDRAM else (others => '0');
	o_wb_sdram_data <= i_wb_data when s_slave = SDRAM else (others => '0');
	o_wb_sdram_sel <= i_wb_sel when s_slave = SDRAM else (others => '0');

end architecture;
