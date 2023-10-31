library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_TEXTIO.ALL;
use STD.TEXTIO.ALL;

entity wb_ram is
  generic(
	 ROW_COUNT: positive := 256;  -- Determines the size of the RAM
	 G_INIT_FILE: string := ""
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

	type MEM_BANK is array (0 to ROW_COUNT-1) of std_logic_vector(7 downto 0);
	 
	function init_from_file_or_zeroes(filename : string; bank_number : natural) return MEM_BANK is
        variable result : MEM_BANK := (others => (others => '0'));
        file file_handle : text;
        variable line : line;
        variable data : std_logic_vector(31 downto 0);
        variable file_opened : boolean := FALSE;
    begin
        file_open(file_handle, filename, read_mode);
        file_opened := TRUE;
        for i in result'range loop
            if endfile(file_handle) then
                report "Reached end of file before loading all memory for bank " & natural'image(bank_number) severity FAILURE;
                if file_opened then
                    file_close(file_handle);
                end if;
                return result;
            end if;
            readline(file_handle, line);
            read(line, data);
            result(i) := data((bank_number+1)*8-1 downto (bank_number*8));
        end loop;
        if file_opened then
            file_close(file_handle);
        end if;
        return result;
    end function;
    
    -- Define RAM banks
    signal s_mem_bank_3 : MEM_BANK := init_from_file_or_zeroes(G_INIT_FILE, 3);
	 signal s_mem_bank_2 : MEM_BANK := init_from_file_or_zeroes(G_INIT_FILE, 2);
	 signal s_mem_bank_1 : MEM_BANK := init_from_file_or_zeroes(G_INIT_FILE, 1);
	 signal s_mem_bank_0 : MEM_BANK := init_from_file_or_zeroes(G_INIT_FILE, 0);
  
begin

  process(i_rst, i_clk)
    variable v_addr : integer range 0 to ROW_COUNT-1;
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
--		if v_req = '1' and v_addr < ROW_COUNT then
			o_err <= '0';
			-- Bank 0
--			if i_sel(0) = '1' and i_we = '1' then
--				s_mem_bank_0(v_addr) <= i_data(7 downto 0);
--			end if;
			o_data(7 downto 0) <= s_mem_bank_0(v_addr);
			-- Bank 1
--			if i_sel(1) = '1' and i_we = '1' then
--				s_mem_bank_1(v_addr) <= i_data(15 downto 8);
--			end if;
			o_data(15 downto 8) <= s_mem_bank_1(v_addr);
			-- Bank 2
--			if i_sel(2) = '1' and i_we = '1' then
--				s_mem_bank_2(v_addr) <= i_data(23 downto 16);
--			end if;
			o_data(23 downto 16) <= s_mem_bank_2(v_addr);
			-- Bank 3
--			if i_sel(3) = '1' and i_we = '1' then
--				s_mem_bank_3(v_addr) <= i_data(31 downto 24);
--			end if;
			o_data(31 downto 24) <= s_mem_bank_3(v_addr);
--		else
--			-- Address out of range
--			o_data <= (others => '0');
--			o_err <= '1';
--		end if;
      -- Ack that we have dealt with the request.
      o_ack <= v_req;
    end if;
  end process;
  -- Note: STALL and RTY are always deasserted, as we respond in one clock cycle and there is
  -- no risk of any errors.
  o_stall <= '0';
  o_rty <= '0';
end rtl;
