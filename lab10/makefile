include forwarding_iosystem.mk
include ../resources/iosystem/iosystem.mk

####################################################
# Simulation Rules
####################################################



# Create a bitstream for the move_char test program by loading the appropriate memory files into the design checkpoint
forwarding_move_char.bit: forwarding_iosystem.bit move_char_text.mem move_char_data.mem
	vivado -mode batch -source ../resources/load_mem.tcl -log forwarding_move_char.log \
		-tclargs updateMem forwarding_iosystem.dcp \
		move_char_text.mem move_char_data.mem forwarding_move_char.bit 

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
	rm -f *.backup.log
	rm -f sim_tb_multicycle_bounds*.log
	rm -f riscv_multicycle_synth.dcp riscv_multicycle_synth*.log
	rm -f *.bit *.dcp *.rpt
	rm -f *.log *.mem *.txt
	rm -f buttoncount_text.mem
	rm -f xelab.log
	rm -f multicycle_buttoncount.log
	rm -f *.wdb
