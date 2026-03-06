################################
# Simulation
################################

assemble_pipeline:
	java -jar ../resources/rars1_6.jar pipeline_nop.s mc CompactDataAtZero a dump .text HexText pipeline_nop_text.mem a dump .text SegmentWindow pipeline_nop_text_debug.txt
	java -jar ../resources/rars1_6.jar pipeline_nop.s mc CompactDataAtZero a dump .data HexText pipeline_nop_data.mem a dump .text SegmentWindow pipeline_nop_data_debug.txt

analyze_pipeline: assemble_pipeline ../include/riscv_memory.sv riscv_basic_pipeline.sv ../include/tb_riscv_pkg.sv tb_riscv_pipeline.sv ../lab02/alu.sv ../lab03/regfile.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_tb_pipeline: analyze_pipeline
	xelab tb_riscv_pipeline -debug typical -nolog -timescale 1ns/100ps

sim_riscv_pipeline: elab_tb_pipeline
	xsim tb_riscv_pipeline --log sim_riscv_pipeline.log --runall

assemble_bounds: bounds_nop.s
	java -jar ../resources/rars1_6.jar bounds_nop.s mc CompactDataAtZero a dump .text HexText bounds_nop_text.mem
	java -jar ../resources/rars1_6.jar ../lab06/bounds_data.s mc CompactDataAtZero a dump .data HexText bounds_nop_data.mem

analyze_bounds: assemble_bounds ../include/riscv_memory.sv riscv_basic_pipeline.sv ../include/tb_riscv_pkg.sv tb_riscv_pipeline.sv ../lab02/alu.sv ../lab03/regfile.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_tb_bounds: analyze_bounds
	xelab tb_riscv_pipeline -debug typical -nolog -timescale 1ns/100ps -generic "TEXT_MEM=bounds_nop_text.mem" -generic "DATA_MEM=bounds_nop_data.mem" -s tb_pipeline_bounds

sim_bounds_nop: elab_tb_bounds
	xsim tb_pipeline_bounds --log sim_bounds_nop.log --runall

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
