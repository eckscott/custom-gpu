include multicycle_iosystem.mk
include ../resources/iosystem/iosystem.mk

####################################################
# Simulation Rules
####################################################

elab_buttoncount: analyze_multicycle_iosystem buttoncount_text.mem
	xelab multicycle_iosystem -s multicycle_iosystem --nolog  \
		-debug typical -timescale 1ns/100ps \
		-generic "TEXT_MEM=buttoncount_text.mem" \
		-generic "USE_DEBOUNCER=0" \
		-L unisims_ver glbl \

# Simulation of top-level design without testbench using the template tcl file
sim_buttoncount: elab_buttoncount
	xsim multicycle_iosystem --nolog -tclbatch buttoncount.tcl

################################
# Implementation
################################

multicycle_buttoncount.bit: multicycle_iosystem.sv buttoncount_text.mem
	vivado -mode batch -source implement_multicycle_buttoncount.tcl -log multicycle_buttoncount.log

################################
# Clean
################################

clean: clean_iosystem
	rm -rf xsim.dir .Xil tb_multicycle.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_tb_multicycle*.log *.wdb
	rm -f sim_tb_multicycle_bounds*.log
	rm -f riscv_multicycle_synth.dcp riscv_multicycle_synth*.log
	rm -f *.bit *.dcp *.rpt
	rm -f *.log, *.mem, *.txt
