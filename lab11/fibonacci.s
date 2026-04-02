#########################################################################
#
# Filename: fibonacci.s
# 
# Author: Ethan Scott
#
# Description: This script determines the fibonacci number for any input
#   through an iterative approach. First, it checks for the edge cases,
#   like if the input is 0, or 1, predefined fibonacci values, and if
#   it's not those then it enters an interative loop as described below
#
# Functions:
#  - iterative_fibonacci: This function computes the fibonacci number for
#    a given input using an iterative approach.
#  - recursive_fibonacci: This function computes the fibonacci number for
#    a given input using a recursive approach.
#########################################################################

# The function needs to be in the text segment
.text

# The function names so the main program can call them (fib_main.s)
.globl iterative_fibonacci
.globl recursive_fibonacci

iterative_fibonacci:		# Performs iterative fibonacci for input x10 (x10!) and returns result
                            # to x10

    addi x2, x2, -8   # Make room to save values on stack
    sw x8, 0(x2)     # Save caller s0 on stack
    sw x1, 4(x2)     # Save return address on stack

    add x8, x10, x0    # Move input to s0 for manipulation

    beq x8, x0, $L2      # If input is 0, return 0
    addi x28, x0, 1     # Set temp reg to 1 for comparison
    beq x8, x28, $L3    # If fib(1) jump to case L3

    addi x5, x0, 0     # Initialize fib_2 = 0
    addi x6, x0, 1     # Initialize fib_1 = 1
    addi x7, x0, 0     # Initialize fib = 0

    addi x29, x0, 1    # Initialize i = 1
loop:
    bge x29, x8, $L4   # i <= input
    add x7, x6, x5     # fib = fib_1 + fib_2
    add x5, x0, x6     # fib_2 = fib_1
    add x6, x0, x7     # fib_1 = fib
    addi x29, x29, 1   # i++
    beq x0, x0, loop   # loop back to start of this loop

$L4:
    add x10, x0, x7    # Set fib(input) = output (fib) from loop
    beq x0, x0, $L1

$L3:
    addi x10, x0, 1     # Set fib(1) = 1
    beq x0, x0, $L1     # Jump to return

$L2:
    addi x10, x0, 0    # Set fib(0) = 0
    beq x0, x0, $L1    # Jump to return

$L1:
    lw x8, 0(x2)     # Restore s0
    lw x1, 4(x2)     # Restore return address
    addi x2, x2, 8   # Update stack pointer

    ret
    nop
    nop
    nop

recursive_fibonacci:	# Performs recursive fibonacci for input x10 (x10!) and
                        #returns result to x10

    addi x2, x2, -12  # Make room to save values on stack
    sw x18, 0(x2)     # save saved register
    sw x8, 4(x2)     # Save saved register 2
    sw x1, 8(x2)      # Save return address on stack

    add x18, x10, x0   # store argument in x18
    
    addi x5, x0, 2     # Set temp reg to 2 for comparison
    bge x10, x5, $L5   # n >= 2

    lw x18, 0(x2)      # Load saved register 
    lw x8, 4(x2)       # Load saved register 2
    lw x1, 8(x2)       # Load return address back into x1
    addi x2, x2, 12     # reset stack pointer
    ret    # return
    nop
    nop
    nop

$L5:
    addi x10, x18, -1  # n = n - 1
    jal x1, recursive_fibonacci  # fib(n - 1)
    add x8, x10, x0       # save fib(n-1) in x8
    addi x10, x18, -2   # n = n - 2
    jal x1, recursive_fibonacci  # fib(n-2)
    add x10, x10, x8   # fib = fib(n-2) + fib(n-1)

    lw x18, 0(x2)      # recover OG n - 1
    lw x8, 4(x2)      # recover saved register 2
    lw x1, 8(x2)       # pop return address
    addi x2, x2, 12    # increment stack
    jalr x0, 0(x1)     # return

