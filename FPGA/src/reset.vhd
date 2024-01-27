library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

entity Reset_handler is
	port (
		i_clk : in std_logic;
		i_nrst : in std_logic;
		i_serial_ndtr : in std_logic;
		i_serial_nrts : in std_logic;
		o_rst_proc : out std_logic;
		o_rst_rom : out std_logic;
		o_rst_ram : out std_logic
	);
end Reset_handler;

architecture Behavioral of Reset_handler is
	
	signal s_rst_proc : std_logic;
	
begin

	o_rst_rom <= '0';
	o_rst_ram <= '0';
	
	s_rst_proc <= not i_nrst;
	o_rst_proc <=  s_rst_proc;

end Behavioral;