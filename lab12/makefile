include final_iosystem.mk

################################
# Mileston 3 Rules
################################

custom_font.bit: riscv_io_final.dcp
	vivado -mode batch -source ../resources/load_mem.tcl \
		-tclargs updateFont riscv_io_final.dcp custom_font.txt custom_font.bit custom_font.dcp

custom_font.dcp: custom_font.bit

custom_background.mem: custom_background.txt
	python3 ../resources/generate_background.py $< $@

custom.bit: custom_font.dcp custom_background.mem
	vivado -mode batch -source ../resources/load_mem.tcl \
		-tclargs updateBackground custom_font.dcp custom_background.mem custom.bit custom.dcp

#################################
# Personal Project Rules
#################################

project_text.mem: project.s multiply.s
	java -jar ../resources/rars1_6.jar project.s multiply.s mc CompactTextAtZero \
    a dump .text HexText project_text.mem \
	a dump .data HexText project_data.mem a dump .text SegmentWindow project_text.txt

project.bit: riscv_io_final.sv project_text.mem
	vivado -mode batch -source implement_project.tcl -log project.log

project.dcp: project.bit

project_font.bit: project.dcp
	vivado -mode batch -source ../resources/load_mem.tcl \
		-tclargs updateFont project.dcp project_font.txt project_font.bit project_font.dcp

project_font.dcp: project_font.bit

project_background.mem: project_background.txt
	python3 ../resources/generate_background.py $< $@

project_background.bit: project_background.mem project_font.dcp
	vivado -mode batch -source ../resources/load_mem.tcl \
		-tclargs updateBackground project_font.dcp project_background.mem project_background.bit project_background.dcp

#################################
# Clean Rules
#################################

clean: clean_iosystem
	rm -f *.bit *.jou *.log *.rpt *.dcp *.pb *.wdb
	rm -f clockInfo.txt
	rm -rf .Xil xsim.dir
	rm -f project_text.txt
	rm -f project_text.mem
	rm -f project_data.txt
	rm -f project_data.mem