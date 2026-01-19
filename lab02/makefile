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

analyze_calc: calc.sv alu.sv ../include/synchronizer.sv ../include/oneshot.sv tb_calc.sv
	xvlog -i ../include $^ -sv --nolog

elab_calc: analyze_calc
	xelab calc -debug typical -nolog

elab_tb_calc: analyze_calc
	xelab tb_calc -debug typical -nolog

sim_calc_gui: elab_calc
	xsim calc -gui --nolog

sim_tb_calc: elab_tb_calc
	xsim tb_calc --log sim_tb_calc.log --runall

################################
# Implementation
################################

calc_synth.dcp: synth_calc.tcl calc.sv
	vivado -mode batch -script synth_calc.tcl -nojournal -log calc_synth.log

calc.bit: calc_synth.dcp
	vivado -mode batch -script imp_calc.tcl -log calc_imp.log

################################
# Clean
################################

clean:
	rm -rf xsim.dir .Xil tb_alu.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_tb_alu*.log *.wdb
	rm -f alu_synth.dcp synth_alu*.log
	rm -f *.bit *.dcp *.rpt
	rm -f clockInfo.txt alu_timing.rpt alu_utilization.rpt alu_imp*.log
	rm -f *.log