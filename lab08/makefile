################################
# Simulation
################################

assemble_pipeline:
	java -jar ../resources/rars1_6.jar pipeline_nop.s mc CompactDataAtZero a dump .text HexText pipeline_nop_text.mem a dump .text SegmentWindow pipeline_nop_text_debug.txt
	java -jar ../resources/rars1_6.jar pipeline_nop.s mc CompactDataAtZero a dump .data HexText pipeline_nop_data.mem a dump .text SegmentWindow pipeline_nop_data_debug.txt

analyze_pipeline: assemble_pipeline ../include/riscv_memory.sv riscv_basic_pipeline.sv ../include/tb_riscv_pkg.sv tb_riscv_pipeline.sv ../lab02/alu.sv ../lab03/regfile.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_tb_pipeline: analyze_pipeline
	xelab tb_riscv_pipeline -debug typical -nolog -timescale 1ns/100ps -generic "instruction_memory_filename=pipeline_nop_text.mem" -generic "data_memory_filename=pipelin_nop_data.mem" -s tb_riscv_pipeline

sim_tb_multicycle_bounds: elab_tb_pipeline
	xsim tb_riscv_pipeline --log sim_riscv_pipeline.log --runall