################################
# Simulation
################################

assemble_final:
	java -jar ../resources/rars1_6.jar final.s mc CompactDataAtZero a dump .text HexText final_text.mem a dump .text SegmentWindow final_text_debug.txt
	java -jar ../resources/rars1_6.jar final.s mc CompactDataAtZero a dump .data HexText final_data.mem a dump .text SegmentWindow final_data_debug.txt

analyze_final: assemble_final ../include/riscv_memory.sv riscv_final.sv ../include/tb_riscv_pkg.sv tb_riscv_final.sv ../lab02/alu.sv ../lab03/regfile.sv
	xvlog -i ../include $(wordlist 2,$(words $^),$^) -sv --nolog

elab_tb_final: analyze_final
	xelab tb_riscv_final -debug typical -nolog -timescale 1ns/100ps

sim_riscv_final: elab_tb_final
	xsim tb_riscv_final --log sim_riscv_final.log --runall

sim_riscv_final_gui: elab_tb_final
	xsim tb_riscv_final --log sim_riscv_final.log -gui


################################
# Implementation
################################

riscv_final.dcp: synth_riscv_final.tcl riscv_final.sv
	vivado -mode batch -script synth_riscv_final.tcl -nojournal -log riscv_final.log

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
