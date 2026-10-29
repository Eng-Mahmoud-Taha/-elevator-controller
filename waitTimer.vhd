library ieee;
use ieee.std_logic_1164.all;


--Timer Click Enable and Timer Based on it :)
entity wait_timer is
    generic (CLK_FREQ : positive := 50_000_000);
    port (
        clk     : in  std_logic;
        reset_n : in  std_logic;
        hold    : in  std_logic;
        done    : out std_logic
    );
end entity;

architecture rtl of wait_timer is
    signal cnt     : natural range 0 to CLK_FREQ - 1;   -- counts clock cycles
    signal tick_1s : std_logic;                         -- 1 second clock enable
    signal sec     : std_logic;                         -- '1' = first second passed
begin
    -- part 1: 1 second clock enable
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            cnt     <= 0;
            tick_1s <= '0';
        elsif rising_edge(clk) then
            tick_1s <= '0';
            if hold = '1' then
                cnt <= 0;
            elsif cnt = CLK_FREQ - 1 then
                cnt     <= 0;
                tick_1s <= '1';
            else
                cnt <= cnt + 1;
            end if;
        end if;
    end process;

    -- part 2: 2 second timer, moves only when the enable is on
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            sec  <= '0';
            done <= '0';
        elsif rising_edge(clk) then
            done <= '0';
            if hold = '1' then
                sec <= '0';
            elsif tick_1s = '1' then
                if sec = '1' then          -- 2nd tick: 2 seconds passed sec=max-1
                    sec  <= '0';
                    done <= '1';
                else
                    sec <= '1';             --sec+=1
                end if;
            end if;
        end if;
    end process;
end architecture;