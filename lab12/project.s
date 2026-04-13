#####################################################################################
#
# drawing_program.s
#
# A VGA drawing program. The screen displays a large drawing space (like a piece
# of paper on a desk). The character 'A' can be moved around the drawing space
# using the directional buttons. When SW(0) is toggled ON, moving the character
# leaves a copy of 'A' behind at each previous position, effectively "drawing"
# with the letter. When SW(0) is OFF, the character moves cleanly without leaving
# a trail.
#
# Controls:
#   BTNU  - Move character up
#   BTND  - Move character down
#   BTNL  - Move character left
#   BTNR  - Move character right
#   BTNC  - (First press) Run digit recognition, display result on 7-seg and LEDs
#           (Second press while displaying) Clear canvas and restart
#   SW(0) - OFF = move freely, ON = draw (leave A behind)
#
# Memory Organization:
#   0x0000-0x1fff : text
#   0x2000-0x3fff : data
#   0x7f00-0x7fff : I/O
#   0x8000-0xbfff : VGA
#
# The stack operates in the data segment starting at 0x3ffc.
#
# Registers:
#  x1(ra):  Return address
#  x2(sp):  Stack Pointer
#  x3(gp):  Data segment pointer
#  x4(tp):  I/O base address
#  x8(s0):  VGA base address
#
#####################################################################################
.globl  main

.text

# I/O address offset constants
	.eqv LED_OFFSET         0x0
	.eqv SWITCH_OFFSET      0x4
	.eqv SEVENSEG_OFFSET    0x18
	.eqv BUTTON_OFFSET      0x24
	.eqv CHAR_COLOR_OFFSET  0x34
	.eqv TIMER              0x30

# Button mask constants
	.eqv BUTTON_C_MASK  0x01
	.eqv BUTTON_L_MASK  0x02
	.eqv BUTTON_D_MASK  0x04
	.eqv BUTTON_R_MASK  0x08
	.eqv BUTTON_U_MASK  0x10

# Switch mask
	.eqv SW0_MASK       0x01

# Character constants
	.eqv CHAR_A             0x41        # ASCII 'A' (moving character)
	.eqv CHAR_A_MOVING      0xffffd041  # 'A' pencil yellow foreground, white background (the pencil)
	.eqv CHAR_A_DRAWN       0xfff00042  # 'B' black foreground, white background (drawn/stamped)
	.eqv CHAR_SPACE         0x20        # ASCII space (blank)
	.eqv CHAR_SPACE_WHITE   0xffffff20  # Space with white background (used to clear)

# VGA layout constants
	.eqv COLUMN_MASK        0x1fc       # Mask for column bits in VGA address
	.eqv COLUMN_SHIFT       2           # Right shift amount to get column number
	.eqv ROW_MASK           0x3e00      # Mask for row bits in VGA address
	.eqv ROW_SHIFT          9           # Right shift amount to get row number
	.eqv ADDRESSES_PER_ROW  512         # Bytes per row in VGA memory (128 cols * 4)
	.eqv NEG_ADDRESSES_PER_ROW -512

# Drawing canvas boundaries
# The canvas occupies columns 2..75 and rows 2..27 (leaving a 1-cell border)
	.eqv CANVAS_LEFT_COL    31
	.eqv CANVAS_RIGHT_COL   44
	.eqv CANVAS_TOP_ROW     7
	.eqv CANVAS_BOTTOM_ROW  20

# Starting position of the 'A' cursor: column 69, row 4 (top-right of canvas)
# VGA address = 0x8000 + col*4 + row*512 = 0x8000 +  
	.eqv STARTING_LOC       0x9080

main:
	# Setup stack pointer: sp = 0x3ffc
	li sp, 0x3ffc

	# Setup global pointer to data segment (2<<12 = 0x2000)
	lui gp, 2

	# Prepare I/O base address
	li tp, 0x7f00

	# Prepare VGA base address
	li s0, 0x8000

	# Call main drawing program procedure
	jal DRAWING_PROGRAM

END_MAIN:
	j END_MAIN


################################################################################
#
# DRAWING_PROGRAM
#
#  Main procedure. Initializes the canvas, places the cursor, and enters the
#  main input loop.
#
################################################################################
DRAWING_PROGRAM:

	# Setup stack frame
	addi sp, sp, -4
	sw ra, 0(sp)

	# Initialize default VGA color from starting location
	li t0, STARTING_LOC
	lw t1, 0(t0)
	srli t1, t1, 8
	sw t1, CHAR_COLOR_OFFSET(tp)

DP_RESTART:
	# Clear the canvas (fill drawing area with spaces)
	jal CLEAR_CANVAS

	# Place the cursor at the starting location
	li a0, STARTING_LOC
	jal MOVE_CHARACTER

	# Turn off LEDs and 7-seg (clean state)
	sw x0, LED_OFFSET(tp)
	sw x0, SEVENSEG_OFFSET(tp)

DP_NO_BUTTON:
	# Wait until no buttons are pressed before looking for input
	lw t0, BUTTON_OFFSET(tp)
	bne t0, x0, DP_NO_BUTTON

DP_WAIT_BUTTON:
	# Wait for a button press
	lw t0, BUTTON_OFFSET(tp)
	beq t0, x0, DP_WAIT_BUTTON

	# A button has been pressed; value is in t0
	add a0, t0, x0

DP_PROC_BUTTON:
	# Check if BTNC is pressed -> run inference
	li t0, BUTTON_C_MASK
	beq t0, a0, DP_RUN_INFERENCE

	# Otherwise process directional button: compute new address
	jal UPDATE_CHAR_ADDR     # returns new address in a0

	# Check SW(0) to decide draw mode
	lw t0, SWITCH_OFFSET(tp)
	andi t0, t0, SW0_MASK
	beq t0, x0, DP_MOVE_FREE  # SW(0) OFF: move freely

DP_DRAW_MODE:
	# SW(0) ON: stamp the drawn 'A' at the OLD location before moving
	jal STAMP_CHARACTER        # stamp drawn-A at current (old) location
	jal x0, DP_DO_MOVE

DP_MOVE_FREE:
	# SW(0) OFF: normal move (old position restored to what was there)

DP_DO_MOVE:
	jal MOVE_CHARACTER         # move cursor to new address (a0)

DP_WAIT_RELEASE:
	# Wait for button release
	lw t0, BUTTON_OFFSET(tp)
	bne x0, t0, DP_WAIT_RELEASE

DP_WAIT_NEXT:
	# Wait for next button press
	lw t0, BUTTON_OFFSET(tp)
	beq x0, t0, DP_WAIT_NEXT
	add a0, t0, x0
	jal x0, DP_PROC_BUTTON

DP_RUN_INFERENCE:
	# Wait for BTNC to be released before starting inference
	lw t0, BUTTON_OFFSET(tp)
	bne x0, t0, DP_RUN_INFERENCE

	# -----------------------------------------------------------------
	# NEURON_LOOP placeholder
	# Full forward-pass inference will go here.
	# When complete, the predicted digit will be in a result register
	# and certainty will be computed for the LEDs.
	# -----------------------------------------------------------------
	# TODO: implement inference loop
	# For now, fall straight through to display.

DIGIT_DISPLAY_LOOP:
	# Display placeholder digit "1" on the seven-segment display
	addi t0, x0, 1
	sw t0, SEVENSEG_OFFSET(tp)

	# Placeholder: LEDs show 0 certainty for now
	sw x0, LED_OFFSET(tp)

DDL_WAIT_RELEASE:
	# Ensure BTNC is not currently held before we poll for next press
	lw t0, BUTTON_OFFSET(tp)
	bne x0, t0, DDL_WAIT_RELEASE

DDL_WAIT_BTNC:
	# Spin here until BTNC is pressed again
	lw t0, BUTTON_OFFSET(tp)
	beq x0, t0, DDL_WAIT_BTNC

	# Check that it is specifically BTNC (ignore directional presses)
	li t1, BUTTON_C_MASK
	bne t0, t1, DDL_WAIT_BTNC

DDL_BTNC_PRESSED:
	# Clear the 7-seg and LEDs before restarting
	sw x0, SEVENSEG_OFFSET(tp)
	sw x0, LED_OFFSET(tp)

	# Jump back to DP_RESTART to clear canvas and begin fresh
	jal x0, DP_RESTART

DP_EXIT:
	lw ra, 0(sp)
	addi sp, sp, 4
	ret


################################################################################
#
# CLEAR_CANVAS
#
#  Fills the canvas area (rows CANVAS_TOP_ROW..CANVAS_BOTTOM_ROW,
#  cols CANVAS_LEFT_COL..CANVAS_RIGHT_COL) with blank space characters.
#  Also resets DISPLACED_CHARACTER_LOC to 0 so MOVE_CHARACTER won't
#  try to restore a stale location.
#
################################################################################
CLEAR_CANVAS:

	addi sp, sp, -4
	sw ra, 0(sp)

	# Reset displaced character tracking
	addi t0, gp, %lo(DISPLACED_CHARACTER_LOC)
	sw x0, 0(t0)

	# Compute starting VGA address of canvas:
	# addr = 0x8000 + CANVAS_LEFT_COL*4 + CANVAS_TOP_ROW*512
	li t5, 0x8000
	li t0, CANVAS_LEFT_COL
	slli t0, t0, 2                  # col * 4
	add t5, t5, t0
	li t0, CANVAS_TOP_ROW
	slli t0, t0, 9                  # row * 512
	add t5, t5, t0                  # t5 = VGA address of top-left canvas cell

	# Number of rows and columns to clear
	li t6, CANVAS_TOP_ROW           # current row counter
	li s1, CANVAS_BOTTOM_ROW        # last row
	li s2, CANVAS_LEFT_COL          # left column index
	li s3, CANVAS_RIGHT_COL         # right column index

	li a1, CHAR_SPACE_WHITE         # value to write (blank cell)

CC_ROW_LOOP:
	blt s1, t6, CC_DONE            # done all rows?

	# Reset column counter and base pointer for this row
	li t4, CANVAS_LEFT_COL         # current column counter
	# Compute row base address: t5 already points to left col of current row

	add t3, t5, x0                 # t3 = current cell pointer

CC_COL_LOOP:
	blt s3, t4, CC_NEXT_ROW        # done all cols in this row?
	sw a1, 0(t3)                   # write blank
	addi t3, t3, 4                 # next column
	addi t4, t4, 1
	jal x0, CC_COL_LOOP

CC_NEXT_ROW:
	addi t6, t6, 1                 # next row
	li t0, ADDRESSES_PER_ROW
	add t5, t5, t0                 # advance base pointer to next row
	jal x0, CC_ROW_LOOP

CC_DONE:
	lw ra, 0(sp)
	addi sp, sp, 4
	ret


################################################################################
#
# UPDATE_CHAR_ADDR
#
#  Reads the current cursor location and computes a new address based on
#  which directional button was pressed (passed in a0). Clamps movement
#  to the canvas boundaries. Returns the new (or unchanged) address in a0.
#
#  a0: button value (input), new VGA address (output)
#
################################################################################
UPDATE_CHAR_ADDR:

	addi sp, sp, -4
	sw ra, 0(sp)

	# Load current character address
	lw t2, %lo(DISPLACED_CHARACTER_LOC)(gp)

	# If first call (address == 0), use starting location
	bne t2, x0, UCA_COMPUTE_COLROW
	li t2, STARTING_LOC

UCA_COMPUTE_COLROW:
	# Compute column (t3) and row (t4) from address
	li t0, COLUMN_MASK
	and t3, t0, t2
	srli t3, t3, COLUMN_SHIFT

	li t0, ROW_MASK
	and t4, t0, t2
	srli t4, t4, ROW_SHIFT

UCA_CHECK_BTNR:
	li t0, BUTTON_R_MASK
	bne t0, a0, UCA_CHECK_BTNL
	li t1, CANVAS_RIGHT_COL
	bge t3, t1, UCA_DONE        # At right boundary
	addi t2, t2, 4
	jal x0, UCA_DONE

UCA_CHECK_BTNL:
	li t0, BUTTON_L_MASK
	bne t0, a0, UCA_CHECK_BTND
	li t1, CANVAS_LEFT_COL
	bge t1, t3, UCA_DONE        # At left boundary
	addi t2, t2, -4
	jal x0, UCA_DONE

UCA_CHECK_BTND:
	li t0, BUTTON_D_MASK
	bne t0, a0, UCA_CHECK_BTNU
	li t1, CANVAS_BOTTOM_ROW
	bge t4, t1, UCA_DONE        # At bottom boundary
	addi t2, t2, ADDRESSES_PER_ROW
	jal x0, UCA_DONE

UCA_CHECK_BTNU:
	li t0, BUTTON_U_MASK
	bne t0, a0, UCA_DONE
	li t1, CANVAS_TOP_ROW
	bge t1, t4, UCA_DONE        # At top boundary
	addi t2, t2, NEG_ADDRESSES_PER_ROW

UCA_DONE:
	add a0, t2, x0
	lw ra, 0(sp)
	addi sp, sp, 4
	ret


################################################################################
#
# STAMP_CHARACTER
#
#  Called in draw mode before moving. Writes the DRAWN version of 'A'
#  (cyan foreground) at the current cursor location so it stays on screen.
#  Also updates DISPLACED_CHARACTER to reflect this stamped value, so that
#  MOVE_CHARACTER will restore this drawn-A (not erase it) if it ever comes
#  back to this cell.
#
################################################################################
STAMP_CHARACTER:

	addi sp, sp, -4
	sw ra, 0(sp)

	# Get current cursor location
	lw t0, %lo(DISPLACED_CHARACTER_LOC)(gp)
	beq t0, x0, SC_DONE         # No location yet, skip

	# Write the drawn-A value at the current location
	li t1, CHAR_A_DRAWN
	sw t1, 0(t0)

	# Update the saved displaced character value to the drawn-A,
	# so MOVE_CHARACTER restores the drawn-A (not a blank) when leaving
	addi t2, gp, %lo(DISPLACED_CHARACTER)
	sw t1, 0(t2)

SC_DONE:
	lw ra, 0(sp)
	addi sp, sp, 4
	ret


################################################################################
#
# MOVE_CHARACTER
#
#  Moves the cursor 'A' (red) to the new location given in a0.
#  Restores the previously displaced character at the old location
#  (unless in draw mode, where STAMP_CHARACTER already handled that).
#  Saves the new location's old contents, then writes the moving 'A'.
#
#  a0: VGA memory address of new cursor location (unchanged on return)
#
################################################################################
MOVE_CHARACTER:

	addi sp, sp, -4
	sw ra, 0(sp)

	# Load old cursor location
	lw t3, %lo(DISPLACED_CHARACTER_LOC)(gp)

	# If zero (first call), skip restore
	beq t3, x0, MC_SAVE_DISPLACED_CHAR

	# Restore what was at the old location
	lw t2, %lo(DISPLACED_CHARACTER)(gp)
	sw t2, 0(t3)

MC_SAVE_DISPLACED_CHAR:
	# Save the value currently at the new location
	lw t1, 0(a0)
	addi t0, gp, %lo(DISPLACED_CHARACTER)
	sw t1, 0(t0)

	# Save the new location address
	addi t0, gp, %lo(DISPLACED_CHARACTER_LOC)
	sw a0, 0(t0)

MC_UPDATE_MOVING_CHAR:
	# Write the moving cursor 'A' (red) at the new location
	lw t0, %lo(MOVING_CHARACTER)(gp)
	sw t0, 0(a0)

MC_EXIT:
	lw ra, 0(sp)
	addi sp, sp, 4
	ret

	nop
	nop
	nop

################################################################################
# Data segment
################################################################################

.data

# The cursor character: red 'A' on black background
MOVING_CHARACTER:
	.word CHAR_A_MOVING

# Value of the character that the cursor is currently covering
DISPLACED_CHARACTER:
	.word 0

# VGA address where the cursor currently sits (0 = not yet placed)
DISPLACED_CHARACTER_LOC:
	.word 0