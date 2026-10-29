# ModelSim script for the elevator controller.
# Usage: in the ModelSim transcript, cd to the folder with the .vhd files, then:  do run_sim.do
#
# The script looks for your files by name pattern. If it cannot find one, it tells you.
proc find_file {patterns} {
    foreach p $patterns {
        set r [glob -nocomplain $p]
        if {[llength $r] > 0} { return [lindex $r 0] }
    }
    error "No file found for $patterns. Current folder: [pwd]. .vhd files here: [glob -nocomplain *.vhd]"
}
set RESOLVER [find_file {request_resolver.vhd *esolver*.vhd}]
set TIMER    [find_file {wait_timer.vhd *imer*.vhd}]
set FSM      [find_file {unit_control.vhd unitControl.vhd *nit*ontrol*.vhd}]
set TOP      [find_file {elevator_ctrl.vhd EVcontroller.vhd *ctrl.vhd *controller.vhd}]
set TB       [find_file {elevator_ctrl_tb.vhd *tb*.vhd}]
echo "Using: $RESOLVER $TIMER $FSM $TOP $TB"

# close any simulation that is still open
catch {quit -sim}

# fresh work library
catch {vdel -lib work -all}
vlib work
vmap work work

# compile: every file before the files that use it
vcom -93 $RESOLVER
vcom -93 $TIMER
vcom -93 $FSM
vcom -93 $TOP
vcom -93 $TB

# load the testbench (+acc keeps all signals visible)
vsim -voptargs=+acc work.elevator_ctrl_tb

# ---------------- waveform ----------------
delete wave *

add wave -divider "Inputs"
add wave -label clk                 /elevator_ctrl_tb/clk
add wave -label reset_n             /elevator_ctrl_tb/reset_n
add wave -label sw -radix unsigned  /elevator_ctrl_tb/sw
add wave -label enter_n             /elevator_ctrl_tb/enter_n

add wave -divider "Outputs"
add wave -label floor -radix unsigned /elevator_ctrl_tb/floor
add wave -label mv_up               /elevator_ctrl_tb/mv_up
add wave -label mv_dn               /elevator_ctrl_tb/mv_dn
add wave -label door_open           /elevator_ctrl_tb/door_open

add wave -divider "Inside the design"
add wave -label state               /elevator_ctrl_tb/dut/u_fsm/state
add wave -label pending -radix binary /elevator_ctrl_tb/dut/pending
add wave -label here                /elevator_ctrl_tb/dut/here
add wave -label above               /elevator_ctrl_tb/dut/above
add wave -label below               /elevator_ctrl_tb/dut/below
add wave -label hold                /elevator_ctrl_tb/dut/hold
add wave -label tick_1s             /elevator_ctrl_tb/dut/u_timer/tick_1s
add wave -label done                /elevator_ctrl_tb/dut/done
add wave -label clear               /elevator_ctrl_tb/dut/clear

configure wave -namecolwidth 150
configure wave -valuecolwidth 70

# run until the testbench finishes, then show everything
run -all
wave zoom full
