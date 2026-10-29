library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- The FSM  Every state returns to IDLE  and IDLE makes all the decisions.
--   IDLE      : door closed  looks at here/above/below and decides
--   MOVE_UP   : going up one floor until done (2 s)
--   MOVE_DN   : going down one floor until done (2 s)
--   DOOR_OPENED : door open  until done (2 s)

entity unit_control is
    generic (N_FLOORS : positive := 10); 
    port (
        clk       : in  std_logic;
        reset_n   : in  std_logic;
        done      : in  std_logic;                      -- from timer 2 s passed
        here      : in  std_logic;                      -- from request_resolver 
        above     : in  std_logic;
        below     : in  std_logic;

        floor     : out std_logic_vector(3 downto 0);   --current floor (logic vector or number is better or hex is needed??)
        mv_up     : out std_logic;
        mv_dn     : out std_logic;
        door_open : out std_logic;

        clear     : out std_logic;                      -- clears pending bit of this floor
        hold      : out std_logic                       -- keeps wait_timer reset
    );
end entity;

architecture rtl of unit_control is
    type state_t is (IDLE, MOVE_UP, MOVE_DN, DOOR_OPENED);

    signal state,     next_state : state_t;
    signal floor_reg, next_floor : natural range 0 to N_FLOORS - 1; --number of floor generic
    signal dir_up,    next_dir   : std_logic;  -- '1' = last direction was up
begin
    
    -- Process 1: registers only (any signal on the left assignment is flipflop on a clock signal)
    
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            state     <= IDLE;
            floor_reg <= 0;
            dir_up    <= '1';
        elsif rising_edge(clk) then
            state     <= next_state;
            floor_reg <= next_floor;
            dir_up    <= next_dir;
        end if;
    end process;

    -- Process 2: Combinational one :D
    -- Don't Forget to cover all outputs :D
    --any signal u read from or scan or in when-if should be in sensitivity list :D
    process(state, floor_reg, dir_up, done, here, above, below) --all input signals should be included
    begin
        -- defaults
        next_state <= state;
        next_floor <= floor_reg;
        next_dir   <= dir_up;
        mv_up      <= '0'; --outputs
        mv_dn      <= '0'; --outputs
        door_open  <= '0'; --outputs
        clear      <= '0'; --outputs
        hold       <= '0'; --outputs
        floor      <= std_logic_vector(to_unsigned(floor_reg, 4)); --outputs

        case state is
            when IDLE =>
                hold <= '1';
                if here = '1' then
                    next_state <= DOOR_OPENED;
                elsif dir_up = '1' then           --here is zero   --going up: prefer above
                    if above = '1' then
                        next_state <= MOVE_UP;  next_dir <= '1'; --no need for this
                    elsif below = '1' then
                        next_state <= MOVE_DN;  next_dir <= '0';
                    end if;
                else                                  -- going down prefer below
                    if below = '1' then
                        next_state <= MOVE_DN;  next_dir <= '0'; --no need for this
                    elsif above = '1' then
                        next_state <= MOVE_UP;  next_dir <= '1';
                    end if;
                end if;

            when MOVE_UP =>
                mv_up <= '1';
                if done = '1' then
                    next_floor <= floor_reg + 1;
                    next_state <= IDLE;
                end if;

            when MOVE_DN =>
                mv_dn <= '1';
                if done = '1' then
                    next_floor <= floor_reg - 1;
                    next_state <= IDLE;
                end if;

            when DOOR_OPENED =>
                door_open <= '1';
                clear     <= '1';
                if done = '1' then
                    next_state <= IDLE;
                end if;
        end case;
    end process;
end architecture;