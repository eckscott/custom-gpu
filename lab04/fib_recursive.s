#########################################################################
#
# Filename: fib_recursive.s
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

fibonacci:			# Performs fibonacci for input x2 (x2!) and returns result
                    # to x2

    addi x2, x2, -8   # Make room to save values on stack
    sw x8, 0(x2)     # Save caller x8 on stack
    sw x1, 4(x2)     # Save return address on stack

    mv x8, x10        # Move input to x8 for manipulation

    beq x10, x0, $L2   # n = 0
    addi x6, x0, 1     # Set temp reg to 1 for comparison
    beq x10, x6, $L3   # n = 1
    
    addi x5, x0, 2     # Set temp reg to 2 for comparison
    bge x5, x8, $L1    # input >= 2
    addi x10, x0, 0    # fib = 0
    addi x2, x2, 8     # increment stack
    jalr x0, 0(x1)     # Now that you've stored as many iterations as you need
                       # you will jump to the actual fibonacci calculation

$L1:
    addi x10, x10, -1  # n - 1
    jal x1, fibonacci  # fib(n - 1)
    addi x6, x10, 0    # x6 = n
    lw x10, 0(x2)      # x10 = n + 1 (recovering the old n vals)
    lw x1, 4(x2)       # pop return address
    addi x2, x2, 8     # increment stack
    add x10, x10, x6   # fib(n) = fib(n-1) + fib(n-2)
    jalr x0, 0(x1)     # return

$L2:
    lw x8, 0(x2)
    lw x1, 4(x2)
    addi x2, x2, 8

    addi x10, x0, 0

    ret

$L3:
    lw x8, 0(x2)
    lw x1, 4(x2)
    addi x2, x2, 8

    addi x10, x0, 1

