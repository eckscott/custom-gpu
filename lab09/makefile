################################
# Simulation
################################

assemble_forwarding:
	java -jar ../resources/rars1_6.jar forwarding.s mc CompactDataAtZero a dump .text HexText forwarding_text.mem a dump .text SegmentWindow forwarding_text_debug.txt
	java -jar ../resources/rars1_6.jar forwarding.s mc CompactDataAtZero a dump .data HexText forwarding_data.mem a dump .text SegmentWindow forwarding_data_debug.txt

analyze_forwarding: assemble_forwarding ../include/riscv_memory.sv riscv_forwarding_pipeline.sv ../include/tb_riscv_pkg.sv tb_riscv_forwarding.sv ../lab02/alu.sv ../lab03/regfile.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_tb_forwarding: analyze_forwarding
	xelab tb_riscv_forwarding -debug typical -nolog -timescale 1ns/100ps

sim_riscv_forwarding: elab_tb_forwarding
	xsim tb_riscv_forwarding --log sim_riscv_forwarding.log -gui

assemble_bounds: bounds_nop.s
	java -jar ../resources/rars1_6.jar bounds_nop.s mc CompactDataAtZero a dump .text HexText bounds_nop_text.mem
	java -jar ../resources/rars1_6.jar ../lab06/bounds_data.s mc CompactDataAtZero a dump .data HexText bounds_nop_data.mem

analyze_bounds: assemble_bounds ../include/riscv_memory.sv riscv_basic_pipeline.sv ../include/tb_riscv_pkg.sv tb_riscv_pipeline.sv ../lab02/alu.sv ../lab03/regfile.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_tb_bounds: analyze_bounds
	xelab tb_riscv_pipeline -debug typical -nolog -timescale 1ns/100ps -generic "TEXT_MEM=bounds_nop_text.mem" -generic "DATA_MEM=bounds_nop_data.mem" -s tb_pipeline_bounds

sim_bounds_nop: elab_tb_bounds
	xsim tb_pipeline_bounds --log sim_bounds_nop.log -gui

################################
# Implementation
################################

riscv_basic_pipeline.dcp: synth_riscv_basic_pipeline.tcl riscv_basic_pipeline.sv
	vivado -mode batch -script synth_riscv_basic_pipeline.tcl -nojournal -log riscv_basic_pipeline.log

################################
# Clean
################################

clean:
	rm -rf xsim.dir .Xil tb_riscv_pipeline.wdb xsim*.jou xelab.pb xvlog.log xvlog.pb vivado*.str vivado*.jou
	rm -f sim_tb_riscv_pipeline*.log *.wdb
	rm -f sim_tb_riscv_pipeline_bounds*.log
	rm -f riscv_riscv_pipeline_synth.dcp riscv_riscv_pipeline_synth*.log
	rm -f sim_riscv_pipeline.log
	rm -f *.bit *.dcp *.rpt
	rm -f *.log *.mem *.txt
