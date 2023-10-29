library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

entity R_REG is
	port(
		i_address: in std_logic_vector(31 downto 0);
		o_rom_data: out std_logic_vector(31 downto 0)
	);
end entity;


architecture rtl of R_REG is
	
begin

	o_rom_data <= x"FEEDBEEF" when i_address = x"10001000" else
					  x"BABADEDA" when i_address = x"10001001" else
					  x"DEADBEEF" when i_address = x"10001002" else  
					  x"DEDABABA" when i_address = x"10001003" else 
					 (others => '0');

end architecture;