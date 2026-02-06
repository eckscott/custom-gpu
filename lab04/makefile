################################
# Simulation
################################

fact_rec_78:
	java -jar ../resources/rars1_6.jar fact_rec_78.s fact_rec.s | tee fact_rec_78.out

fib_iterative:
	java -jar ../resources/rars1_6.jar fib_main_multiple.s fib_iterative.s | tee fib_iterative.out

fib_recursive:
	java -jar ../resources/rars1_6.jar fib_main_multiple.s fib_recursive.s | tee fib_recursive.out

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
	rm -f *.out