################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Magical Drop.
#
# Student 1: Norah Liu, 1012004545
# Student 2: Tony Lin, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       256
# - Unit height in pixels:      256
# - Display width in pixels:    8
# - Display height in pixels:   8
# - Base Address for Display:   0x10008000 ($gp)
################################# Knowledge #############################
# - Each memory cell / address stores 1 byte = 8 bits 
# - One unit om the display occupies 4 consecutive memory cells (4 bytes) 

#############################################################################
    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. 
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. 
ADDR_KBRD:
    .word 0xffff0000

# Bubble colors:
# 0 = empty, 1 = red, 2 = blue, 3 = yellow, 4 = green
# map color to pallete
#Initalize 5 words, each word has 4 bytes to contain the 32 bites RGB value of each color 
palette: .word 0x00000000, 0x00ef5350, 0x0042a5f5, 0x00ffee58, 0x0066bb6a

##############################################################################
# Mutable Data
##############################################################################

# Game board: 7 columns (14 units) x 14 rows (28 units)
board: .space 392 

# Player's starting position:
# Start the player in the middle of the board (0-6) 
player_col: .word 3

# The bubble carried by the player:
# Initialize it so player starts with 0 bubble held (empty color)
held_color: .word 0
held_count: .word 0

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    
    # draw a red square at (8,2) on the board 
    li $a0, 8       # X
    li $a1, 2       # Y 
    li $a2, 2       # width of rectangle
    li $a3, 2       # height of rectangle 
    li $v1, 0x00ef5350  # RGB color              
    
    jal draw_rectangle  # jump to draw rectangle in CPU 
    
    # Draw the four rectangles forming the board 
    # size = 7 columns x 14 rows. Each cell is 2x2 
    # (Innerside): width is 14 units, height is 28 units 
    li $v1 0x0090a4ae   # save the board's color in v1 
    
    # Draw the top rectangle 
    li $a0, 8
    li $a1, 0
    li $a2, 16
    li $a3, 1
    jal draw_rectangle
    
    # Draw bottom rectangle
    li $a0, 8
    li $a1, 29
    li $a2, 16
    li $a3, 1
    jal draw_rectangle
    
    # Draw the left rectangle 
    li $a0, 8
    li $a1, 1
    li $a2, 1
    li $a3, 28
    jal draw_rectangle
    
    # Draw the right rectangle 
    li $a0, 23
    li $a1, 1
    li $a2, 1
    li $a3, 28
    jal draw_rectangle
    
    
    li $v0, 10      # Exit 
    syscall

    # Function to draw any cell on the board 
draw_rectangle:
    # have arguments of a0, a1
    lw $t0 ADDR_DSPL    # load the display address 
    
    # find the starting address 
    sll $t1, $a1, 5     # times the row by 32, save to t1
    add $t1, $t1, $a0   # add column to the base address, save to t1 
    sll $t1, $t1, 2     # times the base by 4, save to t1 
    add $t0, $t0, $t1   # add the base to the origin address (t0), save to t0 
                        # we have our current address saved in t0 
    move $t2, $a3       # fine how many rows remaining to draw 

# Draw every row in a rectangle 
draw_row: 
    # after having the starting cell, we need to draw row from it 
    # find the starting unit of the row and remaining units to draw 
    
    move $t1, $t0       # address of the first unit in the current row 
    move $t3, $a2       # Number of units to draw horizontally
    
# Move down column to draw 
draw_column: 
    # draw the row starting with the current address with given width 
    sw $v1, 0($t1)      # Draw t1 (the first unit of the row) with the color saved in v1 
    addi $t1, $t1, 4    # add 4 to t1 to move right to the next unit of the row 
    addi $t3, $t3, -1   # subtract one from the number of units to be drawn horizontally 
    bnez $t3, draw_column   # (branch if not equal to zero) start at t3, to draw the left 

    # Move down one display row
    addi $t0, $t0, 128  # add 128 (32 units) to t0 (starting address of the current row) to move down by one row 
    addi $t2, $t2, -1   # after finishing one row, subtract one from the number of rows to draw 
    bnez $t2, draw_row  # if not zero rows remaining to draw, we draw row again

    jr $ra  # return to main
    
