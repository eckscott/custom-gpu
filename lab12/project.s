
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
	.eqv END_OF_ROW1         0x8EAC   # row 7 (top canvas row)
	.eqv END_OF_ROW2		 0x90AC   # row 8
	.eqv END_OF_ROW3		 0x92AC   # row 9
	.eqv END_OF_ROW4		 0x94AC   # row 10
	.eqv END_OF_ROW5		 0x96AC   # row 11
	.eqv END_OF_ROW6		 0x98AC   # row 12
	.eqv END_OF_ROW7		 0x9AAC   # row 13
	.eqv END_OF_ROW8		 0x9CAC   # row 14
	.eqv END_OF_ROW9		 0x9EAC   # row 15
	.eqv END_OF_ROW10		 0xA0AC   # row 16
	.eqv END_OF_ROW11		 0xA2AC   # row 17
	.eqv END_OF_ROW12		 0xA4AC   # row 18
	.eqv END_OF_ROW13		 0xA6AC   # row 19
	.eqv END_OF_ROW14		 0xA8AC   # row 20 (bottom canvas row)
	.eqv INC_ROW_OFFSET		 464   # offset to add to VGA address to advance one row
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
	la t2, L1_WEIGHTS	 # Pointer to start of L1 weights
	la s4, L1_BIASES	 # Pointer to L1 bias values
	la s5, HIDDEN_ACTIVATIONS # Pointer to store L1 outputs
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
	addi t1, t1, INC_ROW_OFFSET	# advance to next row (adjust for already adding 4 above)
	addi t1, t1, -8

INC_POINTERS:
	addi t1, t1, 8		# advance to next cell
	addi t2, t2, 1		# advance to next weight

	jal x0, NUERON_LOOP

NEURON_DONE: # ReLU
	bge t0, x0, STORE_ACTIVATION # if sum is positive, store it as activation
	addi t0, x0, 0		# if sum is negative, store 0 as activation

STORE_ACTIVATION:
	#srai t0, t0, 6		# Descale from Q2.6 fixed point format back to integer (divide by 64)
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
	la s1, L2_WEIGHTS	 # Pointer to start of L2 weights
	la s4, L2_BIASES	 # Pointer to L2 bias values
	la s7, OUTPUT_SCORES	 # Pointer to store L2 outputs
	addi s6, x0, 0		 # current digit

L2_NEURON:
	addi t1, x0, 0	    # current neuron 
	lb t0, 0(s4)  # accumulator (currently holds bias value)
	la s5, HIDDEN_ACTIVATIONS # Pointer to L1 outputs
	addi t2, x0, 32 	# Number of neurons in L2

L2_NEURON_LOOP:
	beq t1, t2, L2_NEURON_DONE

	lw a0, 0(s5) 		# Load L1 activation
	lb a1, 0(s1) 		# Load weight
	jal multiply
	add t0, t0, a0		# accumulate into sum

	addi s1, s1, 1		# advance weight pointer
	addi s5, s5, 4		# advance L1 output pointer
	addi t1, t1, 1		# increment neuron counter
	jal x0, L2_NEURON_LOOP

L2_NEURON_DONE:
	#addi t0, t0, 1028	# Help with rounding before destroying number with shift (equivalent to adding 0.5 in fixed point)
	#addi t0, t0, 1028
	#srai t0, t0, 12		# Descale from Q12.0 fixed point format back to integer (divide by 4096)
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
	addi t0, x0, -255		# current max value
	addi t1, x0, 0			# index of current max value
	addi t2, x0, 0			# current index
	la s7, OUTPUT_SCORES # Pointer to start of L2 output scores
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

	sw t0, LED_OFFSET(tp)

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
    .byte -1, -1, -5, -4, 2, -3, 1, -3, 0, -9, -5, -6, 31, 0, -5, 23, 17, 16, 17, 9, -1, 6, 6, -2, -17, 6, 0, 4, -16, 8, -3, -12, -5, -29, -7, -12, -7, -4, 6, -2, -16, -3, -17, -20, 5, 39, 21, 13, 32, 10, -7, 3, 46, 11, 12, -2, 8, 2, 28, 46, 1, 8, -2, 13, 2, 4, 5, 18, 19, -6, 16, 3, 3, 27, 22, -1, -14, 2, 2, 4, 18, 10, -11, -21, 2, -3, -7, -8, -4, 2, -3, -5, 4, -7, -24, -6, 1, -2, -5, 4, 0, 1, 3, 5, 2, 4, 1, 20, 55, 14, 18, 1, 0, -14, 48, 49, 38, -14, -1, 5, -8, 13, 26, 24, -3, -2, -20, -4, 15, 31, 9, 27, 5, -26, 9, 12, 4, -2, 31, 33, -19, 4, 1, -12, -1, 30, -1, -9, -3, 32, 17, -13, 1, 15, -12, 2, 23, -16, -14, 11, 27, -7, 10, 29, -12, -1, 38, 22, -11, 22, 21, 22, 7, 15, 24, 4, -2, 7, -2, 2, 31, -15, -6, -16, 1, 8, 13, 23, 2, 5, 2, -9, -20, -17, 1, -6, 5, -5, 4, 2, -1, -6, -4, -6, -3, 12, 29, 29, -10, 2, 1, 40, 33, 25, 19, 3, 4, -2, 22, 0, -5, -18, -13, 1, -16, 1, -27, -4, 0, -1, 22, -10, -13, -20, 23, -10, -1, 31, -9, -39, -27, 23, -23, -36, -13, -3, -29, -17, 0, -9, -20, 16, 9, -10, -40, 20, 3, 12, 30, 5, 19, 9, 19, 24, 17, 29, 13, 26, 28, 29, 31, 21, 34, 5, 15, 4, -14, -1, -1, 11, 5, -2, -10, 32, -9, -2, -3, 0, 4, -1, -18, -8, 5, -5, -6, 2, -4, 6, 5, -1, -5, 6, -4, 1, -6, -18, -8, 0, 4, -12, -15, 12, -8, -34, 6, 0, -12, 1, 5, 10, 17, -7, 27, 13, 19, 25, 20, 18, 9, 21, 36, 39, 11, 10, -7, 34, 16, -9, -22, 8, -7, -14, 19, -1, -45, -32, 24, -23, -14, -16, -9, -31, -2, 47, -39, -22, 30, -9, -11, 11, 29, -37, -19, 43, -9, 8, 10, -11, -11, 12, 27, 4, -12, 8, 13, 20, 22, 10, 4, -17, -14, 9, 22, -20, 6, 4, 4, 23, 6, 21, 3, 6, 0, -1, -1, 0, 2, 1, -2, 6, -5, -3, 1, 22, 28, -2, 2, 4, 21, 41, 66, 14, 5, 5, -2, 21, 11, 16, 17, 4, -18, 5, 17, -5, 3, 13, 15, -22, -1, 11, 10, -7, 17, 39, -11, -12, -1, 8, -26, 14, 10, 5, -30, 17, 8, -37, -8, 4, 8, -29, 23, -3, -34, 11, 13, 2, 13, 20, -41, -15, 25, -39, -20, 16, 23, 17, 34, 6, 11, -3, 4, 25, 30, 31, -6, -6, -4, -10, 8, 5, 7, -2, -2, 5, -6, -17, -25, -13, -1, 6, 1, 3, -5, -3, -6, 4, 3, -5, 6, -35, -51, 1, -14, 4, -4, -4, 15, 1, -31, -29, -2, 2, 7, 29, 31, -4, 7, 4, 26, 22, 32, 27, 26, 52, 19, 18, 33, 23, 36, 9, 26, 40, 17, 23, 11, 17, -4, -5, 13, -10, -9, -14, -11, 2, 2, -12, 11, -15, -19, -20, 12, 1, -24, 11, 19, -12, 4, -4, -1, -25, 1, 8, -10, -11, -7, -15, 6, 4, 7, 1, 20, -11, -12, 11, -5, 47, 62, 48, 37, -2, 6, -4, -5, 9, 11, 9, 4, 1, 2, 0, -6, 0, -1, 1, -6, 5, -1, -8, 18, 47, 23, 4, -1, -37, -22, 27, 21, 0, 2, -3, -17, -1, 51, -17, -8, -2, 26, -25, 25, 58, -32, -32, -19, 18, 19, 29, -12, -15, -14, -30, 24, 21, 2, -35, 6, 18, -31, -9, 8, 13, -34, 2, 17, 5, -6, -4, 4, -35, -6, 13, -8, -15, -22, -26, -25, 10, 1, -33, -16, -27, -35, 31, 16, 12, 5, 2, -18, -20, 30, 9, 13, 16, -2, -4, 3, 16, 9, 16, 3, -6, 4, 14, 25, 15, 3, -6, 1, 2, 0, -3, 4, 2, 4, 1, 1, 17, 17, -1, 26, 5, 5, -2, -2, -31, -10, -6, 1, -6, -14, -36, -44, -22, -20, -7, -12, -21, -21, 12, 7, -8, -7, -20, -24, -6, 32, 13, -5, -35, -16, -15, 5, 24, 12, 0, -26, 10, 14, 47, 23, 33, 24, 22, -3, 8, 27, 23, 42, 33, 28, -10, 19, 17, 47, 24, 22, 12, -2, -7, 4, 11, -29, -23, 13, 3, -37, -48, -70, -75, -27, -20, -2, -3, -27, -29, -12, 2, 4, 1, -2, -20, 8, -15, -2, 5, 4, 0, 3, 2, -5, 1, -1, 4, -4, -3, -14, -10, -20, 1, 3, -20, -2, -16, -3, -13, 5, 1, -4, 5, 20, 21, 11, -2, 7, 2, 17, 8, -6, 25, -16, -4, 19, 8, -69, 14, 20, -22, -6, -3, -27, -37, 60, 13, 19, -10, 15, -13, 18, 38, 5, -14, 2, 22, 0, 35, 16, -12, -1, 12, 13, -21, 23, -11, -17, 17, 6, 19, -7, -7, -20, -5, -15, 2, -6, 0, -30, -25, 10, -18, -4, 23, 19, -9, -15, 45, 5, -6, -4, 0, 18, -7, 3, 4, -3, -6, 2, -4, -1, 1, 2, 2, -4, 20, 19, 12, -17, -3, 4, 35, 28, 32, 17, -15, -1, 3, 39, 20, 11, 35, 5, -6, 22, 19, -8, -21, 48, 0, 5, 6, -39, -43, -67, 7, -43, -12, -6, -53, -41, -15, -8, -43, -2, 4, -4, 0, 8, -30, -26, -1, 12, 14, -4, 10, -6, -16, 5, 5, 23, -1, 9, -2, -9, 41, 15, 51, 29, -5, -7, 19, 24, -3, 44, 44, 3, -7, 10, -2, -6, 29, 16, 23, -14, -22, -4, 1, -3, 4, 16, 12, 3, 3, 2, -4, 5, 4, -1, -6, 3, -4, 4, 24, 4, -15, -6, -6, 0, 22, 18, 7, -7, -40, 4, -1, 20, 23, 15, 13, -22, -28, 27, 29, 13, 40, 15, 2, -36, 21, -2, -12, -10, 23, 12, -28, 17, -26, -30, -54, 3, -9, -17, -6, -27, -29, -28, 9, -6, 13, 8, -28, -33, -19, -13, 12, 18, 18, -14, -27, -4, -10, -8, 36, 12, -2, 7, 29, 6, -22, 17, 6, 30, 21, 2, -6, -20, -10, 1, 19, 28, 20, 13, -21, 2, 2, 6, 14, 20, 17, -1, -5, -1, -2, 0, 6, 4, 2, 0, 4, 5, 5, 10, -14, 28, -2, -5, -17, -5, -14, -39, 3, -1, 5, 3, 6, 4, 4, -31, -14, 24, 13, 15, 11, 39, -2, -27, 23, 34, 32, 5, 33, 50, -36, 19, 32, 22, -8, 18, 64, 15, -21, 14, 6, -34, 39, 25, -11, -12, 3, 17, 11, 22, -5, -27, -13, -41, 20, 25, -2, -46, -17, 4, -38, -11, 5, -19, -43, -16, 6, -31, -7, -8, -32, -19, -15, 1, 2, 4, 5, 1, -9, 0, 0, -2, 12, 28, 15, -2, -6, -1, 6, -2, 3, -2, 1, -5, -3, -6, 13, -31, -1, -25, -4, -3, -18, 1, 1, 10, 14, -5, 6, 5, -14, -15, 9, 42, 0, 23, 20, 10, 13, 27, 36, 13, 30, 16, 23, 17, 2, 3, 14, 30, 21, 26, -53, -8, -15, -4, 3, -6, -11, -60, -33, -15, -4, 0, -10, -50, -24, -10, -7, -24, -7, 7, -33, -13, 5, -7, -14, -6, 12, 24, 13, 9, -11, 2, -3, 11, 22, 12, 7, -13, 3, -1, 4, 8, 5, 8, -34, -3, 1, 0, 20, 16, 14, 3, -2, -6, 6, -1, -2, -1, 2, 2, 2, -3, 3, 6, -14, -28, -4, 6, 1, 15, 31, -1, -36, 6, 3, 3, 3, 24, 38, -6, -33, -28, -14, 1, 3, 30, -11, -27, -29, -7, -17, -11, 17, 2, -1, -28, -12, 14, 16, 17, 2, 14, -8, 4, 9, -1, 9, -14, -13, 5, 7, 3, -18, 1, 0, -22, 12, 11, -2, -26, 10, 11, -19, 13, 30, 5, -18, 4, -11, -4, 5, 20, 37, 30, 12, -7, 10, 5, 9, 14, 4, 6, 32, 3, 4, 4, -22, -18, -24, 5, 0, 6, -5, 5, 0, 5, -3, -5, 3, -3, 31, 57, 11, 5, 2, 5, -11, 15, 22, 14, 12, -3, -2, -28, -13, -19, -37, -10, 33, -12, -5, -14, -30, -33, -6, 28, -7, -5, 4, -51, -26, -6, -3, -16, 6, 37, 0, 5, -8, 7, 9, 11, 37, 31, 12, 1, 25, -1, 16, 10, 22, 18, 8, 39, -7, 1, 10, 22, -4, 13, 27, -3, -14, 0, 2, 4, 35, 2, 2, -26, -8, -15, -5, 25, -17, -2, -29, -30, -17, -34, -12, 3, -3, 1, -8, -6, -8, -2, -1, -4, -5, 6, -5, 0, -4, -3, 0, -2, -1, 7, -5, 10, -5, -1, 27, 15, -13, -46, -50, 6, 4, 7, 13, 6, -38, -78, -8, 10, 0, -4, 28, -3, -77, -17, 17, 7, -12, 24, -15, -57, -34, 11, -17, -6, 33, 10, -11, -4, -10, -31, 0, 21, -2, -11, -15, 8, -26, -20, 11, -3, 2, -27, 6, -30, -66, -3, 2, -3, -13, 14, -31, -47, 22, 7, -18, -11, 3, -7, -27, -13, -1, -5, 1, 5, 18, 6, 8, 9, 25, -5, -4, 6, -6, 18, 10, 1, -3, -5, -4, 1, 4, -4, 1, 4, 0, -1, -11, 6, -22, -21, 4, -6, -19, -73, -81, -50, -33, 6, -6, -4, -13, 0, 19, 2, -9, 16, -5, 18, 14, 39, -2, -6, 19, -5, 18, -7, 24, -5, -2, 15, 8, 6, -1, 12, -18, 10, -10, 26, 12, 12, 7, -2, -9, -7, 25, 26, 31, 5, -1, -2, -1, -35, -14, -14, -22, -15, 13, 3, -22, -28, -40, -14, 1, -17, 6, 1, 6, -45, 6, 14, 22, 2, 15, 13, -9, 5, 17, 0, -5, 5, 6, 21, 7, 4, 6, 3, 5, -2, 3, 1, -3, -3, 0, 2, 0, 35, 14, -14, -1, -2, 14, 28, 14, 13, -13, 6, 0, 21, 1, 24, -9, -25, 21, -12, 19, -12, -30, -16, -5, 4, -16, -11, -24, -14, 22, -16, 0, -23, -10, 14, 23, 16, -15, 18, 18, 5, 21, 16, 26, -2, -1, 5, 26, -1, -8, 27, 17, 18, 4, 26, -23, -27, 19, 7, 27, 22, 6, -27, 13, 7, 7, -10, 6, -2, 19, 17, 5, 4, -9, -5, 14, 8, 5, -18, 2, -2, 3, 1, -12, -17, 0, 6, 4, -4, 0, 0, 5, 0, 5, 6, -4, 1, -1, -1, -16, -15, 4, -6, 2, 28, 36, -2, -27, 1, 0, 2, 28, 31, 19, -1, -10, -25, 17, 23, 36, 28, 24, 5, 3, 30, 11, 12, 17, 12, 33, 16, -6, -22, 31, 15, -7, 15, -7, -9, -16, 24, 7, -18, -12, 7, -17, -15, 10, 7, -11, 23, 13, 14, -10, -3, 2, 11, 43, 22, 31, -4, -17, -15, 12, 15, 4, 6, 24, 2, 7, 12, 13, -5, 23, 47, 61, 45, 16, -4, -5, 1, -13, -11, -18, 4, -3, -2, 4, 4, -1, 4, -5, 5, 0, -5, -35, -42, 12, -11, 5, 4, 3, 14, 8, 11, 14, -3, -4, 6, 2, -11, 0, 18, 5, -19, -7, -1, -24, 3, 25, 39, -20, -13, 0, 20, -17, -8, 30, -18, -12, 20, 27, -14, -23, 12, 9, -16, 8, -33, 7, 21, -16, 15, 18, -45, -23, -3, 23, -39, 15, 41, 2, -18, 5, 14, -27, 13, 22, 30, 1, 8, 1, 7, -6, -3, 16, 30, 10, -16, 20, -5, -3, 10, -30, -15, -15, 0, 4, 5, -6, -23, -16, 1, -1, 6, 6, -6, -3, 6, -5, 5, -3, -6, 17, 20, 6, -22, 3, -4, 21, 28, 48, 29, -16, 1, 6, 20, 25, 21, 13, 5, -14, 21, 33, 21, 10, -7, -9, -7, 25, 21, -22, -2, -13, -5, 28, 13, -53, -55, 26, -5, 2, 7, -8, -43, -23, 52, 1, 6, -6, 16, -2, 2, 39, 3, 2, 30, 10, 10, 14, 7, -9, 6, 46, 11, 25, 17, -10, -7, -17, 21, 5, 16, 11, 15, -5, -26, -15, 3, 9, 9, 13, 22, -26, 5, 2, 0, 21, 12, 27, 4, 0, 3, -5, -4, 4, 5, -3, 0, -5, 5, 1, 3, 6, 29, 6, -6, -18, -19, 9, 19, 23, 1, 3, -46, -2, 30, 24, 3, 14, -19, -28, 21, -2, -41, -53, 15, -26, -1, 33, -55, -25, -27, 7, -20, 9, 33, 4, 56, 23, -3, -5, 13, 8, 15, 31, 2, 3, -15, -33, 3, 4, 7, -4, -17, -9, -11, 1, -7, 13, -3, -33, -15, -9, -34, 0, 16, 14, -10, -3, -4, 0, -2, 11, 37, 13, -4, -6, -5, 20, 12, 36, -3, -5, 5, -14, -12, -8, 6, 2, -4, -5, 2, 0, -2, 4, 2, 6, -3, 0, -23, 6, -7, 6, 4, -23, -6, -9, -29, -39, -6, -3, 34, 25, -26, -26, -16, 10, 19, 18, 13, 21, 19, 38, 21, 28, 8, 5, 20, 15, 5, 19, 29, 10, 23, -1, 8, -5, 14, 17, 14, 30, 13, 31, 9, -2, 1, -1, -30, 2, 20, 8, -8, 1, -59, -47, -22, -19, -12, 5, 9, -22, -19, -6, -13, -9, -9, 4, 17, 38, 35, -15, -28, 18, -4, 27, 37, 21, -6, -28, 0, -4, -5, 10, 19, 7, 4, -1, 0, 4, 1, -6, -4, -3, 4, 5, 4, -21, -21, 5, 16, -1, 1, -9, -51, -14, 3, 1, -6, 1, -24, -45, 9, 19, 10, 28, -6, -60, -35, 24, -3, -10, 3, -19, -72, -5, 14, -11, -11, 9, -15, -40, -8, 40, 25, -32, 18, -10, -41, -6, 38, -7, -70, -14, 18, -53, -24, 15, -6, -90, -15, 12, -4, -35, 9, -12, -81, -8, -18, 8, -6, 19, -22, -66, -3, 4, 2, 4, 6, -46, -39, -5, 3, -5, 25, 8, 15, 18, -5, -4, 2, -18, -16, -13, -5, -3, -1, -2, 3, -2, -2, 3, -1, -6, -4, 16, 13, -23, -28, 3, 6, -31, -8, 8, 14, -5, -5, -4, -15, -12, 2, 12, 16, -10, -3, -15, 1, 4, -10, 9, -2, -13, 20, 11, -30, -37, 8, -14, -11, 21, 7, -39, -31, 21, 28, 5, 13, 45, -27, -8, -2, 7, 1, 22, 45, 50, 19, -13, 10, -14, 22, 34, 7, -1, 5, 25, -1, 28, 20, 3, 15, 19, -3, 0, -8, 27, 19, 25, 43, -10, -1, -41, -21, -17, -43, 15, -6, 0, 0, -10, -10, -3, -4, 5, 2, 5, -1, 4, 0, -4, -2, -3, -1, 12, 38, 0, 17, -2, -1, 11, 13, 12, 19, -22, -2, -6, -12, 10, 10, 14, -70, -17, -1, -10, 20, 5, -2, -62, -22, 4, -20, -9, -41, -21, -15, -27, -6, -26, -30, -19, -4, 18, -36, 6, -21, -13, 28, -5, 19, 28, -2, -27, 7, 15, -21, 17, 32, -13, -46, 18, 10, -1, 18, 25, 4, -44, 18, 26, 11, 3, 25, 4, -20, -12, -4, -4, 2, -21, 6, -31, -41, -25, -8, -15, -6, -2, -2, -5, 4, 7, -5, -1, -6, 2, 2, 2, 1, -4, -3, -1, -6, -9, -12, 12, 38, -1, -6, 2, -23, -14, -5, 28, 4, 5, -8, 7, -9, -18, 12, 43, 23, 11, 26, -2, -27, 16, 49, 25, 16, 37, 33, -4, 19, 32, 25, 29, 13, 16, 13, 18, 36, 12, 0, -16, 28, 17, 15, -10, -7, -17, -11, 46, 7, 1, -24, -8, -15, 3, 32, 3, -15, -37, -14, -27, -7, 20, 8, -11, -8, -1, -23, -23, 11, 19, -11, 16, -1, -3, -3, 15, 2, -36, 6, -6, 1, 10, 11, 17, -3, 6, 3, 2, -1, 5, 3, 3, 3, -1, -1, -29, -53, -8, 14, -4, 1, -5, -70, -73, -43, -25, -6, -1, -34, -58, -31, -4, 32, 18, -4, -30, -31, 20, 28, 31, 36, -14, -39, -4, 15, 3, 19, 48, -3, -19, 7, 8, -34, -4, 28, 6, -31, 6, 26, -25, -52, -13, -4, -24, -3, 26, -14, -81, -13, 0, -24, 9, 20, -15, -83, -6, -1, -20, 18, -2, -28, -51, -4, 3, -30, 11, 5, -10, -23, -2, 1, -32, 8, 17, 19, 15, -3, -4, -3, -16, -21, -18, 4, 5, -3, 0, 5, -5, -5, -6, 2, -1, -2, 28, 25, 33, -18, -5, -2, 6, 54, 25, 29, 19, -4, 2, 14, 33, 39, 44, 43, 20, -2, 10, 11, 35, 7, -10, 21, -6, -16, -13, -63, -70, -89, -14, -5, -6, -13, -3, 0, -45, -24, -4, -17, -4, 4, -2, -33, 18, 0, -30, -8, 0, 1, 4, 10, -7, 16, -39, -30, 3, 10, 36, -5, 42, 15, 28, 16, 19, 18, 2, 25, 34, 15, 1, 23, 19, 1, 7, 30, 27, 8, 15, -4, 3, 0, -2, -4, -2, -2, -1, 3, 0, -2, -3, 0, 0, 6, 2, -5, -4, -6, -21, 10, -3, 4, -22, 4, -5, 2, 8, -6, 1, 18, 16, -3, 12, 20, -8, 19, 15, 11, -13, 5, 22, 3, 23, -6, 16, -47, 2, 19, -35, 20, 2, 12, -53, -25, 4, -31, 10, 13, 22, -45, -8, 12, 13, -2, 7, 30, -35, 19, 17, 1, -6, 3, 15, -7, 10, 3, 6, 1, 2, 9, 8, 9, 11, -7, -3, 2, 10, 15, 5, 0, -19, -2, -14, -30, -2, -10, -33, 6, 4, -4, 11, 18, 15, -6, 5, 1, 6, 1, -2, 3, -5, -2, -2, -5, -9, 3, 2, 30, -3, 1, 10, -11, -29, -33, 16, -3, -6, 3, -13, -26, -8, -15, -2, 13, -25, -8, 16, 20, -6, -32, 21, -9, -16, 14, 6, -18, -35, 25, -11, -23, 3, 14, -10, -21, -12, -30, -4, 16, 18, -2, 13, -8, -35, 1, 20, -4, -29, 8, -9, -45, 4, 13, 5, -10, 6, -6, -34, -9, -1, 10, -13, 13, -3, -5, -30, -42, -21, -2, 0, 1, -5, -9, -27, 6, 8, 4, -2, 5, 11, 28, 5, -3, 3, -2, 3, 5, -4, 5, -4, -6, 0, 1, 2, -5, 3, 2, 1, 1, -20, -14, -29, -17, -5, 3, -5, -4, 31, 12, -7, 13, 36, -6, 0, 21, 19, 10, 31, 30, -16, 20, 6, -47, -5, 9, 20, -23, 32, 19, 2, 7, 12, 31, 16, 18, 52, 42, 20, -24, -18, 7, -45, 16, 18, -5, -32, -26, 6, -51, -92, -37, -21, -2, -11, 13, -11, -47, -14, -1, 15, -22, 6, 7, -3, 7, 6, 18, 1, 6, 22, 35, 32, 20, 24, 5, -6, -6, -18, -2, -11, -2, 6

L1_BIASES:
    .byte 21, 0, 33, 1, 13, 19, 34, 5, 0, 15, 19, 0, 25, 16, 23, 37, 40, 4, 6, 18, -9, 5, 3, 29, 0, 22, 30, 29, 2, 31, 42, 4   

L2_WEIGHTS:
    .byte -38, 25, -38, -28, 15, 17, 38, 41, -54, 1, 16, 19, 38, 35, -30, -67, -29, -37, -7, 32, -34, -29, -19, -14, 31, 15, -64, -23, 19, 40, -37, -66, 14, -40, 34, 19, 3, -48, 71, -64, -44, 53, -11, -95, -35, -3, -25, 36, 33, -72, -4, -28, 20, -89, -94, 12, -91, 28, 9, 43, -62, 8, 31, -99, 4, 20, 26, 45, -4, -8, -28, 32, 21, 36, 29, -39, 10, -18, 37, 0, -18, 16, 17, -48, 19, -33, 8, -111, 16, 18, -29, -95, 23, 0, 3, -53, 16, 3, 35, -27, 4, 22, -37, -10, 16, 21, 30, -40, 11, 22, -36, 23, -9, 20, 20, 34, 16, -28, 13, -19, -48, -26, -31, -59, 4, -58, -46, 34, 25, -48, -25, -12, -35, -18, -59, -1, 7, -24, -76, -5, -51, -26, 29, 3, 24, 31, -34, -20, -44, 9, 34, 8, 31, -60, 14, -1, -108, 38, -4, 38, -28, 3, 28, -11, 10, 26, 5, -1, -85, -29, -27, -31, 10, -19, 8, -96, -3, -7, 6, 29, -10, 40, 2, 0, -16, -37, 15, 53, 71, -21, 0, 19, 28, 16, -7, -57, 25, -56, 7, 41, -20, -87, 11, 4, -24, -49, 23, 17, -106, 2, -52, -22, -15, 24, -78, 6, -5, 32, 15, -13, 3, 16, 41, -28, -39, -47, -46, 8, -65, 24, 16, -27, 11, 38, 42, 42, 56, -54, -36, 23, 31, -21, 2, -36, 33, -33, 39, -27, -55, 11, 14, -30, 11, 13, 16, -16, 24, 13, -20, 37, 18, 15, -65, -87, -4, -36, -32, -1, -44, 4, 27, -25, -20, 12, 27, -4, 29, 13, -22, 10, 9, -18, 14, 21, -24, -40, -29, 14, -24, -4, -49, -19, -33, 9, 12, -26, 32, -34, -25, 19, -65, 9, -30, 36, 33, -14, 12, -22, -40, 30, -6, 44, 7, -10, -17, 14, -38, -11, 16, 31

L2_BIASES:
    .byte 11, 23, -7, -1, 21, 13, -5, -13, -28, 4

# Hidden layer 1 output buffer
HIDDEN_ACTIVATIONS:
	.space 128	# 32 words 4 bytes each

OUTPUT_SCORES:
	.space 40	# 10 words 4 bytes each
