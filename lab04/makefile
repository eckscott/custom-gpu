################################
# Simulation
################################

fact_rec_78:
	java -jar ../resources/rars1_6.jar fact_rec_78.s fact_rec.s | tee fact_rec_78.out

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

analyze_regfile_top: regfile_top.sv regfile.sv ../include/synchronizer.sv ../include/oneshot.sv tb_regfile_top.sv ../lab02/alu.sv
	xvlog -i ../include $^ -sv --nolog

elab_regfile_top: analyze_regfile_top
	xelab regfile_top -debug typical -nolog

elab_tb_regfile_top: analyze_regfile_top
	xelab tb_regfile_top -debug typical -nolog

sim_regfile_top_gui: elab_regfile_top
	xsim regfile_top -gui --nolog

sim_tb_regfile_top: elab_tb_regfile_top
	xsim tb_regfile_top --log sim_tb_regfile_top.log --runall

################################
# Implementation
################################

regfile_top_synth.dcp: synth_regfile_top.tcl regfile_top.sv
	vivado -mode batch -script synth_regfile_top.tcl -nojournal -log regfile_top_synth.log

regfile_top.bit: regfile_top_synth.dcp
	vivado -mode batch -script imp_regfile_top.tcl -log regfile_top_imp.log

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