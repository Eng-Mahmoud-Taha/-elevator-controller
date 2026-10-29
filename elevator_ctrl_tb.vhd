library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Self-checking testbench for elevator_ctrl.
-- CLK_FREQ is set to 10, so "1 second" is only 10 clock cycles.
-- Errors are printed in the ModelSim transcript. No error message = PASSED.

entity elevator_ctrl_tb is
end entity;

architecture sim of elevator_ctrl_tb is
    constant CLK_FREQ   : positive := 10;
    constant CLK_PERIOD : time     := 10 ns;
    constant TWO_SEC    : time     := 2 * CLK_FREQ * CLK_PERIOD;   -- 200 ns

    signal clk       : std_logic := '0';
    signal reset_n   : std_logic := '0';
    signal sw        : std_logic_vector(3 downto 0) := "0000";
    signal enter_n   : std_logic := '1';
    signal mv_up     : std_logic;
    signal mv_dn     : std_logic;
    signal door_open : std_logic;
    signal floor     : std_logic_vector(3 downto 0);

    signal moving    : std_logic;
    signal sim_done  : boolean := false;

    -- text for the printed log
    function state_text(u, d, o : std_logic) return string is
    begin
        if    u = '1' then return "MOVING UP";
        elsif d = '1' then return "MOVING DOWN";
        elsif o = '1' then return "DOOR OPEN";
        else               return "IDLE, door closed";
        end if;
    end function;
begin
    ---------------------------------------------------------------------
    -- Device under test
    ---------------------------------------------------------------------
    dut : entity work.elevator_ctrl
        generic map (CLK_FREQ => CLK_FREQ)
        port map (
            clk       => clk,
            reset_n   => reset_n,
            sw        => sw,
            enter_n   => enter_n,
            mv_up     => mv_up,
            mv_dn     => mv_dn,
            door_open => door_open,
            floor_out => floor
        );

    -- Clock (stops when the test is finished)
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process;

    moving <= mv_up or mv_dn;

    -- prints a line every time the floor or the state changes
    log : process(floor, mv_up, mv_dn, door_open)
    begin
        if reset_n = '1' then
            report "[" & time'image(now) & "] floor = "
                   & integer'image(to_integer(unsigned(floor)))
                   & " | " & state_text(mv_up, mv_dn, door_open);
        end if;
    end process;

    ---------------------------------------------------------------------
    -- Checkers (always running)
    ---------------------------------------------------------------------
    -- 1) never up and down together, never door open while moving
    assert not (mv_up = '1' and mv_dn = '1')
        report "mv_up and mv_dn are both on" severity error;
    assert not (door_open = '1' and moving = '1')
        report "door is open while the elevator is moving" severity error;

    -- 2) the floor only changes by 1, in the direction of the move
    floor_check : process(clk)
        variable fl_prev : integer   := 0;
        variable fl_now  : integer;
        variable up_prev : std_logic := '0';
        variable dn_prev : std_logic := '0';
    begin
        if rising_edge(clk) then
            fl_now := to_integer(unsigned(floor));
            if reset_n = '1' and fl_now /= fl_prev then
                assert (fl_now = fl_prev + 1 and up_prev = '1') or
                       (fl_now = fl_prev - 1 and dn_prev = '1')
                    report "Floor changed in a wrong way: "
                           & integer'image(fl_prev) & " -> " & integer'image(fl_now)
                    severity error;
            end if;
            fl_prev := fl_now;
            up_prev := mv_up;
            dn_prev := mv_dn;
        end if;
    end process;

    -- 3) every move takes about 2 seconds
    move_check : process(moving)
        variable t0 : time := 0 ns;
    begin
        if moving = '1' then
            t0 := now;
        elsif moving = '0' and reset_n = '1' and t0 > 0 ns then
            assert now - t0 >= TWO_SEC and now - t0 <= TWO_SEC + 5 * CLK_PERIOD
                report "A move did not take about 2 seconds" severity error;
        end if;
    end process;

    -- 4) the door stays open at least 2 seconds
    door_check : process(door_open)
        variable t0 : time := 0 ns;
    begin
        if door_open = '1' then
            t0 := now;
        elsif door_open = '0' and reset_n = '1' and t0 > 0 ns then
            assert now - t0 >= TWO_SEC and now - t0 <= TWO_SEC + 5 * CLK_PERIOD
                report "The door was not open for about 2 seconds" severity error;
        end if;
    end process;

    ---------------------------------------------------------------------
    -- Stimulus
    ---------------------------------------------------------------------
    stim : process
        -- set the switches, then press enter for 3 clocks
        procedure press(f : natural) is
        begin
            sw <= std_logic_vector(to_unsigned(f, 4));
            wait until falling_edge(clk);
            enter_n <= '0';
            wait for 3 * CLK_PERIOD;
            enter_n <= '1';
            wait for CLK_PERIOD;
        end procedure;

        -- wait for the door to open, check the floor, wait for it to close
        procedure wait_door(f : natural; name : string) is
        begin
            if door_open /= '1' then      -- it may already be open
                wait until door_open = '1' for 5 us;
            end if;
            assert door_open = '1'
                report name & ": timeout, the door never opened" severity failure;
            if to_integer(unsigned(floor)) = f then
                report name & ": OK, door opened at floor " & integer'image(f);
            else
                report name & ": door opened at floor "
                       & integer'image(to_integer(unsigned(floor)))
                       & " instead of " & integer'image(f)
                    severity error;
            end if;
            wait until door_open = '0' for 1 us;
        end procedure;

        procedure check_idle(name : string) is
        begin
            assert mv_up = '0' and mv_dn = '0' and door_open = '0'
                report name & ": outputs should be all off" severity error;
        end procedure;
    begin
        -- reset
        reset_n <= '0';
        wait for 3 * CLK_PERIOD;
        reset_n <= '1';
        wait for 2 * CLK_PERIOD;
        assert floor = "0000" report "After reset the floor should be 0" severity error;
        check_idle("Reset");

        report "T1: one request, floor 0 -> 2";
        press(2);
        wait_door(2, "T1");

        report "T2: request at the current floor (2)";
        press(2);
        wait_door(2, "T2");

        report "T3: request below, floor 2 -> 0";
        press(0);
        wait_door(0, "T3");

        report "T4: several requests going up (5, 3, 1): stops at 1, 3, 5";
        press(5);
        press(3);
        press(1);
        wait_door(1, "T4a");
        wait_door(3, "T4b");
        wait_door(5, "T4c");

        report "T5: direction rule: at 5 going up, request 7 then 2: 7 first, then 2";
        press(7);
        press(2);
        wait_door(7, "T5-a");
        wait_door(2, "T5-b");

        report "T5b: direction rule: 1 pressed BEFORE 7, but going up: 7 is served first";
        press(4);
        press(1);
        press(7);
        wait_door(4, "T5b-a");
        wait_door(7, "T5b-b");
        wait_door(1, "T5b-c");

        report "T6: invalid floors (12 and 15) are ignored";
        press(12);
        press(15);
        wait for 100 * CLK_PERIOD;
        check_idle("T6");

        report "T7: reset in the middle of a move";
        press(9);
        if mv_up /= '1' then          -- it may already be moving
            wait until mv_up = '1' for 1 us;
        end if;
        wait for 5 * CLK_PERIOD;
        reset_n <= '0';
        wait for 3 * CLK_PERIOD;
        reset_n <= '1';
        wait for 100 * CLK_PERIOD;
        assert floor = "0000" report "T7: floor should be 0 after reset" severity error;
        check_idle("T7");

        report "ALL TESTS DONE. If no error message appeared above, the design PASSED.";
        sim_done <= true;
        wait;
    end process;
end architecture;