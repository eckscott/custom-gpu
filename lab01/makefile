################################
# Simulation
################################

analyze_updownbuttoncount: updownbuttoncount.sv ../include/synchronizer.sv ../include/oneshot.sv updownbuttoncount_tb.sv
	xvlog $^ -sv --nolog

elab_updownbuttoncount: analyze_updownbuttoncount
	xelab updownbuttoncount -debug typical -nolog

elab_updownbuttoncount_tb: analyze_updownbuttoncount
	xelab updownbuttoncount_tb -debug typical -nolog

sim_updownbuttoncount_gui: elab_updownbuttoncount
	xsim updownbuttoncount -gui --nolog

sim_updownbuttoncount_tb: elab_updownbuttoncount_tb
	xsim updownbuttoncount_tb --log sim_updownbuttoncount_tb.log --runall

################################
# Implementation
################################

updownbuttoncount_synth.dcp: synth_updownbuttoncount.tcl updownbuttoncount.sv
	vivado -mode batch -script synth_updownbuttoncount.tcl -nojournal -log synth_updownbuttoncount.log

updownbuttoncount.bit: updownbuttoncount_synth.dcp
	vivado -mode batch -script imp_updownbuttoncount.tcl -log updownbuttoncount_imp.log

################################
# Clean
################################

clean:
	rm -rf xsim.dir .Xil updownbuttoncount_tb.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_updownbuttoncount_tb*.log *.wdb
	rm -f updownbuttoncount_synth.dcp updownbuttoncount_synth*.log
	rm -f updownbuttoncount.bit updownbuttoncount.dcp
	rm -f clockInfo.txt updownbuttoncount_timing.rpt updownbuttoncount_utilization.rpt updownbuttoncount_imp*.log
	rm -f vivado.log