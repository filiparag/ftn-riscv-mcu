library ieee;
use ieee.std_logic_1164.ALL;
use ieee.std_logic_unsigned.ALL;

entity DBG_CNT is
  port (
    i_Clk       : in  std_logic;	
    i_Rstn 		 : in  std_logic;
    i_En			 : in  std_logic;

	 o_Debug_Cnt : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of DBG_CNT is

	signal s_cnt : std_logic_vector(7 downto 0);

begin

	process (i_Clk, i_Rstn) 
	begin
		if(i_Rstn = '0') then
			s_cnt <= (others => '0');
		elsif(rising_edge(i_Clk)) then
			if(i_En = '1') then
				s_cnt <= s_cnt + 1;
			end if;
		end if;
	end process;

	o_Debug_Cnt <= s_cnt;

end architecture;

