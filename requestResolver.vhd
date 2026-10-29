library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Pure combinational logic (no registers).

entity request_resolver is
    generic (N_FLOORS : positive := 10);  
    port (
        pending : in  std_logic_vector(N_FLOORS-1 downto 0);--depends on generic floor numbers
        floor   : in  std_logic_vector(3 downto 0);  --integer or logic vector is better?IDK same -- current floor
        here    : out std_logic;
        above   : out std_logic;
        below   : out std_logic
    );
end entity;

architecture rtl of request_resolver is
begin
    process(pending, floor) --combinational process :D --don't forget to cover all inputs
    begin
        here  <= '0';
        above <= '0';
        below <= '0';
        for i in 0 to N_FLOORS - 1 loop
            if pending(i) = '1' then
                if    i = to_integer(unsigned(floor)) then here  <= '1';
                elsif i > to_integer(unsigned(floor)) then above <= '1';
                else             below <= '1';
                end if;
            end if;
        end loop;
    end process;
end architecture;