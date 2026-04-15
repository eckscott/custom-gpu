
#####################################################################################
#
# project.s
#
# A VGA drawing program. The screen displays a large drawing space (like a piece
# of paper on a desk). The character 'A' is a pencil that can be moved around the drawing
# space using the buttons. When SW(0) is toggled ON, moving the character marks the
# character 'B' behind at each previous position, effectively "drawing"
# with the letter. When SW(0) is OFF, the pencil moves cleanly without leaving
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

# Starting position of the 'A' cursor: column 31, row 7 (top-right of canvas)
# VGA address = 0x8000 + col*4 + row*512 = 0x8000 +  
	.eqv STARTING_LOC       0x8E7C

# VGA addresses that require a larger offset for next row
	.eqv END_OF_ROW1         0x8EB0   # row 7 (top canvas row)
	.eqv END_OF_ROW2		 0x90B0   # row 8
	.eqv END_OF_ROW3		 0x92B0   # row 9
	.eqv END_OF_ROW4		 0x94B0   # row 10
	.eqv END_OF_ROW5		 0x96B0   # row 11
	.eqv END_OF_ROW6		 0x98B0   # row 12
	.eqv END_OF_ROW7		 0x9AB0   # row 13
	.eqv END_OF_ROW8		 0x9CB0   # row 14
	.eqv END_OF_ROW9		 0x9EB0   # row 15
	.eqv END_OF_ROW10		 0xA0B0   # row 16
	.eqv END_OF_ROW11		 0xA2B0   # row 17
	.eqv END_OF_ROW12		 0xA4B0   # row 18
	.eqv END_OF_ROW13		 0xA6B0   # row 19
	.eqv END_OF_ROW14		 0xA8B0   # row 20 (bottom canvas row)
	.eqv INC_ROW_OFFSET		 460   # offset to add to VGA address to advance one row
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

################################################################################
#
#  FIRST LAYER NEURON LOOP
#
#  Forward pass through the neural network to compute digit recogntion result.
#  This neural network scans the VGA canvas memory to read pixel values. For the
#  first layer, it accumulates the weights if corresponding to an "on" pixel,
#  effectively computing the dot product of the input image with each neuron's
#  weights. A ReLU is then applied to decide which neurons are "activated"
#  (positive output) and which are not
#
################################################################################

NEURON_START:
	li t2, L1_WEIGHTS	 # Pointer to start of L1 weights
	li s4, L1_BIASES	 # Pointer to L1 bias values
	li s5, HIDDEN_ACTIVATIONS # Pointer to store L1 outputs
	addi s6, x0, 0		 # current neuron

FIRST_LAYER_NEURON_LOOP:
	lb t0, 0(s4)         # accumulator (currently holds bias value)
	li t1, STARTING_LOC  # pointer to start of vga memory

NUERON_LOOP:
	lw t3, 0(t1)	     # read cell value
	andi t3, t3, 0x0ff	 # get pixel on/off value (0x42 if "on", 0x20 if "off")
	li t4, 0x42		     # compare to on
	bne t3, t4, SKIP_ADD # if not drawn, don't add weight

	lb t5, 0(t2)		# load weight value
	add t0, t0, t5		# accumulate weight into sum

SKIP_ADD:

	# Check to see if at the end of the canvas (after processing 20 rows). If so, we're done with this neuron.
	li t6, END_OF_ROW14
	beq t6, t1, NEURON_DONE

	# Check to see if row advance is needed for VGA address
	li t6, END_OF_ROW1
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW2
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW3
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW4
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW5
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW6
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW7
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW8
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW9
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW10
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW11
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW12
	beq t6, t1, ADVANCE_ROW
	li t6, END_OF_ROW13
	beq t6, t1, ADVANCE_ROW

	beq x0, x0, INC_POINTERS

ADVANCE_ROW:
	addi t1, t1, INC_ROW_OFFSET - 4	# advance to next row (adjust for already adding 4 above)

INC_POINTERS:
	addi t1, t1, 4		# advance to next cell
	addi t2, t2, 1		# advance to next weight

	jal x0, NUERON_LOOP

NEURON_DONE: # ReLU
	bge t0, x0, STORE_ACTIVATION # if sum is positive, store it as activation
	addi t0, x0, 0		# if sum is negative, store 0 as activation

STORE_ACTIVATION:
	sw t0, 0(s5)		# store activation value for this neuron
	addi s4, s4, 1      # advance bias pointer
	addi s5, s5, 4		# advance to next output cell
	addi s6, s6, 1      # increment neuron counter
	addi t0, x0, 32 	# finished neuron count is 32, time to move to second layer
	bne s6, t0, FIRST_LAYER_NEURON_LOOP

################################################################################
#
#  SECOND LAYER NEURON LOOP
#
#  This Layer takes the 32 activations from the first layer as input and produces
#  10 output scores corresponding to digit predictions. Each output neuron computes
#  the dot product of the 32 hidden layer activations with its weights, adds a bias,
#  and produces a score. The digit with the highest score is the predicted digit.
#
################################################################################
LAYER_2_START:
	li s1, L2_WEIGHTS	 # Pointer to start of L2 weights
	li s4, L2_BIASES	 # Pointer to L2 bias values
	li s7, OUTPUT_SCORES	 # Pointer to store L2 outputs
	addi s6, x0, 0		 # current digit

L2_NEURON:
	addi t1, x0, 0	    # current neuron 
	lb t0, 0(s4)  # accumulator (currently holds bias value)
	li s5, HIDDEN_ACTIVATIONS # Pointer to L1 outputs
	addi t2, x0, 32 	# Number of neurons in L2

L2_NEURON_LOOP:
	beq t1, t2, L2_NEURON_DONE

	lw a0, 0(s5) 		# Load L1 activation
	lb a1, 0(s1) 		# Load weight
	jal multipy
	add t0, t0, t3		# accumulate into sum

	addi s1, s1, 1		# advance weight pointer
	addi s5, s5, 4		# advance L1 output pointer
	addi t1, t1, 1		# increment neuron counter
	jal x0, L2_NEURON_LOOP

L2_NEURON_DONE:
	sw t0, 0(s7)		# store output score for this digit
	addi s7, s7, 4		# advance output score pointer
	addi s4, s4, 1      # advance bias pointer
	addi s6, s6, 1      # increment digit counter
	addi t3, x0, 10	 # After computing scores for all 10 digits, move to display logic
	bne s6, t3, L2_NEURON

################################################################################
#
#  ARGMAX AND DISPLAY
#
#  After computing the output scores for each digit, we need to determine
# which digit has the highest score (argmax) and display that result on the
# 7-seg display. The LEDs can be used to indicate confidence.
#
################################################################################

ARG_MAX:
	addi t0, x0, -120		# current max value
	addi t1, x0, 0			# index of current max value
	addi t2, x0, 0			# current index
	li s7, OUTPUT_SCORES # Pointer to start of L2 output scores
	addi s8, x0, 10		# number of scores to process

ARG_MAX_LOOP:
	# Compare current score with max score
	lw t3, 0(s7)
	bge t0, t3, ARG_MAX_NEXT

ARG_MAX_UPDATE:
	add t0, t3, x0		# update max value
	add t1, t2, x0      # update max index

ARG_MAX_NEXT:
	addi s7, s7, 4		# advance output score pointer
	addi t2, t2, 1		# increment index
	bne t2, s8, ARG_MAX_LOOP

DIGIT_DISPLAY_LOOP:
	sw t1, SEVENSEG_OFFSET(tp)  	# Display index of max score on 7-seg (0-9)

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

# Weights and biases for the neural network
L1_WEIGHTS:
    .byte 1, 3, -3, -1, -2, 3, 3, 2, 2, 2, -4, -2, 4, -4, -1, 4, -3, -5, -23, -38, -35, -23, -33, 4, 9, 2, -2, 4, 0, 2, 7, -6, -37, -28, -35, -12, -5, 0, 4, 9, -21, -1, -1, 9, -20, -10, -13, -11, -29, -9, 12, 6, 13, 3, -32, 1, -2, 26, -3, -7, 5, -5, -30, 5, 35, 20, -2, -25, -18, -1, 6, 0, -9, -26, -1, -13, -21, 18, 38, 20, 0, -46, -24, 3, 4, 18, -3, -7, 2, 5, -2, 25, 29, 22, 1, -17, -15, 2, 2, 1, -6, -24, 6, 20, 7, 13, 33, 12, -14, -25, -11, 4, -1, -2, -14, -46, -1, 9, 4, 4, 14, -2, -25, -43, -28, 3, -4, -2, -18, -35, -31, -14, 3, -6, -10, -28, -39, -46, -20, 1, 1, -8, 11, -4, -12, -6, -3, -21, -13, -32, -31, -25, -6, -1, 0, -20, 17, 26, 16, 3, -2, -13, -19, -18, -32, -18, 0, 0, -4, -11, 33, 18, 18, -6, -16, -18, -4, 14, 19, 3, -1, 1, -3, 4, 2, 17, -7, 19, -16, -3, 15, 5, 11, -1, -3, 1, -3, 0, -4, 1, -1, -3, -1, -2, 2, 0, -1, 3, -4, -1, -3, 4, 3, -16, -11, -12, -26, -28, -5, -17, -24, -25, 9, 2, 1, -4, -2, 0, -5, 3, 10, 1, 4, 3, -3, -15, -2, -1, 0, 20, 7, 20, 14, 17, 9, -1, -11, 5, 5, 15, 18, -21, -2, 16, 21, 18, 23, 18, 4, -12, -14, 5, 18, 26, 20, 9, 8, 9, 20, 19, 21, 21, 14, -3, -6, 0, -4, 10, 11, -4, 0, 6, -4, -29, -11, -14, -12, -9, -2, 2, -6, -22, 10, -6, 3, 16, -31, -30, -34, -10, 8, 2, 10, 8, -19, -18, -1, 1, 2, -10, -17, -18, -7, -4, 14, 23, 6, -2, 2, 0, 9, 3, 2, -7, 7, 13, 11, 2, -3, 8, -11, -14, -13, 2, 4, 3, 1, 7, 15, 21, 18, 2, -1, -3, -11, -12, -15, -1, -7, -1, 2, -8, 8, 13, 16, 26, 22, 13, 2, -19, -11, -2, 7, -3, -4, -6, -18, -11, -4, 5, 7, 22, 10, 3, -27, -28, 1, -1, 0, 2, -2, 22, 0, 2, 15, 11, 5, 21, -4, -3, -1, 1, -3, -1, -1, 0, -3, -4, -2, -2, -3, -4, 1, 2, 4, 0, -4, 2, -2, -19, -17, 5, 13, -9, -12, -23, -18, -29, 2, -2, -2, 4, -13, 18, 31, 32, 38, 25, 7, -11, -21, -37, -16, 1, -3, -9, 4, -12, -7, 3, 20, 18, 35, 26, 7, -6, -48, -12, 3, -6, -16, -14, -24, -29, -25, 10, 26, 29, 23, 2, -34, -1, -4, 9, -21, -22, -21, -32, -7, -10, -13, 21, 33, 17, -28, -2, 0, 0, -16, -17, 2, 9, -2, -20, -14, 17, 24, 8, -9, 0, 2, -5, 17, 11, 6, -4, -20, -12, 9, 13, 12, 1, -5, 4, 1, 3, 27, 15, -6, -12, -21, -12, 7, 4, -7, 7, -6, -1, 1, 0, 13, 4, 3, -2, -5, 6, 5, 3, -7, -9, -10, 12, -4, 13, 11, 13, 11, 15, 13, 5, -3, -3, -14, -24, -6, 1, 4, 18, -6, 11, 13, 11, 6, -1, -2, -21, -24, -3, 7, 4, 4, 15, 38, 39, 17, 23, -1, -14, -7, -18, 32, 1, -3, 2, -2, -1, 2, -8, 18, 17, -1, 23, 14, 3, 16, 3, -2, -4, 1, 4, 4, 0, 2, -4, 5, 0, -1, -4, 3, -2, -3, -1, 2, 3, 3, 17, 12, 7, 17, 4, -13, -1, 10, 28, -6, -2, 1, 4, 5, 8, 13, 0, 16, 5, -4, 5, -4, 9, 3, -1, 1, 15, 9, 8, -3, -4, -7, -28, -9, -1, -5, -9, -17, 7, 3, 14, 26, 17, 16, 18, 4, -22, -4, 8, 7, 4, -11, 1, 14, 18, 13, 9, 24, 36, -3, -24, 16, 18, 10, 10, -17, 4, 2, 29, 18, 36, 25, 21, -40, -40, 16, 2, 9, 30, -6, 9, 4, 29, 10, 32, 20, -15, -38, -31, -7, -9, 10, 38, 3, -4, 4, 2, 12, 28, 28, -16, -39, -16, -7, 1, 18, 11, -1, -4, -2, 6, -4, -17, 19, -1, -28, -1, 5, 20, 16, -6, 14, -10, 3, -23, -24, -28, -16, 0, 0, 3, 16, 6, -2, -11, -13, -1, 2, -15, -28, -30, -35, -2, 10, 14, 19, 3, -7, -24, -11, -2, 4, -12, -2, 1, 6, 4, 0, -4, 0, -4, -5, -26, -2, 4, 0, 1, 1, 24, -3, 15, 4, 9, 2, 13, 5, 1, -3, -3, -4, 1, -2, 2, 3, 1, 18, 4, -4, 0, -3, -4, -2, 1, -2, -3, -5, 27, 14, 26, 18, 27, 10, 20, 33, 36, -12, 2, -2, 3, -7, -13, -9, 0, 3, 14, 14, 21, 15, 6, 0, -4, -1, -1, -49, -18, -10, 1, 14, 13, 8, 8, -18, -13, -10, 17, 3, -1, -30, -4, 7, 20, 20, 14, -11, -32, -44, -48, -39, 3, -3, -1, -22, 10, 8, 5, -3, -6, -32, -23, -8, -10, -19, -2, 1, -3, -22, 6, -3, -10, -7, -2, -23, -1, 14, 23, 12, 16, -3, 6, -26, -14, -3, 4, 12, 6, -18, -7, -3, 8, 10, -2, 2, -10, -10, -7, 1, 12, 8, -4, -21, -12, -6, -4, 21, -1, -4, -6, -18, -14, -9, 9, 16, -4, 7, -1, 5, 13, 28, -15, -4, 0, 2, -11, 2, 18, 22, 19, 3, 9, 9, 13, 17, -4, -3, 7, -1, -7, -7, 2, 10, 2, -1, -7, -6, -4, -13, 0, 4, 1, -17, -57, -60, -67, -61, -59, -47, -39, -26, 12, 3, 1, 0, -2, 1, -8, -2, 13, -8, -15, -2, -14, -18, 3, -2, 2, -1, 0, 1, 4, -2, -2, 1, -1, -2, 1, 4, 1, -3, -2, 1, 1, -3, 5, 16, 19, 6, -17, -28, -25, -17, -4, 2, 4, -4, 0, -8, 15, 26, 33, 22, 10, 5, 2, 5, -4, 20, 2, -4, -5, -7, 6, 19, 14, 25, 25, 34, 24, 15, 7, -11, 9, -4, 13, 1, -7, -2, 15, 31, 35, 33, 16, 4, 1, -19, -10, 12, 8, -21, -13, -5, 3, -12, -41, -17, -4, -15, -7, -15, -3, -1, 7, -31, -15, -1, -6, -31, -39, -23, -8, -14, -19, -10, -10, 4, 6, -24, -5, 2, 0, -13, -16, -26, -29, -28, -29, 10, 2, -4, -7, -16, -19, -10, 6, -9, -22, -29, -23, -14, -13, 23, 4, 1, -14, 3, -13, -5, -4, -13, -10, 1, 3, 7, 10, 6, 8, -1, 17, 15, 7, 7, 23, 28, 31, 24, 17, 19, 20, 5, -3, 4, 16, 1, 14, 26, 37, 37, 29, 24, 20, 12, 39, 6, 3, 0, 5, 0, -10, 2, 5, 0, 5, 15, 8, -14, 4, 0, -3, 3, 3, 1, -7, 13, -11, 12, -1, 14, -14, -20, 3, -1, -4, 4, -3, -1, -2, -1, -4, -4, -9, 0, 0, 1, -3, -5, -4, 1, 4, 4, 6, 12, 17, 29, -4, 28, 8, 28, 10, -5, 0, -4, -2, 22, 17, 25, 23, 8, 10, 33, 38, 21, 14, 12, 2, -4, -12, 23, 17, 19, -2, -6, -3, 3, 9, 8, 27, 61, 14, 3, -2, 10, -3, 3, -6, -7, -19, -15, 2, 10, 5, 27, -2, -7, -1, -5, -8, -10, -12, 1, -13, -9, 2, -26, -15, 27, -2, -4, -12, -25, -6, 5, 24, 22, 10, 10, 5, -19, -29, -1, 15, 4, -26, -6, 4, 14, 20, 24, 31, 22, 14, -6, -9, 10, -2, 3, 30, 3, -15, -7, -4, 19, 15, 19, 15, 17, 19, -4, 0, 4, 26, 15, 12, -7, -18, -5, 4, 24, 24, 25, 23, -2, 3, 0, 23, 15, -8, 2, 0, 7, 26, 25, 19, 29, 17, -27, -2, 4, 13, 11, -12, 4, 14, 8, 6, 15, 29, 16, 9, 10, 1, 2, 9, -5, -14, -12, 6, 2, 2, -1, -5, -15, -3, 0, 3, 0, -1, 4, -11, 6, -10, 16, -20, -15, -10, -20, -4, 4, 2, -2, -1, -1, 4, 4, 1, -4, -2, -3, 4, 0, -3, -3, 2, 4, -4, -3, -2, -27, -36, -30, 8, -3, 5, -20, -12, -17, -3, -2, 3, 4, -20, -33, -19, -5, -5, -5, 1, 6, 4, 13, 2, 5, 1, -11, -28, -48, -15, 6, 7, -6, 2, 1, 26, 2, -8, 3, 8, -6, -11, -29, -12, -1, 14, 22, 17, 20, 25, 29, -6, 13, 20, 1, -18, -11, -6, 16, 26, 3, -1, -11, 14, 45, 2, 0, 29, 8, 4, 4, -3, 11, 4, -29, -34, -61, -57, -23, -5, 0, 22, -10, -6, 0, -12, -10, -9, -15, -4, -24, -36, -21, 1, -4, -7, 2, -7, -31, -30, -7, -8, 7, 6, -33, -43, -10, 3, -1, 4, 1, 31, 11, -6, 21, 10, 24, 8, -39, -21, 1, -7, -1, -10, -3, 4, 12, 4, 15, 11, -1, -11, -34, -12, 4, 4, -2, -6, -12, -16, -5, 9, 4, 4, -14, -25, -27, -19, -6, -4, -4, 2, 9, -16, 2, 0, 10, -7, -15, 5, -2, 3, -2, -4, -1, -4, -4, 33, 0, -1, 19, 13, 7, 5, -15, -3, 2, 1, 2, -1, -3, 4, 4, 3, 10, 1, 0, 0, -3, -3, -2, 1, -2, 2, -4, 14, 3, -6, -2, -22, -10, 10, 24, 33, -10, -2, 2, 4, 13, -12, -1, -14, -10, -10, 4, 8, 5, 18, 28, 3, 1, 15, -1, -2, 10, 0, 1, 1, 3, 4, 3, 13, 54, 11, -1, 4, -3, 4, 18, 2, -2, -7, -12, 3, 14, 28, 42, 2, 9, 14, 8, 21, 20, 7, 16, 4, -6, 7, 23, 39, 58, -4, -2, 16, 23, 38, 26, 30, 22, -2, 3, 6, 8, 13, -7, 14, 1, 24, -13, -2, 3, 16, 9, 5, 3, 16, 6, 14, -3, -1, 4, -5, -8, 3, -8, 3, -6, -1, 13, 12, 2, -1, -19, 0, 3, 1, -5, 6, 0, -3, -1, 10, 8, -4, -12, -16, -29, -11, 4, -21, -17, -10, 2, 15, 19, 20, -6, -24, -18, -21, -29, -2, -2, -18, -11, -14, 0, 10, 22, 23, 3, -13, -22, -12, 3, 4, 2, -11, 3, 12, 24, 33, 27, 5, -1, 3, -4, 7, 3, 1, 2, 1, -2, 19, -1, 3, 14, 9, 2, 11, -10, -3, -1, 2, 0, -3, 4, 0, 4, 4, 10, 2, 3, -4, -1, 2, -3, 0, 1, 4, 0, 34, 21, 28, 34, 29, 9, 4, 14, 30, 0, -4, 0, 1, 14, 12, 11, 6, -11, -22, -28, -33, -30, -3, -5, 0, 4, 13, 33, 18, 14, 5, -2, 4, -15, -38, -39, -43, -33, -2, 0, 7, 31, 2, 6, 1, 24, 31, -20, -35, -25, -25, -16, 4, 7, 12, 7, 7, 1, 4, 12, 1, -10, -5, 7, -11, -49, 4, 3, 19, 8, -7, -5, -10, -5, 11, 12, 17, 26, 17, -16, 9, -1, 24, -4, -2, -4, -3, 0, 17, 24, 24, 28, 20, 16, -4, 1, 14, 10, 7, -16, 1, -5, 27, 17, 13, 23, 7, 18, 1, -1, -7, 0, -19, -36, -26, 5, 33, 15, 8, 0, -9, -5, -4, 1, 20, -25, -34, -34, -23, 23, 27, -8, -12, -20, -27, -10, 0, 1, -16, -9, -39, -33, -13, -11, -12, -21, -21, -31, -16, -8, 0, 2, -10, 2, -2, 14, 14, 8, 9, 4, 3, 9, -24, 2, 4, 1, -1, 3, 22, 4, 13, -1, 11, 10, 7, 23, -3, 0, -2, 3, 1, 0, -3, -1, 2, -16, 3, 1, -4, 1, 2, -4, 5, 4, 1, -1, -33, -15, -12, -8, -5, -16, -20, -26, -27, 12, -2, 1, -1, -3, -3, -5, -4, 0, 12, 20, 15, 2, 13, -12, 4, -3, -7, 9, 0, -11, 3, 8, 2, -3, 15, 12, 10, -16, 8, -4, -4, 9, -6, -6, 6, 4, -15, 3, 17, 2, 2, 11, -6, -13, -25, 4, 6, -8, -2, -4, -58, -12, 0, -5, -2, -17, -2, 4, -13, 7, -4, -7, -17, -22, -60, -28, 3, -1, 10, -11, -16, 4, -26, 27, 19, 25, 0, -15, -40, -6, 21, 21, 22, 15, -1, 2, -4, 3, 24, 38, 29, -6, -1, 34, 28, 26, 6, 20, 0, 1, -5, 8, 28, 20, 6, -10, 9, 18, 20, 9, -7, -1, 10, 1, 12, 21, 15, 17, -2, -9, 1, 7, 4, 5, 10, 2, 4, 0, 8, -13, -6, 3, 14, 8, 1, -9, -3, 8, 8, -1, -3, -4, 9, -24, -38, -63, -51, -35, -30, -48, -30, -2, 1, 0, 0, 4, 3, 3, -10, -20, -2, -33, -39, -15, -2, 1, 0, 1, -2, -1, 1, 1, 0, -2, -4, 4, -8, 4, -3, -4, 3, 4, -4, 0, -4, -1, -13, -24, -20, -14, 9, -4, -3, -14, -24, -15, 4, -2, 3, -6, -2, 2, 6, 8, 6, 4, -6, -3, -11, 8, -3, 3, -13, -1, -4, 0, 20, 15, 13, 14, 10, 6, 3, 3, -14, 1, -27, 0, 12, 14, 11, 12, 17, 8, 15, 15, 23, 12, 3, -6, 0, 10, 9, 7, -9, 7, 21, 0, 6, 15, 26, 18, -1, 1, -13, 3, 1, -13, -9, 24, 14, -13, -12, -7, -6, 5, -4, -4, 5, -10, -4, -16, -11, 21, 10, -23, -22, -12, -2, -9, -2, -2, -8, -4, -10, 2, 3, 5, -6, -21, -16, -8, 11, -3, 4, 2, 2, 18, 24, 14, -4, -19, -14, -12, 5, 13, 19, -8, -3, 0, -7, 12, 31, 16, -5, -15, -7, 0, 20, 23, 7, 4, 0, -3, 15, 1, 11, 7, 8, 19, 22, 17, 9, 3, -1, 10, -2, 0, 16, -15, -11, 5, 11, 12, 6, 6, 5, -7, 9, -4, -4, -4, 4, -3, -16, 5, -16, 23, 7, 2, -2, -22, 0, 2, -2, -2, 4, -2, -2, -1, 0, 5, 9, -2, -2, -3, 2, -2, 1, -1, 1, 0, 26, 38, 40, 28, -2, 30, 17, 25, 30, 10, -4, 3, -1, 13, 20, 11, 11, 6, 8, 3, 7, -1, -5, 19, -2, -4, -4, 2, -13, -23, -32, -27, -7, -8, -14, -21, -12, 25, 23, 3, -3, -8, -29, -19, -22, -22, -2, 3, -10, -2, -7, 21, -4, -1, -20, -24, -9, -19, -20, 7, 19, 13, 3, 11, 3, 3, 3, 2, -17, -33, -10, -8, 15, 30, -7, -13, -18, -24, -5, 14, -4, -1, -10, 10, 24, 24, 30, 21, -1, 17, 3, 6, 26, 27, 2, 4, -11, 29, 21, 15, 6, 1, 18, 41, 22, 19, 27, 16, 0, -4, 2, 13, 26, 17, 14, 13, 26, 28, 14, 8, 18, 27, 14, 3, 20, 5, -8, 8, 6, -2, -8, -6, 4, -4, 5, 3, -2, 4, 7, -4, -32, -27, -26, -41, -50, -50, -42, -30, -18, -9, 3, -3, -3, -8, -51, -61, -60, -78, -48, -44, -36, -51, 0, -3, 1, -4, -1, -2, -8, -13, -19, -25, -19, -8, -18, -16, -3, 4, -1, 3, 0, -1, 2, 0, -2, -11, 1, 4, -1, 4, -3, -3, 2, -4, 2, 3, 6, 0, 3, 8, 12, 13, -8, -18, -25, 16, 3, 0, 3, -11, 5, 12, 30, 26, 25, 17, 4, 5, -26, -7, -1, -1, -17, -10, -14, 4, 15, 15, 23, 18, 15, 2, -14, -5, -19, -4, -22, -13, -4, -6, 0, 7, 7, -3, 2, -1, 3, -6, 2, -13, -21, 8, 8, 0, -1, -21, -6, -7, 3, 0, 5, 1, -2, -3, -21, 3, -9, -2, -18, 14, 32, 17, 8, 6, -1, 9, -10, 3, -21, -14, -8, -15, -7, 28, 21, 0, -11, -23, -44, -9, -2, -3, -1, 2, -8, -5, 5, 19, 7, -2, -20, -18, -11, 18, 2, 4, -4, 16, 11, 22, 3, -4, 9, 7, 15, 23, 25, 10, 15, -4, 17, 25, 45, 20, -4, -8, -1, 12, 27, 23, 24, 18, -1, -2, 16, 8, 11, 16, 9, 6, 7, 9, 20, 31, 31, 1, 5, 0, 10, -24, -15, -5, 5, 15, 15, 22, 16, 10, 14, 3, 0, -3, -4, -4, -26, 7, -4, 7, 3, 3, -8, -5, -4, 3, -4, 4, 2, -4, 1, -3, 1, -19, 3, 1, -1, 2, -4, 1, 0, 2, -3, 0, -26, -35, -35, -46, -43, -15, -17, -47, -30, 10, 3, -1, -4, 14, -19, -52, -43, -53, -45, -29, -18, -12, -14, -2, -1, -1, -17, -13, -19, 11, 1, 15, 23, 13, 0, -10, -20, 0, -9, -3, -16, -32, 0, 13, 11, 8, 2, -1, -8, -4, -11, -4, 6, -8, -31, 2, 22, 19, -7, -46, -31, -14, 3, 6, 8, -7, -3, -3, -15, 19, 17, 11, 0, -9, 8, 22, 14, 22, 7, 2, -1, -2, -25, 23, 31, 29, 21, 32, 24, 28, 20, 0, -14, -17, -3, -3, 9, 12, 23, 20, 17, 18, 18, 28, 3, -3, -12, -23, 4, 3, 14, 5, 10, -20, -26, -19, -7, -8, -3, 0, -10, -10, -1, -1, 4, -10, -17, -28, -28, -18, -17, -16, -13, 9, 0, -16, -1, 0, 9, -13, -21, -12, 0, -10, -6, -5, 9, 10, 42, 8, 4, -3, 11, 6, 15, 6, 25, 17, 14, 21, 14, 31, 10, -2, -3, 0, -1, 2, -31, -13, -3, -26, -20, -12, -11, 15, -1, 2, 0, 2, 2, -4, -4, 3, -2, 0, 3, 3, -2, -3, 2, -3, 1, 0, 2, 4, -16, 3, -10, -29, -13, -10, 1, -38, -12, 7, 1, 1, -3, -7, -31, -34, -21, -15, -29, -42, -50, -36, -32, 2, 4, -2, 14, -16, 6, -9, -12, -37, -52, -27, -17, -6, -6, -19, -13, -1, 8, -8, 4, 12, 17, 35, 40, 31, 22, 18, 7, 13, -6, 11, 4, 16, 21, 19, 30, 49, 37, 10, 11, -4, -8, 26, -2, -2, 10, 21, 2, 5, -16, -19, -13, -18, -10, -15, -24, 3, -14, 3, 29, -4, -11, -6, -5, -7, -15, -11, 0, -2, -8, 9, 3, -2, -16, -24, -22, 1, -4, -11, -11, 11, -1, 10, 5, 22, -3, -2, -17, -12, -8, -5, -12, -3, 6, 5, 7, 6, 12, 40, -3, -4, -8, 3, -7, -5, 2, 4, -3, -8, -13, -6, 1, 13, -3, 5, -19, 23, 15, 9, -4, -7, -12, -9, -15, -3, 5, 14, -3, 2, -16, 6, 6, 9, 1, 7, 15, 23, 22, 6, 18, -2, -4, -2, -3, -3, 25, 1, 19, 5, 37, 22, 21, 4, -4, -4, 2, -2, 3, 2, -3, 1, 3, 16, 8, 2, -5, -2, 0, -4, -1, 1, 4, 1, 31, 32, 39, 23, 5, 20, 16, 34, 31, 2, 0, 4, -4, 11, 5, 17, 22, 13, 13, 6, -5, 2, 4, 14, 2, 4, 2, 17, 12, 16, 8, -10, -34, -25, -24, -23, 2, 29, 10, -3, 10, 9, 9, 10, -3, -40, -52, -26, -14, -12, -3, 4, 2, 4, -2, 5, -3, 15, 12, -21, -19, 1, 0, 2, 0, 1, -2, -3, -2, -6, -8, 9, 15, 10, 5, -1, 9, 19, 10, 29, 13, 0, -4, 0, 6, 5, 6, 21, 29, 13, 14, 11, 20, 8, -2, -1, 7, 5, 21, -4, -14, 19, 21, 16, 8, 2, 7, 16, 4, 3, 7, -5, 2, -12, -10, 23, 8, 3, -7, -5, 8, 19, 2, -3, 2, -7, -16, -7, 6, 22, 7, 1, 2, 11, 0, -11, 4, 0, 3, -12, -28, -18, -15, 2, 4, 3, -5, -9, -11, -6, -3, -2, 0, -7, -24, -58, -47, -34, -31, -21, -30, -37, -10, -1, 1, -4, 2, -3, -1, 4, -13, -3, -7, 8, 4, -5, 3, 1, -4, 3, 1, 3, 3, -4, 2, 1, 5, 1, 3, 1, 1, 3, 0, -3, -2, 0, 1, 7, 22, 21, 24, 12, -4, -11, -11, 16, -3, 1, 1, 3, 15, 32, 35, 25, 18, 22, 29, 18, -7, 8, -1, -3, -14, 1, -6, -4, 4, 7, 13, 16, 18, 19, 24, 12, -7, 2, -17, 0, -3, 1, -4, 0, -3, 7, 14, 10, 28, 21, 6, -2, 2, -7, -17, -14, -9, 1, 6, 0, -5, -11, 8, 22, -3, 4, -15, -23, -31, -11, -2, 19, 9, -12, -16, -27, -36, 3, -15, 1, -14, -10, -11, 3, -2, 15, -3, -20, -17, -25, -25, 1, -1, 2, 1, 4, -25, -12, -5, -1, -30, -14, -9, -1, 19, 22, 3, 0, 10, 3, 10, -4, -12, -14, -15, 3, 21, 25, 42, 21, 11, 2, 18, 14, 22, 7, 12, 13, 12, 16, 28, 37, 31, 12, 4, 1, 22, 7, 17, 27, 29, 36, 32, 28, 15, 13, 21, 13, 1, -1, 17, -13, -9, -8, -5, -4, -2, -11, -15, -29, 2, 3, -2, 0, 4, 4, -6, 9, -10, 11, -5, -12, -20, -2, 0, 0, 1, -4, 0, 1, 3, -2, 3, -13, 2, -4, 0, -4, 0, 1, 4, 4, -4, 2, -37, -38, -50, -35, -53, -35, -50, -31, -28, -7, 2, 4, -1, -9, -4, -17, -12, -6, -18, -27, -38, -43, -15, -7, 3, -2, 10, 6, 0, 15, 10, 14, 18, 6, -9, -26, -27, 3, -17, 3, -1, 5, 8, 11, 2, 11, 9, 22, 6, 1, -3, -1, -1, 2, -2, 9, 17, 14, -2, -2, 1, 19, 9, 16, 6, 1, 4, 1, 7, 24, 15, 4, 23, 0, 12, 29, 13, 3, 0, -16, -6, -4, -3, 16, 3, 6, 19, 16, 9, 17, 19, 0, 4, -6, -3, -2, 17, 0, -2, 7, 7, -3, -10, 18, 13, 4, -2, -30, 2, -1, 9, -19, -29, -19, -14, -22, -18, 9, 7, -1, -12, -38, 0, -3, -10, -16, -23, -25, -19, -25, -5, 1, -4, -8, -25, -21, -2, -1, -21, -1, -2, -6, 8, 22, 15, 5, -1, -5, 11, 1, -4, 4, -17, 26, 46, 31, 43, 25, 11, 12, 15, 41, 5, -4, 4, -2, 0, -4, 5, -8, 14, -11, 1, -4, 3, 26, 2, 2, -2, -1, -3, -2, -1, 2, 4, -8, 6, -2, -3, 4, 2, -1, 0, 4, 2, 1, 10, 4, -2, 3, 11, -2, -31, -28, -10, -1, -3, -2, -2, -4, 15, 16, 15, 8, 10, -14, -23, -21, -17, -29, 4, -3, 11, 4, 1, -4, 2, 21, 37, 26, 3, -7, -26, -18, -6, -4, 6, 4, -2, 2, 8, 2, 21, 16, 9, -11, -23, -18, 1, 13, 16, -12, -7, -6, -14, -47, -14, 13, 30, 16, -24, -37, 3, -2, -2, -31, -24, -26, -26, -47, 13, 16, 26, -13, -36, -20, -1, 0, 17, -25, -9, -23, -18, -6, 13, 9, -6, -34, -42, -16, -1, -2, 24, -10, -13, -19, -5, 11, 3, -6, -18, -34, -33, 2, -1, 2, -3, -14, -21, 5, 5, 14, 4, -2, -9, -14, 8, 14, 8, 4, 37, 6, 0, 9, 10, 2, -6, -1, 4, 15, 17, 25, -4, 2, 24, 23, 15, 19, 8, 7, 9, 1, 0, 9, 16, -2, 2, 0, 5, 37, 36, 25, 7, 15, 11, 11, 6, 30, 2, 0, 4, 4, 4, -3, 17, 29, 7, 10, 20, 42, 11, 17, -3, 1, -4, 1, 2, -4, 3, -3, 2, 14, -11, 4, -4, -3, 4, -3, -1, -2, 4, -1, 17, -4, -8, 6, 17, 23, 23, 31, 28, -5, -4, -1, -4, 8, -12, -11, 3, 1, 5, 16, 21, 20, 28, 28, 4, -3, 15, -16, -13, 3, 13, 14, 23, 22, 29, 32, 27, 33, 7, 3, -3, -13, -13, 12, 19, 16, 6, -20, -37, -31, -44, 6, -4, 8, -2, 3, 0, -1, 7, -4, -31, -38, -63, -86, -76, -20, -4, -4, 2, 18, 8, -7, -9, -11, 7, 19, 18, -6, -45, -29, 12, 4, 7, -8, -14, 0, -12, -14, -6, 12, 24, 17, -12, -15, 4, -1, 9, 0, -3, 2, 15, 7, -14, 3, 24, 17, -9, -24, 2, 1, 5, 16, 8, -1, -5, -14, -16, 11, 23, 7, -14, -8, -3, -4, -15, 3, -3, -3, -10, -7, 10, 15, 15, 7, 1, -2, -2, -1, -19, 6, -18, -11, -5, 1, 10, 12, 6, 8, 14, 6, 3, 0, -14, 0, 17, 43, 40, 32, 25, 28, 31, 41, 36, -1, -2, -2, -3, 0, 7, 5, 21, 11, 16, 17, 2, -12, -5, -3, 2, 1, 3, -4, 3, -5, -2, -4, 4, 1, 0, 0, -3, -4, -2, 0, 3, 0, -25, -21, -14, -18, 11, -7, -31, -30, -5, 5, -4, 3, -3, -5, 13, 11, 9, 9, 14, 2, -8, -28, -49, -4, -2, -2, 5, 26, 22, 8, 7, 5, -2, 4, 0, 1, -44, -20, -9, 4, 9, 47, 25, 0, -8, 2, 20, 18, 18, -8, -36, -34, 5, 9, 36, 25, 3, -12, -3, 17, 42, 16, 6, -10, -18, -35, 0, -1, 19, 7, -26, -6, -18, 0, 28, 9, -14, -22, -25, -11, -2, 3, 28, -35, -38, -31, -42, -6, 32, 7, 2, 2, -11, 22, 0, 1, 24, -23, -48, -23, -42, 21, 28, 3, 7, 9, 7, 10, 4, 3, 2, -16, -31, -13, -20, -5, 4, 3, 4, 9, 4, -2, 4, -1, 13, 1, -3, -5, -3, -5, 7, 8, 18, 3, -11, 4, 2, -3, 7, 22, 7, 1, -1, 3, 17, 20, 17, -1, -31, 12, 2, 4, 14, 26, 32, 27, 14, 4, 7, 7, 11, -9, -40, 2, -3, -4, -1, 0, 21, 24, 7, 23, 5, 20, 11, -3, 2, 4, 1, 1, 4, -1, 1, 2, 0, -12, 5, 0, 0, -3, -1, 4, -3, 1, 4, -4, 7, -4, 2, 16, 30, 31, -2, 4, -24, 7, 0, 3, -2, -8, 11, -1, -4, -10, 11, 19, 14, 6, -11, 15, -3, -1, 12, 16, 15, 21, 21, 10, 7, 8, 15, 19, -6, -52, -11, 4, 22, 6, 6, 22, 16, 8, 5, 11, 16, 4, 7, -30, 3, 0, 29, -26, -23, -47, -72, -104, -17, 14, -8, -8, -18, -23, 0, 3, -8, -63, -91, -97, -68, -19, 22, 3, -7, -13, -11, 5, -8, -2, 1, -28, -19, -13, 6, 27, 19, 5, 12, 14, 11, 24, 3, -1, 30, 17, 15, 11, 16, 13, 9, 3, 3, 6, -6, 4, 3, 4, 29, 18, 22, 5, 1, 10, 5, 4, 1, -13, -12, 5, 0, -3, 35, 18, 14, 5, 4, 7, 4, 0, -3, -8, 0, 36, -4, -4, -5, 41, 13, -5, -9, -4, -1, -5, 1, -4, -9, -3, 1, 0, -7, 35, 12, 17, 18, 24, -2, 2, -34, -23, -13, -1, -3, -4, 2, 3, 23, 5, 2, 16, 33, 26, 8, -4, 2, -4, -2, 1, 2, -3, 3, -4, 3, -9, -5, 3, 2, -2, 1, -2, 0, 1, -2, -3, -30, -26, -28, -35, -29, -5, -8, -28, -34, 2, 3, 2, -2, -10, 0, -7, 3, 4, 2, 4, -7, -9, -3, 0, -1, -4, -12, 6, 14, 1, -14, -3, 1, 3, 11, 13, 18, 13, -15, 2, -1, -3, -4, -1, -5, -2, 1, 4, 20, 17, 16, 29, -6, -2, 3, -9, 5, 12, 5, 18, 13, 7, 11, -7, -4, 42, -3, -2, -11, -4, 9, 3, 26, 17, -2, 0, 12, -11, -32, -23, -13, 1, -18, 27, 11, 17, 0, -7, -12, 3, 18, 5, 14, 1, -4, 2, 6, 29, 3, -2, -21, -27, -18, 10, 16, 23, 26, -6, -4, -3, 9, 20, 9, -12, -14, -7, -2, -1, 13, 19, 4, -6, 11, 0, 0, 4, -13, -6, -7, -1, -4, 4, -3, 13, 0, -13, -4, 2, 10, 1, -2, 11, 22, 8, 1, 6, 3, -13, 15, 11, 0, 2, 18, 37, 15, 19, 21, 4, -5, -11, -4, 8, 18, 1, -4, 2, 3, -3, -5, 2, -6, -14, -16, -6, -10, 1, 0, -1, -2, 2, -3, 3, 1, 2, 3, 1, 0, 2, -3, -4, -4, 1, 0, 0, 0, 5, -1, -13, -21, -31, 11, 21, 2, 3, -2, -3, -1, -1, -3, 8, 7, 5, 19, 18, 11, -10, -4, -8, -4, 24, -4, -1, -4, -10, -3, 9, 14, 14, 13, -3, 0, -11, 11, 27, 11, 1, -21, -16, -3, 1, 4, 13, 4, -21, -10, -2, -1, 16, -14, -3, -23, -10, -4, -1, 5, 15, -5, -23, -21, -20, -20, 5, 3, -2, -21, -13, -3, 13, 23, 14, 1, 5, -2, 1, -15, -29, 0, -4, -12, -21, -22, 5, 16, 11, 12, -3, -8, 5, 13, -5, -3, 0, 4, -53, -104, -106, -51, -30, 9, -5, -3, 9, 20, 14, -3, 1, 11, -4, -36, -58, -76, -69, 12, 2, 4, 14, 10, 23, 0, 2, -2, 26, 31, 20, 3, 12, 22, 14, 15, 10, 19, -5, 2, 4, 18, 40, 21, 25, 25, 7, 9, 9, -1, -7, -11, -17, 2, -3, 13, 19, 21, 47, 31, 15, -5, -3, -31, -22, 17, -4, -3, -3, -3, -4, -7, 4, 9, -9, 1, -6, -23, -4, -2, 1, 3, 1, -1, -1, 3, 4, -1, 12, 3, 2, 2, 2, 0, 1, -3, -1, -3, 2, 23, 7, 7, 5, 13, -3, 12, 30, 37, -10, -2, -2, 2, 16, -5, -2, -13, 0, -2, 7, 8, 19, 30, -7, 2, 4, 2, 4, -7, -10, -14, -5, -11, -7, 0, 6, 24, 9, 10, 3, -14, -11, -3, 0, 1, 4, -4, -1, -3, -2, -1, -20, 5, -4, -32, -24, 5, 7, 6, 4, -6, -9, -9, -19, -13, -37, -1, 0, -18, -21, 18, 22, 10, 1, 5, 3, 10, 16, 35, 1, 15, 3, -10, -16, 6, 22, 34, 27, 23, 11, 3, -12, -5, 5, -3, -4, -3, -35, -2, 23, 35, 21, 14, 4, -9, -19, -19, 9, 0, 4, -1, -12, -14, 9, 22, 17, 9, -1, -11, -13, -7, -8, -9, -3, -11, -9, -2, 4, 16, 13, 10, 0, 3, -7, -2, -9, -2, 1, 8, -20, -1, 6, 7, 8, 7, 8, 13, 9, -13, -11, -4, -2, -1, -35, -52, -39, -29, -24, -18, -22, -18, -15, -21, 3, -3, 2, 1, -5, -14, -18, -37, -12, -20, 4, 0, -23, 0, -2, -1, 3, 3, 0, -2, -3, 2, 18, 2, -1, -4, 1, 2, 1, -4, 0, 1, 2, 19, 9, 8, 16, -2, -3, 12, 34, 39, -15, -1, -2, -1, 5, 9, 16, 8, 8, 9, 11, 23, 15, -8, 2, -2, -1, -2, -17, -39, -25, -15, -6, 17, 16, 3, -8, -24, -3, 16, -3, -16, -26, -24, -9, 5, 18, 16, -3, -7, -7, -14, -19, 9, -2, -15, -31, 3, 1, -5, -8, -15, -19, 6, 10, 17, -10, -2, 0, -22, -18, 12, 5, -2, 38, 17, 9, 7, 23, 43, 8, 8, 4, -22, 2, -8, -3, 20, 26, 12, -4, -22, -1, -5, -4, 4, 3, 1, -22, -6, 9, 32, -8, -25, -14, -14, -6, -2, -15, -3, 0, -2, -16, 11, 15, 10, -27, -8, 5, 12, -1, 16, -32, -12, 1, -2, 0, 21, 15, 14, 19, 20, 10, 1, 0, -9, -14, 0, 4, 17, -19, -7, 1, 7, 20, 7, -8, -13, -6, -13, -9, -4, -3, 18, -11, 1, 3, 11, 6, 2, 10, 3, 13, 13, 2, 1, 2, -2, -2, -15, 2, -6, 3, -4, 1, 9, -5, 4, 3, 0, -5, 3, 4, -4, 4, 4, -12, 1, 1, 0, -3, -1, -4, 1, 0, 0, 3, -8, -20, -32, -18, -16, -30, -4, -4, -6, -15, -1, -2, -3, 8, -20, -27, -25, 3, -6, -19, -17, 8, 20, -16, 4, 1, 10, -16, -18, -18, -3, 4, 9, 0, -5, -2, -6, 1, -6, 4, -7, -33, -23, -2, 13, 8, 0, 11, 2, -1, -20, -9, -5, -4, -31, -25, 2, 12, 11, -9, -6, 12, 11, -7, -23, -12, 2, 0, -13, 2, 17, 15, 5, 3, 21, 30, 9, -1, -13, -23, 1, -4, -26, 16, 12, 15, 12, -1, 11, 30, 9, -13, -30, -23, 0, 4, 6, -3, 22, 26, 10, -4, 10, 22, -6, -17, -31, -21, -1, 0, -14, -16, 3, -1, -8, 11, 15, 3, 4, -21, -22, -10, -4, 1, -13, -16, -12, -12, -25, -8, 5, 4, 6, 4, 0, 10, -1, -3, -17, -16, -15, -6, -10, -6, -7, 7, 19, 17, 19, -3, -2, -2, -16, 4, 2, 7, 6, -1, -5, 1, 13, 33, 10, -1, 4, 2, 0, 4, -24, -22, 2, -44, -18, -3, -5, 17, -1, 1, 3, -5, -3, -4, 4, 4, 1, 10, -2, 5, -4, 0, 2, 1, 0, 2, -2, -5, 8, -8, 2, 13, 19, -1, 15, 43, 29, -8, 0, 1, 2, 6, -15, -6, -19, -12, -13, 0, 5, 7, 25, 8, 0, 3, 1, -29, -20, -14, -26, -11, -3, 1, 5, 18, 32, 29, 23, -1, -9, -41, -16, -23, -13, 16, 21, 8, 8, 7, 5, 28, -7, -4, -22, -11, -23, -3, 2, 9, 6, -8, -33, -31, -15, 10, 0, 2, -9, 1, -5, -5, 0, -3, 20, 10, -46, -34, -38, -8, 1, 3, -9, 0, -7, 5, 3, 8, 24, 8, -37, -33, -32, -17, 1, 0, -5, -7, -8, 8, 17, 24, 13, -20, -36, -19, -24, 8, 4, 0, -14, -16, -3, 10, 24, 34, 1, -26, -12, -12, 5, 25, -3, -1, -9, -24, -8, 2, 16, 10, -1, 5, 6, 2, 5, 34, -2, -1, 9, -13, -14, -1, 2, -6, -3, 4, 10, 15, 1, 10, 4, -3, 1, -11, -24, -8, -3, -9, -10, -17, -9, 7, 11, 4, 3, 2, 2, 3, -24, -13, -7, -22, 0, -2, -12, 4, 3, -3, -2, -3, 1, 2, -1, 0, -3, 0, -1, -3, 2, 1, 1, 4, 1, -5, 1, -4, 27, 41, 41, 12, -16, 20, 7, 18, 13, -4, 2, -3, 1, -3, -20, -8, 3, 8, 10, 6, 10, -3, 5, 21, -4, 4, 11, -8, -13, 9, 23, 34, 37, 25, 9, 2, -15, 0, 4, -3, 8, -3, 13, 19, 22, 15, -3, -15, -10, -28, -29, -14, 8, 2, 8, 19, 36, 25, 5, -25, -30, -22, -14, -20, -1, 0, -1, -3, 5, 17, 15, -1, -11, -17, -11, -2, -6, 3, 25, 11, -10, -3, 18, -21, -9, -14, -9, -15, 4, 4, -5, -3, 7, 22, 1, 2, -28, -24, -14, -1, 1, -11, -3, -2, -3, -6, -10, 30, 0, 3, -18, -18, -8, 6, 23, -8, -4, -4, -4, 2, 7, 12, 12, -3, 2, -5, 13, 21, 19, 9, 3, -8, -4, -3, 12, -1, 4, 0, -17, -1, 7, 4, 14, 19, 21, 9, 6, 6, 21, 7, -1, 3, -11, -6, -6, 1, 6, 2, 8, 6, 23, 4, 18, 0, 3, -4, 2, -4, 19, 2, 5, -6, 24, 21, 17, -12, -5, 0, 3, 3, -1, -3, 0, 4, -4, -5, -1, 0, -4, 3, -2, 3, -3, 2, -3, -2, -7, -15, -39, -45, -22, -50, -37, -30, -17, -3, -1, -3, -4, 4, -6, -27, -43, -29, -23, -19, -25, -13, -20, -16, -4, -1, 8, -13, -16, -27, -11, -6, -7, -8, -2, 10, 21, 7, -20, 0, 3, -21, -20, -9, 10, 19, 4, -1, 14, 17, 30, 18, 6, -7, -10, -22, -34, 2, 11, -4, 1, -1, 1, 11, 27, 37, -1, -1, 4, -15, 1, 18, 19, 10, 19, -1, -22, 2, 8, 13, -4, -3, -1, -3, -18, 6, 3, 21, 41, 11, -31, -28, -20, -21, 0, 2, -10, -39, -37, -16, -3, 21, 34, 9, -48, -32, -30, -36, -2, -4, -12, -36, -20, -16, -15, 5, 21, -1, -40, -53, -46, -27, 2, 4, -10, -42, -5, -6, -10, -1, 4, -15, -32, -55, -33, -9, 4, 1, -7, -10, 7, 4, 17, 16, 15, -2, -25, -30, -24, -5, 3, 0, -7, -10, -2, 9, 19, 3, 10, -1, 14, 22, 2, 3, -4, 4, 1, 3, 2, -17, 1, -16, 2, 4, 3, 0, -2, -3, 1, -2, -4, 1, 1, 2, -2, 2, 4, 3, -2, 1, 2, 2, 4, 4, 3, -4, -20, -17, -17, -32, -49, -54, -42, -44, -34, 15, 0, -3, -2, -5, -21, -24, -23, -26, -36, -30, -28, -26, -22, -7, 0, 3, 13, -8, -30, -16, 12, 12, 14, 18, 18, 9, 0, -4, -12, -1, 6, -17, -8, -1, 22, 27, 27, 28, 24, 12, 26, 30, 3, 3, 2, 5, 19, 17, 23, 18, -2, 7, 2, 2, 17, 24, 0, 0, 14, 22, 8, 3, 16, 11, -12, -22, 7, 5, 11, 12, -5, 2, 23, 5, 19, 4, 3, -6, -11, -16, 7, 3, 18, 7, -2, -2, -26, 10, 14, 1, -4, -14, 7, 13, 0, -5, 19, 10, 4, 1, -27, 20, 5, -8, -20, -10, 14, -10, -10, -19, -7, -6, -2, 0, -19, 13, 17, -2, -17, -3, -11, -27, -29, -25, -20, -13, 0, 3, -20, -18, 22, 28, 28, 4, -13, -25, -32, -34, -3, 10, -1, -4, -16, 7, 11, 6, 21, 15, 21, 2, 2, 1, 15, -2, -3, 2, -1, 2, 22, -4, 6, 0, 13, 8, 8, 6, -1, 3, 0

L1_BIASES:
    .byte 2, -2, -7, 14, 26, 1, 0, 37, 5, 20, 17, 21, 20, 0, 5, 18, 4, 16, 2, 14, 0, 7, -14, 15, 5, 7, 7, 21, 22, 4, 23, -1    

L2_WEIGHTS:
    .byte 30, -22, 23, 24, 7, 43, -31, 7, 11, -14, 20, 12, 11, -30, -61, -18, -25, 18, 0, -14, -23, -57, -45, 14, -53, 13, 15, -25, -59, 27, -55, 34, 37, -26, -46, -12, 34, -38, -24, 35, -43, 16, 3, 24, -50, 16, -84, -28, -35, 23, -65, 28, -13, 26, -5, -50, 76, 10, -10, -7, 23, -42, 11, -82, -64, 22, 14, -56, 5, 44, 9, -61, -30, 19, 25, -17, 50, 25, 2, 40, 19, 17, -21, 35, -79, 7, 35, -10, -54, -5, -8, -22, 13, 13, -69, 5, -12, -16, 27, -31, -29, -5, 19, 10, 1, -12, -48, 16, 6, 2, 10, -8, -41, 26, 7, 21, 1, 35, 51, 17, 27, -33, 12, -38, -77, -39, -20, -15, 27, 15, -46, 15, -36, -83, 26, -53, 10, -8, 52, -40, -15, -24, 11, -97, -3, -30, 15, -65, -32, 0, -71, 25, 1, 23, -40, 27, 20, -65, 31, 0, -37, -9, -38, -6, -3, 9, 5, 53, 17, -85, -32, 8, 21, -6, 0, 43, 28, 6, -10, -63, 67, -37, -5, 13, 57, -28, -11, -10, 9, 22, 10, 7, -14, -41, -36, 20, 36, -4, 11, 3, 20, 48, -7, -13, 27, -23, -51, -104, 37, 7, -39, -33, 24, -49, -39, -36, -63, 31, 27, -11, 21, 4, -54, -38, 13, 23, 23, 50, -35, 4, -38, -3, 24, 28, -47, -21, -59, -39, -13, 40, -9, -64, 16, 21, 12, 25, 72, 4, -41, -33, -55, -4, -3, 18, 1, 18, -49, 28, 0, -53, -8, -30, 13, -20, 21, -46, -40, 28, -61, 32, -3, -19, 35, 9, 2, -8, -22, 13, -44, -13, -76, 11, 24, -9, -5, 20, 16, 6, 27, -32, 29, -8, -53, -58, -20, -38, -2, 10, 29, -15, -76, 2, 28, 3, -58, -17, 20, 10, 11, -8, -92, 1, 22, -14, 13, 31, 22, 9, 19, 4

L2_BIASES:
    .byte -6, 12, -8, -5, -11, -2, 3, -9, -3, 8

# Hidden layer 1 output buffer
HIDDEN_ACTIVATIONS:
	.space 128	# 32 words 4 bytes each

OUTPUT_SCORES:
	.space 40	# 10 words 4 bytes each
