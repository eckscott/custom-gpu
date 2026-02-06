#########################################################################
#
# Filename: fib_recursive.s
# 
# Author: Ethan Scott
#
# Description: This script determines the fibonacci number for any input
#   through a recursive approach.
#
# Functions:
#  - fibonacci: performs fibonacci number of (x10) and returns result to (x10)
#
#########################################################################


# The function name is 'fibonacci' and we need to make it global so the
# main function can call it.
.globl  fibonacci

# The function needs to be in the text segment
.text

fibonacci:			# Performs fibonacci for input x10 (x10!) and returns result
                    # to x10

    addi x2, x2, -12  # Make room to save values on stack
    sw x18, 0(x2)     # save saved register
    sw x8, 4(x2)     # Save saved register 2
    sw x1, 8(x2)      # Save return address on stack

    add x18, x10, x0   # store argument in x18
    
    addi x5, x0, 2     # Set temp reg to 2 for comparison
    bge x10, x5, $L1   # n >= 2

    lw x18, 0(x2)      # Load saved register 
    lw x8, 4(x2)       # Load saved register 2
    lw x1, 8(x2)       # Load return address back into x1
    addi x2, x2, 12     # reset stack pointer
    ret

$L1:
    addi x10, x18, -1  # n = n - 1
    jal x1, fibonacci  # fib(n - 1)
    mv x8, x10       # save fib(n-1) in x8
    addi x10, x18, -2   # n = n - 2
    jal x1, fibonacci  # fib(n-2)
    add x10, x10, x8   # fib = fib(n-2) + fib(n-1)

    lw x18, 0(x2)      # recover OG n - 1
    lw x8, 4(x2)      # recover saved register 2
    lw x1, 8(x2)       # pop return address
    addi x2, x2, 12    # increment stack
    jalr x0, 0(x1)     # return


