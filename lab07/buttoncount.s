#########################################################################
# 
# Filename: buttoncount.s
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 25 February 2026
#
# Description:
# This program demonstrates the operation of all the LEDs, switches,
# buttons, and seven segment display in the I/O sub-system. 
#
#  - The timer value is copied to the seven segment display and is reset
#    with every button push
#  - The LEDs show a continuous count value that counts each button push
#    according to the button behavior described below
#  - Button behavior:
#    - BTNC clears LEDS/the count
#    - BTND decrements the count by 1
#    - BTNU increments the count by 1
#    - BTNR decrements the count by the value of the switches
#    - BTNL increments the count by the value of the switches
#
# This version of the program is written using the primitive instruction set
# for the multi-cycle RISC-V processor developed in the first labs.
#
# This program does not use the data segment.
#
# Memory Organization:
#   0x0000-0x1fff : text
#   0x2000-0x3fff : data
#   0x7f00-0x7fff : I/O
#
# Registers:
#  x3(x3):  I/O base address
#  x8(s0):  Value of buttons
#  x9(s1):  Value of switches
#  x18(s2): Value to write in LEDs
#
# Functions:
#  - N/A
#
#########################################################################

.globl  main

.data
	.word 0

.text


# I/O address offset constants
	.eqv LED_OFFSET 0x0
	.eqv SWITCH_OFFSET 0x4
	.eqv SEVENSEG_OFFSET 0x18
	.eqv TIMER 0x30
	.eqv BUTTON_OFFSET 0x24

# I/O mask constants
	.eqv BUTTON_C_MASK 0x01
	.eqv BUTTON_L_MASK 0x02
	.eqv BUTTON_D_MASK 0x04
	.eqv BUTTON_R_MASK 0x08
	.eqv BUTTON_U_MASK 0x10

main:
	# Prepare I/O base address
	addi x3, x0, 0x7f
	# Shift left 8
	slli x3, x3, 8
	# 0x7f00 should be in x3 (x3)

	# Set constants
	sw x0, SEVENSEG_OFFSET(x3)          # Clear seven segment display
	sw x0, TIMER(x3)                    # Clear timer to zero

    # Set count to 0
    addi x18, x0, 0

LOOP_START:

    # Load the buttons
    lw x8, BUTTON_OFFSET(x3)

UPDATE_SEVEN_SEG:
    lw x5, TIMER(x3)                # Load timer
    sw x5, SEVENSEG_OFFSET(x3)      # Write timer to sevenseg

BTNC:

    # Mask buttons for button c
    andi x6, x8, BUTTON_C_MASK
    # If button is not pressed, skip btnc code
    beq x6, x0, BTNU

ONESHOT_BTNC:

    # Check for button C release fter initial press
    lw x6, BUTTON_OFFSET(x3)            # load val of buttons
    andi x6, x6, BUTTON_C_MASK          # Mask for btnc
    xori x6, x6, -1                     # invert bits
    andi x6, x6, BUTTON_C_MASK          # Mask w/ btnc
    beq x6, x0, ONESHOT_BTNC            # if 0 (if btnc == 1 still) run this
                                        # again until btnc is released

    # Button C pressed - reset count 
    sw x0, TIMER(x3)                    # Clear timer to 0
    addi x18, x0, 0                     # reset count to 0
    beq x0, x0, WRITE_LED               # jump to rewrite LED with count

BTNU:

    # Mask buttons for btnu
    andi x6, x8, BUTTON_U_MASK
    # If button is not pressed, skip btnc code
    beq x6, x0, BTND

ONESHOT_BTNU:

    # Check for btnu release fter initial press
    lw x6, BUTTON_OFFSET(x3)            # load val of buttons
    andi x6, x6, BUTTON_U_MASK          # Mask for btnu
    xori x6, x6, -1                     # invert bits
    andi x6, x6, BUTTON_U_MASK          # Mask w/ btnu
    beq x6, x0, ONESHOT_BTNU            # if 0 (if btnu == 1 still) run this
                                        # again until btnu is released

    # Button U pressed - inc count by 1
    sw x0, TIMER(x3)                    # Clear timer to 0
    addi x18, x18, 1                    # Inc count by 1
    beq x0, x0, WRITE_LED               # jump to rewrite LED with count

BTND:

    # Mask buttons for btnd
    andi x6, x8, BUTTON_D_MASK
    # If button is not pressed, skip btnd code
    beq x6, x0, BTNL

ONESHOT_BTND:

    # Check for btnd release fter initial press
    lw x6, BUTTON_OFFSET(x3)            # load val of buttons
    andi x6, x6, BUTTON_D_MASK          # Mask for btnd
    xori x6, x6, -1                     # invert bits
    andi x6, x6, BUTTON_D_MASK          # Mask w/ btnd
    beq x6, x0, ONESHOT_BTND            # if 0 (if btnd == 1 still) run this
                                        # again until btnd is released

    # Button D pressed - dec count by 1
    sw x0, TIMER(x3)                    # Clear timer to 0
    addi x18, x18, -1                   # dec count by 1
    beq x0, x0, WRITE_LED               # jump to rewrite LED with count

BTNL:

    # Mask buttons for btnl
    andi x6, x8, BUTTON_L_MASK
    # If button is not pressed, skip btnd code
    beq x6, x0, BTNR

ONESHOT_BTNL:

    # Check for btnl release fter initial press
    lw x6, BUTTON_OFFSET(x3)            # load val of buttons
    andi x6, x6, BUTTON_L_MASK          # Mask for btnl
    xori x6, x6, -1                     # invert bits
    andi x6, x6, BUTTON_L_MASK          # Mask w/ btnl
    beq x6, x0, ONESHOT_BTNL            # if 0 (if btnl == 1 still) run this
                                        # again until btnl is released

    # Button L pressed - inc count by switch val
    sw x0, TIMER(x3)                    # Clear timer to 0
    lw x9, SWITCH_OFFSET(x3)            # Read the switches
    slli x19, x9, 16                    # shift switches left 16 to put sw[15]
                                        # in MSB
    srai x19, x19, 16                   # Shift value back to the right now
                                        # with the sign preserved
    add x18, x18, x19                   # inc count by switch value
    beq x0, x0, WRITE_LED               # jump to rewrite LED with count

BTNR:

    # Mask buttons for btnr
    andi x6, x8, BUTTON_R_MASK
    # If button is not pressed, skip btnd code
    beq x6, x0, LOOP_START

ONESHOT_BTNR:

    # Check for btnr release fter initial press
    lw x6, BUTTON_OFFSET(x3)            # load val of buttons
    andi x6, x6, BUTTON_R_MASK          # Mask for btnr
    xori x6, x6, -1                     # invert bits
    andi x6, x6, BUTTON_R_MASK          # Mask w/ btnr
    beq x6, x0, ONESHOT_BTNR            # if 0 (if btnr == 1 still) run this
                                        # again until btnr is released

    # Button R pressed - dec count by switch val
    sw x0, TIMER(x3)                    # Clear timer to 0
    lw x9, SWITCH_OFFSET(x3)            # Read the switches
    slli x19, x9, 16                    # shift switches left 16 to put sw[15]
                                        # in MSB
    srai x19, x19, 16                   # Shift value back to the right now
                                        # with the sign preserved
    sub x18, x18, x19                   # dec count by switch value

WRITE_LED:

    sw x18, LED_OFFSET(x3)
    beq x0, x0, LOOP_START              # jump back to start
