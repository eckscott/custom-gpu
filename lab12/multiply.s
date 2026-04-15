#########################################################################
#
# Filename: multiply.s
#
# Author: Ethan Scott
#
# Description: Signed shift-and-add multiplier function. Designed to be
#   called from Layer 2 of the neural network forward pass in project.s.
#
#   Inputs:
#     a0 (x10) - multiplicand (L1 activation, always >= 0 due to ReLU)
#     a1 (x11) - multiplier   (L2 weight, signed byte, -128 to 127)
#                NOTE: a1 is also the L2 weight pointer in project.s, so
#                      the CALLER must pass the weight VALUE in a separate
#                      register. See integration note below.
#
#   Output:
#     a0 (x10) - product (signed)
#
#   Saved registers used (all caller-saved on entry/exit via stack):
#     x8  (s0), x9  (s1), x18 (s2), x19 (s3), x1 (ra)
#
#########################################################################

.text
.globl multiply

multiply:
    # Save ra and s-registers we use
    addi sp, sp, -20
    sw   ra,  16(sp)
    sw   x19, 12(sp)
    sw   x18,  8(sp)
    sw   x9,   4(sp)
    sw   x8,   0(sp)

    # x10 = activation (>=0), x11 = weight (signed)
    # Track sign: if weight is negative, negate it and flag the result
    addi x19, x0, 0         # sign_flag = 0 (positive result)

    bge  x11, x0, $M_setup  # weight >= 0, no sign flip needed
    sub  x11, x0, x11       # weight = -weight (make positive)
    addi x19, x0, 1         # sign_flag = 1 (result will be negative)

$M_setup:
    addi x8,  x0,  0        # result = 0
    add  x18, x10, x0       # x18 = shifted copy of activation
    add  x9,  x11, x0       # x9  = working copy of weight (counts down)

$M_loop:
    beq  x9, x0, $M_done   # if weight == 0, done

    andi x28, x9, 1         # test LSB of weight
    beq  x28, x0, $M_skip  # LSB == 0, skip add

    add  x8, x8, x18        # result += (activation << shift)

$M_skip:
    slli x18, x18, 1        # activation <<= 1
    srli x9,  x9,  1        # weight >>= 1 (logical, safe since we made it positive)
    jal  x0, $M_loop

$M_done:
    beq  x19, x0, $M_return # sign_flag == 0, result is positive
    sub  x8, x0, x8         # result = -result

$M_return:
    add  x10, x0, x8        # return value in a0

    lw   x8,   0(sp)
    lw   x9,   4(sp)
    lw   x18,  8(sp)
    lw   x19, 12(sp)
    lw   ra,  16(sp)
    addi sp, sp, 20

    ret
    nop
    nop
    nop