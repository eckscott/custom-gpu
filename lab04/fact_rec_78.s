#########################################################################
#
# Filename: fact_rec_78.s
# 
# Author: Ethan Scott
#
# Description: Main function for fact_rec.s that calculates the factorial
#   of 7 and the factorial of 8 and adds them together+
#
# Functions:
#  - fact_rec: Performs factorial for input a0 (a0!) and returns result to a0
#
#########################################################################


.globl  main

# Constant defines for system calls
.eqv PRINT_INT 1        
.eqv PRINT_STR 4               
.eqv EXIT_CODE 93      


# Global data segment
.data
output:				# The location for the output calculated factorial
					# value given the input value data
	.word 0			# Allocates 4 bytes and sets the output to 0 for initialization
	
result_str:					# The location for the result string data
	.asciz "!7 + !8 = "		# allocates 1 byte per character plus null character

eol_str:			# End of line
	.asciz "\n"             

.text
main:				# Label for start of program

	# Call the fact_rec function to compute the factorial of 7
	li a0,7			# Loads 7 to compute the factorial
	jal fact_rec	# Jump and link (save return address) to factorial subroutine (function), argument (a0 (input)) return value 
	la t0,output	# Load output address to t0
	sw a0,0(t0)		# Save the calculated factorial result to output memory location

	# Call the fact_rec function to compute the factorial of 8
	li a0,8			# Loads 8 to compute the factorial
	jal fact_rec	# Jump and link (save return address) to factorial subroutine (function), argument (a0 (input)) return value 

	# Add those two factorials together and store the result
	lw t1, output	# Load !7 from memory
	add a0, a0, t1  # Add !7 and !8 and store in a0
	la t0, output	# Load output address to t0
	sw a0,0(t0)		# Save the calculated factorial result to output memory

	la a0,result_str	# Put result_str address in a0 to be printed
	li a7,PRINT_STR		# System call code for print_str code 4
	ecall				# Make system call
 
	lw a0,output		# Load output value into a0 to be printed
	li a7,PRINT_INT		# System call code for print_int code 1
	ecall				# Make system call

	la a0,eol_str		# Put end of line
	li a7, PRINT_STR	# System call code for print_str code 4
	ecall				# Make system call (i.e., print string)
	
	li a0,0			# Exit (93) with code 0
	li a7,EXIT_CODE	# System call value
	ecall			# Make system call
	ebreak			# Finish with breakpoint

# The fact_rec subrouting is defined in the file 'fact_rec.s'
