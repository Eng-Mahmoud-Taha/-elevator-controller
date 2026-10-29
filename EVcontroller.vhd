library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Top level of the elevator controller.
-- Contains the pending register the notepad and connects: request_resolver, unit_control, wait_timer

entity elevator_ctrl is
    generic (CLK_FREQ : positive := 50_000_000;
            N_FLOORS : positive := 10
            );
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        sw        : in  std_logic_vector(3 downto 0);   -- floor number 
        enter_n   : in  std_logic;                      -- enter button, active low
        mv_up     : out std_logic;
        mv_dn     : out std_logic;
        door_open : out std_logic;
        floor_out : out std_logic_vector(3 downto 0);    -- current floor
        hex0      : out std_logic_vector(6 downto 0)
        
    );
end entity;

architecture rtl of elevator_ctrl is
    signal pending : std_logic_vector(N_FLOORS - 1  downto 0);   -- the notepad

    signal floor_s : std_logic_vector(3 downto 0); -- current floor output from CU input to request and to outputport

    signal here    : std_logic;--output
    signal above   : std_logic;
    signal below   : std_logic;

    signal done    : std_logic;--output from timer input to  unit control

    signal hold    : std_logic;--output from unit control input to timer
    signal clear   : std_logic;--output from unit control input to requestresolver
begin
    --i was thinking of making component called memory so i can put on it notepad and my floor reg:) so cu will only send command to inc + or dec - only
    -- The notepad: check a box on enter, delete it when the door opens
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            pending <= (others => '0');
        elsif rising_edge(clk) then
            if clear = '1' then
                pending(to_integer(unsigned(floor_s))) <= '0';
            end if;

            -- enter button is down and the switches show a valid floor
            if enter_n = '0' and unsigned(sw) < N_FLOORS then
                pending(to_integer(unsigned(sw))) <= '1';
            end if;
        end if;
    end process;

    u_resolver : entity work.request_resolver
        generic map (N_FLOORS => N_FLOORS)
        port map (
            pending => pending,
            floor   => floor_s,
            here    => here,
            above   => above,
            below   => below
        );

    u_timer : entity work.wait_timer
        generic map (CLK_FREQ => CLK_FREQ)
        port map (
            clk     => clk,
            reset_n => reset_n,
            hold    => hold,
            done    => done
        );
        
    u_fsm : entity work.unit_control
        generic map (N_FLOORS => N_FLOORS)
        port map (
            clk       => clk,
            reset_n   => reset_n,
            done      => done,
            here      => here,
            above     => above,
            below     => below,
            floor     => floor_s,
            mv_up     => mv_up,
            mv_dn     => mv_dn,
            door_open => door_open,
            clear     => clear,
            hold      => hold
        );
        u_ssd : entity work.ssd
        port map (
            bin_in  => floor_s,
            seg_out => hex0
        );

    floor_out <= floor_s;
end architecture;