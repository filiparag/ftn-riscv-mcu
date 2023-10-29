library ieee;
use ieee.std_logic_1164.all;

entity RST_Reg is
  port (
    i_Clk       : in  std_logic;
    i_Rstn 		 : in  std_logic;
	 i_WE 		 : in  std_logic;
	 i_Address	 : in  std_logic_vector(31 downto 0);
	 i_Data		 : in  std_logic_vector(31 downto 0);
	 o_Data		 : out std_logic
    );
end entity;

architecture rtl of RST_Reg is
	
	signal s_data : std_logic;
	
begin 

	reg : process(i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_data <= '1';
		elsif(rising_edge(i_Clk)) then
			if(i_WE = '1') then
				if(i_Address = x"11000000") then
					s_data <= i_Data(0);
				else
					s_data <= s_data;
				end if;
			end if;
		end if;
	end process;

	o_Data <= s_data;
	
end architecture;