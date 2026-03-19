#########################################################################
# 
# Filename: move_char.s
#
# Author: Ethan Scott
# Class: ECEN 423, Sec 01, Winter 2026
# Date: 18 March 2026
#
# Description: This assembly file writes my netid (eckscott) starting at
#   column 60 and and row 24 and a smiley face that can be moved
#
# This program does not use the data segment.
#
# Memory Organization:
#   0x0000-0x1fff : text
#   0x2000-0x3fff : data
#   0x7f00-0x7fff : I/O
#   0x8000- : VGA
#
# Registers:
# x3(gp):   I/O base address
# x4(tp):   VGA Base address
# x8(s0):   Memory pointer to location to display character
# x9(s1):   Current column index
# x18(s2):  Current row index
#
#########################################################################
.globl  main

.data
	.word 0

.text

# VGA foreground and brackground values
    .eqv VGA_FOREGROUND 0xf80
    .eqv VGA_BACKGROUND 0x92e
    .eqv VGA_RESERVED   0x00

# I/O address offset constants
	.eqv LED_OFFSET 0x0
	.eqv SWITCH_OFFSET 0x4
	.eqv SEVENSEG_OFFSET 0x18
	.eqv BUTTON_OFFSET 0x24
	.eqv CHAR_COLOR_OFFSET 0x34

# I/O mask constants
	.eqv BUTTON_C_MASK 0x01
	.eqv BUTTON_L_MASK 0x02
	.eqv BUTTON_D_MASK 0x04
	.eqv BUTTON_R_MASK 0x08
	.eqv BUTTON_U_MASK 0x10

# ASCII SPACE
	.eqv SPACE_CHAR 0x20
	.eqv HASH_CHAR 0x23
	.eqv LAST_COLUMN 10			# 79 - last two columns don't show on screen
	.eqv LAST_ROW 10			# 31 - last two rows don't show on screen
	.eqv ADDRESSES_PER_ROW 512
	.eqv NEG_ADDRESSES_PER_ROW -512

# Program constants
	.eqv IO_BASE_PRESHIFT 0x7f
	.eqv IO_BASE_SHFTLEFT 8
	.eqv VGA_BASE_PRESHIFT 0x40
	.eqv VGA_BASE_SHFTLEFT 9
	.eqv SWITCH_MASK_7 0x7f
	.eqv SWITCH_MASK_12_PRESHIFT 0x7ff
	.eqv LOOP_CONSTANT_PRESHIFT 0x400

main:
	# Prepare I/O base address (0x7f00). 
	# We don't have the LUI instruction to do this more naturally
	addi gp, x0, IO_BASE_PRESHIFT		# 0x7f
	# Shift left 8 (0x7f00)
	slli gp, gp, IO_BASE_SHFTLEFT
	# 0x7f00 should be in gp

	# Prepare VGA base address (0x8000)
	addi tp, x0, VGA_BASE_PRESHIFT # 0x40
	# Shift left 9 (0x8000)
	slli tp, tp, VGA_BASE_SHFTLEFT # 0x40 << 9 = 0x8000
	# 0x8000 should be in tp

CLEAR_VGA:

	# Set the foreground to 0xf80
    addi t2, x0, 0xf
	slli t2, t2, 8
	ori t2, t2, 0x80
    # Set the background to 0x92e
    addi t3, x0, 0x9
	slli t3, t3, 8
	ori t3, t3, 0x2e
    # Set the reserved bits
    addi t4, x0, 0
    # Shift reserved and background
    slli t4, t4, 24
    slli t3, t3, 12
    # Merge reserved, background, and foreground
    add t4, t3, t2
    # Write the new color values
    sw t4, CHAR_COLOR_OFFSET(gp)

CLEAR_SEVEN_SEG:

	# Clear Seven segment display and LEDs
	sw x0, SEVENSEG_OFFSET(gp)
	sw x0, LED_OFFSET(gp)

	# Write a space to all locations in VGA memory
	addi t0, x0, SPACE_CHAR		# ASCII character for space
	add t1, x0, tp			# Pointer to VGA space that will change
	# Create constant 0x1000
	addi t2, x0, LOOP_CONSTANT_PRESHIFT  # 0x400
	# should get 0x1000
	slli t2, t2, 2

CLEAR_LOOP:
	sw t0, 0(t1)			# Write 'space' character to pointer in VGA space
	addi t2, t2, -1			# Decrement counter
	beq t2, x0, PRINT_NET_ID	# Exit loop when done
	addi t1, t1, 4			# Increment memory pointer by 4 to next character address
	beq x0, x0, CLEAR_LOOP

PRINT_NET_ID:

	# Set row address to 24
	addi t2, x0, 24
	# Shift row address to fit bits [13:9]
	slli t2, t2, 9
	# Set column address to 60
	addi t3, x0, 60
	# Shift column address to fit bits [8:2]
	slli t3, t3, 2
	# Set VGA character address for writing to (60,24)
	or t4, t3, t2
	add t4, t4, tp

	# Write character 'E'
	addi t1, x0, 0x45
	sw t1, 0(t4)

	# Write character 'C' to next char space
	addi t1, x0, 0x43
	sw t1, 4(t4)

	# Write character 'K' to next char space
	addi t1, x0, 0x4B
	sw t1, 8(t4)

	# Write character 'S' to next char space
	addi t1, x0, 0x53
	sw t1, 12(t4)

	# Write character 'C' to next char space
	addi t1, x0, 0x43
	sw t1, 16(t4)

	#Write Character 'O' to next char space
	addi t1, x0, 0x4F
	sw t1, 20(t4)

	#Write Character 'T' to next 2 char spaces
	addi t1, x0, 0x54
	sw t1, 24(t4)
	sw t1, 28(t4)

	addi s0, tp, 0			# s0: pointer to VGA locations
	addi s1, x0, 0			# s1: current column
	addi s2, x0, 0			# s2: current row

SMILEY_FACE:
	#Write a smiley face to 0,0
	addi t1, x0, 0x01
	sw t1, 0(s0)

# Wait until all the buttons are released before proceeding to check for status of buttons
	# (this is a one shot functionality to prevent one button press from causing more than one
	#  response)
BTN_RELEASE:

	lw t0, BUTTON_OFFSET(gp)
	# Keep jumping back until a button is pressed
	beq x0, t0, BTN_PRESS
	beq x0, x0, BTN_RELEASE

BTN_PRESS:
	# Wait for button press
	lw t0, BUTTON_OFFSET(gp)
	# Keep jumping back until a button is pressed
	beq x0, t0, BTN_PRESS

	# See if BUTTON_C is pressed. If so, clear VGA
	addi t1, x0, BUTTON_C_MASK
	beq t0, t1, CLEAR_VGA

UPDATE_DISPLAY_POINTER:
	# Any other button means print the character of the switches on the VGA and move the pointer

	# Update the pointer based on the button
	addi t1, x0, BUTTON_L_MASK
	beq t0, t1, PROCESS_BTNL
	addi t1, x0, BUTTON_R_MASK
	beq t0, t1, PROCESS_BTNR
	addi t1, x0, BUTTON_U_MASK
	beq t0, t1, PROCESS_BTNU
	addi t1, x0, BUTTON_D_MASK
	beq t0, t1, PROCESS_BTND

	# Shouldn't get here
	beq x0, x0, BTN_RELEASE

	# These code segments update the data to print on the SSD as well
	# as determine the new next location for printing characters
PROCESS_BTNR:
	# Move pointer right
	addi t0, x0, LAST_COLUMN
	beq s1, t0, BTN_RELEASE                     # Ignore if on last column
	addi s1, s1, 1                              # Increment column
	addi t1, x0, SPACE_CHAR						# Write space where smiley was
	sw t1, 0(s0)
	addi s0, s0, 4                              # Increment pointer for next display location
	beq x0, x0, SMILEY_FACE

PROCESS_BTNL:
	# Move pointer left
	beq s1, x0, BTN_RELEASE                     # Ignore if on first column
	addi s1, s1, -1                             # Decrement column
	addi t1, x0, SPACE_CHAR						# Write space where smiley was
	sw t1, 0(s0)
	addi s0, s0, -4                             # Decrement pointer for next display location
	beq x0, x0, SMILEY_FACE

PROCESS_BTNU:
	# Move pointer Up
	beq s2, x0, BTN_RELEASE                     # Ignore if on first row
	addi s2, s2, -1                             # Decrement row
	addi t1, x0, SPACE_CHAR						# Write space where smiley was
	sw t1, 0(s0)
	addi s0, s0, NEG_ADDRESSES_PER_ROW          # Decrement pointer
	beq x0, x0, SMILEY_FACE

PROCESS_BTND:
	# Move pointer Down
	addi t0, x0, LAST_ROW
	beq s2, t0, BTN_RELEASE                     # Ignore if on last row
	addi s2, s2, 1                              # Increment row
	addi t1, x0, SPACE_CHAR						# Write space where smiley was
	sw t1, 0(s0)
	addi s0, s0, ADDRESSES_PER_ROW              # Increment pointer
	beq x0, x0, SMILEY_FACE




