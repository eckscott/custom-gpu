################################
# Simulation
################################

analyze_alu: alu.sv tb_alu.sv
	xvlog -i ../include $^ -sv --nolog

elab_alu: analyze_alu
	xelab alu -debug typical -nolog

elab_tb_alu: analyze_alu
	xelab tb_alu -debug typical -nolog

sim_alu_gui: elab_alu
	xsim alu -gui --nolog

sim_tb_alu: elab_tb_alu
	xsim tb_alu --log sim_tb_alu.log --runall

analyze_calc: calc.sv alu.sv ../include/synchronizer.sv ../include/oneshot.sv
	xvlog -i ../include $^ -sv --nolog

elab_calc: analyze_calc
	xelab calc -debug typical -nolog

sim_calc_gui: elab_calc
	xsim calc -gui --nolog

################################
# Implementation
################################

alu_synth.dcp: synth_alu.tcl alu.sv
	vivado -mode batch -script synth_alu.tcl -nojournal -log synth_alu.log

alu.bit: alu_synth.dcp
	vivado -mode batch -script imp_alu.tcl -log alu_imp.log

################################
# Clean
################################

clean:
	rm -rf xsim.dir .Xil tb_alu.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_tb_alu*.log *.wdb
	rm -f alu_synth.dcp synth_alu*.log
	rm -f alu.bit alu.dcp
	rm -f clockInfo.txt alu_timing.rpt alu_utilization.rpt alu_imp*.log
	rm -f *.log