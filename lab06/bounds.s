#########################################################################
# 
# Filename: bounds.s
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 19 February 2026
#
# Description: This program iterates through an array of words provided
# in the data segment of bounds_data.s, and performs the following:
#  - If the current element is greater than MAX_VALUE, update the element
#    to MAX_VALUE and increment the count of elements greater than MAX_VALUE
#  - If the current element is less than MIN_VALUE, update the element
#    to MIN_VALUE and increment the count of elements less than MIN_VALUE
#  - Once all elements have been iterated through, the program terminates
#    with the program described in end:
#
# Functions:
#  - N/A
#
#########################################################################

# Include bounds_data.s, which contains the data segment for this program
.include "bounds_data.s"

# Data Segment at 0x00000000
.data 0x00000000

.text
main:               # Label for start of program

    la x5, bounds_data   # Load address of bounds_data into x5

iterate_loop:

    lw x6, 0(x5)        # Load the current element of bounds_data into x6

    beq x6, x0, end     # If the current element is 0, end of array reached

    blt MAX_VALUE, x6, update_max  # If current element is greater than
                                   # MAX_VALUE, update max count
    blt x6, MIN_VALUE, update_min  # If current element is less than
                                   # MIN_VALUE, update min count
    
    lw x7, 0(x5)        # Load the updated element
    add a0, x7, a0      # Add the current element to the running sum of array

    addi x5, x5, 4      # Increment pointer to next element (4 bytes for each word)
    jalr x0, iterate_loop  # Jump back to start of loop

update_max:
    sw MAX_VALUE, 0(x5)  # Store MAX_VALUE at the current element's address
    addi a1, a1, 1     # Increment count of elements greater than MAX_VALUE
    return             # Return to caller

update_min:
    sw MIN_VALUE, 0(x5)  # Store MIN_VALUE at the current element's address
    addi a2, a2, 1     # Increment count of elements less than MIN_VALUE
    return             # Return to caller

end:
    addi x0, a0, 0      # Instructions provided in lab write up for termination
    addi x0, a1, 0      # of program
    addi x0, a2, 0
    ebreak
    nop
