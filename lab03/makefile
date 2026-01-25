################################
# Simulation
################################

analyze_regfile: regfile.sv tb_regfile.sv
	xvlog -i ../include $^ -sv --nolog

elab_regfile: analyze_regfile
	xelab regfile -debug typical -nolog

elab_tb_regfile: analyze_regfile
	xelab tb_regfile -debug typical -nolog

sim_regfile_gui: elab_regfile
	xsim regfile -gui --nolog

sim_tb_regfile: elab_tb_regfile
	xsim tb_regfile --log sim_tb_regfile.log --runall

analyze_calc: calc.sv regfile.sv ../include/synchronizer.sv ../include/oneshot.sv tb_calc.sv
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
	rm -rf xsim.dir .Xil tb_regfile.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_tb_regfile*.log *.wdb
	rm -f regfile_synth.dcp synth_regfile*.log
	rm -f *.bit *.dcp *.rpt
	rm -f clockInfo.txt regfile_timing.rpt regfile_utilization.rpt regfile_imp*.log
	rm -f *.log