library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;

entity wb_ram is
  generic(
    ADR_WIDTH : positive := 32;  -- Determines the size of the input port
	 REAL_RAM_DEPTH : positive := 32768;  -- Determines the size of the RAM (num. of words = 2**ADR_WIDTH)
	 G_INIT_FILE : string := ""
  );
  port(
    -- Wishbone SLAVE signals.
    i_rst : in std_logic;
    i_clk : in std_logic;
    i_addr : in std_logic_vector(31 downto 0);
    i_data : in std_logic_vector(31 downto 0);
    i_we : in std_logic;
    i_sel : in std_logic_vector(3 downto 0);
    i_cyc : in std_logic;
    i_stb : in std_logic;
    o_data : out std_logic_vector(31 downto 0);
    o_ack : out std_logic;
    o_stall : out std_logic;
    o_rty : out std_logic;
    o_err : out std_logic
  );
end wb_ram;

architecture rtl of wb_ram is

  type T_MEM is array (0 to REAL_RAM_DEPTH-1) of std_logic_vector(7 downto 0);
    
    -- The folowing code either initializes the memory values to a specified file or to all zeros to match hardware
    impure function initramfromfile (ramfilename : in string; bank : in integer) return T_MEM is
        file ramfile	: text; -- is in ramfilename;
        variable ramfileline : line;
        variable ram_name	: T_MEM;
        variable bitvec : bit_vector(31 downto 0);
    begin
        file_open(ramfile, ramfilename, read_mode);
        for i in T_MEM'range loop
            readline (ramfile, ramfileline);
            read (ramfileline, bitvec);
            ram_name(i) := to_stdlogicvector(bitvec)(8*(bank+1)-1 downto 8*bank);
        end loop;
        return ram_name;
    end function;
    
    impure function init_from_file_or_zeroes(ramfile : string; bank : in integer) return T_MEM is
    begin
        if ramfile /= "" then
            return InitRamFromFile(ramfile, bank) ;
        else
            return (others => (others => '0'));
        end if;
    end;
    
    -- Define RAM
    signal s_mem1 : T_MEM := init_from_file_or_zeroes(G_INIT_FILE, 3);
	 signal s_mem2 : T_MEM := init_from_file_or_zeroes(G_INIT_FILE, 2);
	 signal s_mem3 : T_MEM := init_from_file_or_zeroes(G_INIT_FILE, 1);
	 signal s_mem4 : T_MEM := init_from_file_or_zeroes(G_INIT_FILE, 0);
	 --signal s_mem : T_MEM := (others => (others => '0'));
  
begin
  process(i_rst, i_clk)
    variable v_addr : integer range 0 to REAL_RAM_DEPTH-1;
    variable v_req : std_logic;
  begin
    if i_rst = '1' then
      o_data <= (others => '0');
      o_ack <= '0';
    elsif rising_edge(i_clk) then
      -- Is this a valid request for this Wishbone slave?
      v_req := i_cyc and i_stb;

      -- Get the address.
      v_addr := to_integer(unsigned(i_addr));

      -- Write?
--      if v_req = '1' and i_we = '1' then
--        for k in 0 to C_PARTS_PER_WORD-1 loop
--          if i_sel(k) = '1' then
--            s_mem(k)(v_adr) <= i_dat(GRANULARITY*(k+1)-1 downto GRANULARITY*k);
--          end if;
--        end loop;
--      end if;
		

		if i_sel(0) = '1' then
			if v_req = '1' and i_we = '1' then
				s_mem1(v_addr) <= i_data(7 downto 0);
			end if;
			o_data(7 downto 0) <= s_mem1(v_addr);
		else
			o_data(7 downto 0) <= (others => '0');
		end if;
		
		if i_sel(1) = '1' then
			if v_req = '1' and i_we = '1' then
				s_mem2(v_addr) <= i_data(15 downto 8);
			end if;
			o_data(15 downto 8) <= s_mem2(v_addr);
		else
			o_data(15 downto 8) <= (others => '0');
		end if;
		
		if i_sel(2) = '1' then
			if v_req = '1' and i_we = '1' then
				s_mem3(v_addr) <= i_data(23 downto 16);
			end if;
			o_data(23 downto 16) <= s_mem3(v_addr);
		else
			o_data(23 downto 16) <= (others => '0');
		end if;
		
		if i_sel(3) = '1' then
			if v_req = '1' and i_we = '1' then
				s_mem4(v_addr) <= i_data(31 downto 24);
			end if;
			o_data(31 downto 24) <= s_mem4(v_addr);
		else
			o_data(31 downto 24) <= (others => '0');
		end if;
		
 

      -- Ack that we have dealt with the request.
      o_ack <= v_req;
    end if;
  end process;

  -- Note: STALL, RTY and ERR are always deasserted, as we respond in one clock cycle and there is
  -- no risk of any errors.
  o_stall <= '0';
  o_rty <= '0';
  o_err <= '0';
end rtl;
