################################
# Simulation
################################

assemble_tb:
	java -jar ../resources/rars1_6.jar ../lab05/simple_datapath.s mc CompactDataAtZero a dump .text HexText simple_datapath_text.mem
	java -jar ../resources/rars1_6.jar ../lab05/simple_datapath.s mc CompactDataAtZero a dump .data HexText simple_datapath_data.mem

analyze_riscv_multicycle: assemble_tb ../include/riscv_memory.sv ../lab05/riscv_simple_datapath.sv ../include/tb_riscv_pkg.sv tb_multicycle.sv ../lab02/alu.sv ../lab03/regfile.sv riscv_multicycle.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_riscv_multicycle: analyze_riscv_multicycle
	xelab riscv_multicycle -debug typical -nolog -timescale 1ns/100ps

elab_tb_multicycle: analyze_riscv_multicycle
	xelab tb_multicycle -debug typical -nolog -timescale 1ns/100ps

sim_riscv_multicycle_gui: elab_riscv_multicycle
	xsim riscv_multicycle -gui --nolog

sim_tb_multicycle: elab_tb_multicycle
	xsim tb_multicycle --log sim_tb_multicycle.log --runall

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
