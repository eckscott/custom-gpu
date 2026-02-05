#########################################################################
#
# Filename: fib_iterative.s
# 
# Author: Ethan Scott
#
# Description: 
#
# Functions:
#  - fibonacci
#
#########################################################################


# The function name is 'fibonacci' and we need to make it global so the
# main function can call it.
.globl  fibonacci

# The function needs to be in the text segment
.text

fibonacci:			# Performs fibonacci for input a0 (a0!) and returns result to a0

    addi x2, x2, -8   # Make room to save values on stack
    sw x8, 0(x2)     # Save caller s0 on stack
    sw x1, 4(x2)     # Save return address on stack

    mv x8, x10        # Move input to s0 for manipulation

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
    beq x0, x0, loop

$L4:
    add x10, x0, x7
    j $L1

$L3:
    addi x10, x0, 1     # Set fib(1) = 1
    j $L1               # Jump to return

$L2:
    addi x10, x0, 0    # Set fib(0) = 0
    j $L1              # Jump to return

$L1:
    lw x8, 0(x2)     # Restore s0
    lw x1, 4(x2)     # Restore return address
    addi x2, x2, 8   # Update stack pointer

    ret               # Return to caller
