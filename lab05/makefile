################################
# Simulation
################################

assemble_tb:
	java -jar ../resources/rars1_6.jar simple_datapath.s mc CompactDataAtZero a dump .text HexText simple_datapath_text.mem
	java -jar ../resources/rars1_6.jar simple_datapath.s mc CompactDataAtZero a dump .data HexText simple_datapath_data.mem

analyze_riscv_simple_datapath: assemble_tb riscv_simple_datapath.sv ../include/tb_riscv_pkg.sv tb_simple_datapath.sv ../lab02/alu.sv ../lab03/regfile.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_riscv_simple_datapath: analyze_riscv_simple_datapath
	xelab riscv_simple_datapath -debug typical -nolog -timescale 1ns/100ps

elab_tb_simple_datapath: analyze_riscv_simple_datapath
	xelab tb_simple_datapath -debug typical -nolog -timescale 1ns/100ps

sim_riscv_simple_datapath_gui: elab_riscv_simple_datapath
	xsim riscv_simple_datapath -gui --nolog

sim_tb_simple_datapath: elab_tb_simple_datapath
	xsim tb_simple_datapath --log sim_tb_simple_datapath.log --runall

################################
# Implementation
################################

riscv_simple_datapath_synth.dcp: synth_riscv_simple_datapath.tcl riscv_simple_datapath.sv
	vivado -mode batch -script synth_riscv_simple_datapath.tcl -nojournal -log riscv_simple_datapath_synth.log

################################
# Clean
################################

clean:
	rm -rf xsim.dir .Xil tb_simple_datapath.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_tb_simple_datapath*.log *.wdb
	rm -f riscv_simple_datapath_synth.dcp riscv_simple_datapath_synth*.log
	rm -f *.bit *.dcp *.rpt
	rm -f *.log, *.mem