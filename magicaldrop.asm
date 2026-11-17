# CSC258 Magical Drop - scene, movement, and grabbing
# Student: TODO name and student number
# Attribution: Scene and controls generated with assistance from Codex.
# Controls: a/d move, s grabs a same-colour chain, q quits.
# Held bubbles appear in the panel to the right, one square per bubble.
# Bitmap: width 256, height 256, unit width 8, unit height 8.
# Bitmap base address: 0x10008000 ($gp). Logical screen: 32 x 32 units.
# Board: 7 columns x 14 rows; each bubble occupies 2 x 2 units.
# Interior starts at (9,1); border spans x=8..23, y=0..29.
# Player is beneath the board at y=30..31.

.data
.align 2
ADDR_DSPL: .word 0x10008000
ADDR_KBRD: .word 0xffff0000
# Empty=0, red=1, blue=2, yellow=3, green=4.
palette: .word 0x00000000, 0x00ef5350, 0x0042a5f5, 0x00ffee58, 0x0066bb6a
# 98 cells, row-major; cell address = board + 4*(row*7 + column).
board: .space 392
player_col: .word 3
held_colour: .word 0
held_count: .word 0

.text
.globl main
main:
    li $t0, 3
    sw $t0, player_col
    sw $zero, held_colour
    sw $zero, held_count
    # Clear all 1024 display units.
    li $a0, 0
    li $a1, 0
    li $a2, 32
    li $a3, 32
    li $v1, 0
    jal draw_rect

    # Initialize every cell, including empty lower rows.
    la $s0, board
    li $s1, 98
clear_board:
    sw $zero, 0($s0)
    addiu $s0, $s0, 4
    addiu $s1, $s1, -1
    bnez $s1, clear_board

    # Populate five starting rows (35 cells) with four random colours.
    la $s0, board
    li $s1, 35
random_bubbles:
    li $v0, 42
    li $a0, 0
    li $a1, 4
    syscall
    addiu $a0, $a0, 1
    sw $a0, 0($s0)
    addiu $s0, $s0, 4
    addiu $s1, $s1, -1
    bnez $s1, random_bubbles

    # Top and bottom border.
    li $v1, 0x0090a4ae
    li $a0, 8
    li $a1, 0
    li $a2, 16
    li $a3, 1
    jal draw_rect
    li $a0, 8
    li $a1, 29
    li $a2, 16
    li $a3, 1
    jal draw_rect
    # Left and right walls.
    li $a0, 8
    li $a1, 1
    li $a2, 1
    li $a3, 28
    jal draw_rect
    li $a0, 23
    li $a1, 1
    li $a2, 1
    li $a3, 28
    jal draw_rect

redraw:
    # Erase the previous player and held-bubble indicators.
    li $a0, 9
    li $a1, 30
    li $a2, 14
    li $a3, 2
    li $v1, 0
    jal draw_rect
    li $a0, 25
    li $a1, 0
    li $a2, 7
    li $a3, 16
    jal draw_rect
    # Render the board from its independent memory representation.
    li $s0, 0
draw_cells:
    sll $t0, $s0, 2
    la $t1, board
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    sll $t2, $t2, 2
    la $t1, palette
    addu $t1, $t1, $t2
    lw $v1, 0($t1)
    li $t0, 7
    divu $s0, $t0
    mfhi $a0
    mflo $a1
    sll $a0, $a0, 1
    addiu $a0, $a0, 9
    sll $a1, $a1, 1
    addiu $a1, $a1, 1
    li $a2, 2
    li $a3, 2
    jal draw_rect
    addiu $s0, $s0, 1
    blt $s0, 98, draw_cells

    # Draw a white head and purple body underneath the selected column.
    lw $s0, player_col
    sll $s0, $s0, 1
    addiu $s0, $s0, 9
    move $a0, $s0
    li $a1, 30
    li $a2, 2
    li $a3, 1
    li $v1, 0x00ffffff
    jal draw_rect
    move $a0, $s0
    li $a1, 31
    li $a2, 2
    li $a3, 1
    li $v1, 0x00ab47bc
    jal draw_rect

    # Display held bubbles as a five-column tally to the right of the board.
    li $s0, 0
    lw $s1, held_count
    lw $t0, held_colour
    sll $t0, $t0, 2
    la $t1, palette
    addu $t1, $t1, $t0
    lw $v1, 0($t1)
draw_held:
    beq $s0, $s1, game_loop
    li $t0, 5
    divu $s0, $t0
    mfhi $a0
    addiu $a0, $a0, 26
    mflo $a1
    sll $a1, $a1, 1
    addiu $a1, $a1, 2
    li $a2, 1
    li $a3, 1
    jal draw_rect
    addiu $s0, $s0, 1
    b draw_held

game_loop:
    li $v0, 32
    li $a0, 16
    syscall
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, game_loop
    lw $t1, 4($t0)
    beq $t1, 0x71, quit
    beq $t1, 0x61, move_left
    beq $t1, 0x64, move_right
    beq $t1, 0x73, grab
    b game_loop
move_left:
    lw $t0, player_col
    beqz $t0, game_loop
    addiu $t0, $t0, -1
    sw $t0, player_col
    b redraw
move_right:
    lw $t0, player_col
    beq $t0, 6, game_loop
    addiu $t0, $t0, 1
    sw $t0, player_col
    b redraw
grab:
    # Scan upward from row 13 for this column's bottom-most bubble.
    lw $t0, player_col
    sll $t0, $t0, 2
    la $t2, board
    addu $t2, $t2, $t0
    addiu $t2, $t2, 364
    li $t3, 13
find_bottom:
    lw $t4, 0($t2)
    bnez $t4, found_bottom
    addiu $t2, $t2, -28
    addiu $t3, $t3, -1
    bgez $t3, find_bottom
    b game_loop
found_bottom:
    # A held stack can only be extended with its existing colour.
    lw $t5, held_count
    beqz $t5, begin_grab
    lw $t6, held_colour
    bne $t6, $t4, game_loop
begin_grab:
    sw $t4, held_colour
grab_chain:
    lw $t6, 0($t2)
    bne $t6, $t4, finish_grab
    sw $zero, 0($t2)
    addiu $t5, $t5, 1
    addiu $t3, $t3, -1
    bltz $t3, finish_grab
    addiu $t2, $t2, -28
    b grab_chain
finish_grab:
    sw $t5, held_count
    b redraw
quit:
    li $v0, 10
    syscall

# draw_rect(a0=x, a1=y, a2=width, a3=height, v1=RGB colour)
# Coordinates are logical bitmap units. Caller must supply in-bounds values.
# Clobbers t0..t4; preserves argument registers, v1, and saved registers.
draw_rect:
    lw $t0, ADDR_DSPL
    sll $t1, $a1, 5
    addu $t1, $t1, $a0
    sll $t1, $t1, 2
    addu $t0, $t0, $t1
    move $t2, $a3
rect_row:
    move $t1, $t0
    move $t3, $a2
rect_pixel:
    sw $v1, 0($t1)
    addiu $t1, $t1, 4
    addiu $t3, $t3, -1
    bnez $t3, rect_pixel
    addiu $t0, $t0, 128
    addiu $t2, $t2, -1
    bnez $t2, rect_row
    jr $ra
