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
#     a0 - multiplicand (L1 activation, always >= 0 due to ReLU)
#     a1 - multiplier   (L2 weight, signed byte, -128 to 127)
#
#   Output:
#     a0 - product (signed)
#
#   Saved registers used (all saved/restored via stack):
#     s0, s1, s2, s3, ra
#
#########################################################################

.text
.globl multiply

multiply:
    # Save ra and s-registers we use
    addi sp, sp, -20
    sw   ra,  16(sp)
    sw   s3,  12(sp)
    sw   s2,   8(sp)
    sw   s1,   4(sp)
    sw   s0,   0(sp)

    # a0 = activation (>=0), a1 = weight (signed)
    # Track sign: if weight is negative, negate it and flag the result
    addi s3, x0, 0          # sign_flag = 0 (positive result)

    bge  a1, x0, $M_setup   # weight >= 0, no sign flip needed
    sub  a1, x0, a1         # weight = -weight (make positive)
    addi s3, x0, 1          # sign_flag = 1 (result will be negative)

$M_setup:
    addi s0, x0,  0         # result = 0
    add  s2, a0, x0         # s2 = shifted copy of activation
    add  s1, a1, x0         # s1 = working copy of weight (counts down)

$M_loop:
    beq  s1, x0, $M_done    # if weight == 0, done

    andi t0, s1, 1          # test LSB of weight
    beq  t0, x0, $M_skip   # LSB == 0, skip add

    add  s0, s0, s2         # result += (activation << shift)

$M_skip:
    slli s2, s2, 1          # activation <<= 1
    srli s1, s1, 1          # weight >>= 1 (logical, safe since we made it positive)
    jal  x0, $M_loop

$M_done:
    beq  s3, x0, $M_return  # sign_flag == 0, result is positive
    sub  s0, x0, s0         # result = -result

$M_return:
    add  a0, x0, s0         # return value in a0

    lw   s0,   0(sp)
    lw   s1,   4(sp)
    lw   s2,   8(sp)
    lw   s3,  12(sp)
    lw   ra,  16(sp)
    addi sp, sp, 20

    ret
    nop
    nop
    nop
