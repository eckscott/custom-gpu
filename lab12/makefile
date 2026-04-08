include final_iosystem.mk

custom_font.bit: riscv_io_final.dcp
	vivado -mode batch -source ../resources/load_mem.tcl \
		-tclargs updateFont riscv_io_final.dcp custom_font.txt custom_font.bit custom_font.dcp

custom_font.dcp: custom_font.bit

custom_background.mem: custom_background.txt
	python3 ../resources/generate_background.py $< $@

custom.bit: custom_font.dcp custom_background.mem
	vivado -mode batch -source ../resources/load_mem.tcl \
		-tclargs updateBackground custom_font.dcp custom_background.mem custom.bit custom.dcp

clean: clean_iosystem
	rm -f *.bit *.jou *.log *.rpt *.dcp *.pb *.wdb *.mem
	rm -f clockInfo.txt
	rm -rf .Xil xsim.dir