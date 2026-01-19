#!/usr/bin/python3

# Manages file paths
import pathlib
import sys

sys.dont_write_bytecode = True # Prevent the bytecodes for the resources directory from being cached
# Add to the system path the "resources" directory relative to the script that was run
resources_path = pathlib.Path(__file__).resolve().parent.parent  / 'resources'
sys.path.append( str(resources_path) )

import repo_test_suite
import repo_test

def main():
    tester = repo_test_suite.build_test_suite("lab03", start_date="01/18/2026",
        max_repo_files = 30)
    tester.add_required_repo_files(["regfile.sv", "regfile_sim.tcl",  "regfile_top.sv",
                                    ])
    sim_test = tester.add_makefile_test("sim_tb_regfile", ["regfile.sv"], ["sim_tb_regfile.log"])
    sim_test.add_test(repo_test.file_regex_check(tester, "sim_tb_regfile.log", "===== TEST PASSED =====",
        "tb_regfile testbench check", error_on_match = False,
        error_msg = "tb_regfile testbench failed"))
    sim_test = tester.add_makefile_test("sim_tb_regfile_top", ["regfile_top.sv"], ["sim_tb_regfile_top.log"])
    sim_test.add_test(repo_test.file_regex_check(tester, "sim_tb_regfile_top.log", "===== TEST PASSED =====",
        "tb_regfile_top testbench check", error_on_match = False,
        error_msg = "tb_regfile_top testbench failed"))
    tester.add_makefile_test("regfile_top_synth.dcp", ["regfile_top.sv"], ["regfile_top_synth.log"])
    tester.add_makefile_test("regfile_top.bit", ["regfile_top_synth.dcp"],
                             ["regfile_top.bit", "regfile_top_imp.log",
                             "regfile_top_timing.rpt", "regfile_top_utilization.rpt"])
    tester.run_main()

if __name__ == "__main__":
    main()

