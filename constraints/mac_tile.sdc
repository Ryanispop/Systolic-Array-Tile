# Initial integration assumptions, not measured board/system requirements.
# Time units: ns. Capacitance units for Sky130 HD: pF.
create_clock -name clk -period $::env(CLOCK_PERIOD) [get_ports clk]
set data_inputs [get_ports {rst in_valid out_ready in_a[*] in_b[*]}]
set data_outputs [all_outputs]

# External launch/capture budgets: max 20% of the clock, min 0.5 ns.
# Synchronous reset is timed like every other input (no false path).
set io_budget [expr {0.20 * $::env(CLOCK_PERIOD)}]
set_input_delay -clock clk -max $io_budget $data_inputs
set_input_delay -clock clk -min 0.5 $data_inputs
set_output_delay -clock clk -max $io_budget $data_outputs
set_output_delay -clock clk -min -0.5 $data_outputs
set_input_transition 0.2 $data_inputs
set_load 0.01 $data_outputs
set_clock_uncertainty 0.25 [get_clocks clk]
set_clock_transition 0.15 [get_clocks clk]
set_max_fanout $::env(MAX_FANOUT_CONSTRAINT) [current_design]

# LibreLane sets this flag for ideal-clock pre-PnR STA; routed STA uses CTS.
if {[info exists ::env(OPENLANE_SDC_IDEAL_CLOCKS)] && $::env(OPENLANE_SDC_IDEAL_CLOCKS)} {
    unset_propagated_clock [all_clocks]
} else {
    set_propagated_clock [all_clocks]
}
