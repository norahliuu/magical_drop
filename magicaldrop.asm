# CSC258 Magical Drop - core game (Milestones 1-3)
# Students: Norah Liu and Tony Lin; student numbers: TODO
# Controls: a/d move, s grabs, w throws, q quits. Lowercase keys.
# Demo 1 base game: one new row per 10 a/d/s/w keypresses.
# Vertical runs of 3+ clear; unsupported bubbles rise and new matches chain.
# Reaching row 13 ends play. Stop/Play in Saturn starts a new game.
# No timer, pause, retry screen, or optional features.
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
# Each cell uses 4 bytes, so 7 * 14 * 4 = 392 bytes for the whole board.
board: .space 392
# Columns are numbered 0..6. Starting at 3 puts the player in the middle.
player_column: .word 3
# All held bubbles have one colour, so a colour and a count are enough.
held_bubble_colour: .word 0
held_bubble_count: .word 0
# Count gameplay keys, including unsuccessful actions at a boundary.
key_count: .word 0
game_over: .word 0
# Marking first avoids changing the board while neighbours are still checked.
bubbles_to_clear: .space 392

.text
.globl main
main:
    li $t0, 3
    sw $t0, player_column
    sw $zero, held_bubble_colour
    sw $zero, held_bubble_count
    sw $zero, key_count
    # Clear matching scratch data at startup.
    la $t0, bubbles_to_clear
    li $t1, 98
reset_marks:
    sw $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bnez $t1, reset_marks
    sw $zero, game_over
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
    li $a3, 32
    jal draw_rect
    # Render the board from its independent memory representation.
    li $s0, 0
draw_cells:
    # Dividing the cell number by 7 gives its row and column.
    # The palette turns a small colour number into the actual RGB value.
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
    lw $s0, player_column
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
    lw $s1, held_bubble_count
    lw $t0, held_bubble_colour
    sll $t0, $t0, 2
    la $t1, palette
    addu $t1, $t1, $t0
    lw $v1, 0($t1)
draw_held:
    beq $s0, $s1, finish_frame
    bge $s0, 98, finish_frame
    li $t0, 5
    divu $s0, $t0
    mfhi $a0
    addiu $a0, $a0, 26
    mflo $a1
    addiu $a1, $a1, 2
    li $a2, 1
    li $a3, 1
    jal draw_rect
    addiu $s0, $s0, 1
    b draw_held

finish_frame:
    lw $t0, game_over
    beqz $t0, game_loop
    b quit

game_loop:
    li $v0, 32
    li $a0, 16
    syscall
poll_keyboard:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, game_loop
    lw $t1, 4($t0)
handle_key:
    beq $t1, 0x71, quit
    lw $t0, game_over
    bnez $t0, quit
    beq $t1, 0x61, move_left
    beq $t1, 0x64, move_right
    beq $t1, 0x73, grab
    beq $t1, 0x77, throw
    b game_loop
move_left:
    # Stop at column 0 instead of allowing the player to leave the board.
    lw $t0, player_column
    beqz $t0, action_done
    addiu $t0, $t0, -1
    sw $t0, player_column
    b action_done
move_right:
    # Column 6 is the last of the seven columns.
    lw $t0, player_column
    beq $t0, 6, action_done
    addiu $t0, $t0, 1
    sw $t0, player_column
    b action_done
grab:
    # Scan upward from row 13 for this column's bottom-most bubble.
    lw $t0, player_column
    sll $t0, $t0, 2
    la $t2, board
    addu $t2, $t2, $t0
    addiu $t2, $t2, 364
    li $t3, 13
find_bottom:
    # One board row is 7 words = 28 bytes. Move up until something is found.
    lw $t4, 0($t2)
    bnez $t4, found_bottom
    addiu $t2, $t2, -28
    addiu $t3, $t3, -1
    bgez $t3, find_bottom
    b action_done
found_bottom:
    # A held stack can only be extended with its existing colour.
    lw $t5, held_bubble_count
    beqz $t5, begin_grab
    lw $t6, held_bubble_colour
    bne $t6, $t4, action_done
begin_grab:
    sw $t4, held_bubble_colour
grab_chain:
    # Removing the bubble means writing zero into that board cell.
    # Stop as soon as the next bubble is a different colour or the column ends.
    lw $t6, 0($t2)
    bne $t6, $t4, finish_grab
    sw $zero, 0($t2)
    addiu $t5, $t5, 1
    addiu $t3, $t3, -1
    bltz $t3, finish_grab
    addiu $t2, $t2, -28
    b grab_chain
finish_grab:
    sw $t5, held_bubble_count
    b action_done
throw:
    lw $t5, held_bubble_count
    beqz $t5, action_done
    lw $t0, player_column
    sll $t0, $t0, 2
    la $t2, board
    addu $t2, $t2, $t0
    addiu $t2, $t2, 364
    li $t3, 13
throw_find_bottom:
    # One board row is 7 words = 28 bytes. Move up until something is found.
    lw $t4, 0($t2)
    bnez $t4, throw_position
    addiu $t2, $t2, -28
    addiu $t3, $t3, -1
    bgez $t3, throw_find_bottom
throw_position:
    # Place below the lowest occupied row; an empty column starts at row 0.
    addiu $t3, $t3, 1
    addu $t4, $t3, $t5
    # Check the whole stack fits before changing any cells.
    bgt $t4, 14, throw_overflow
    addiu $t2, $t2, 28
    lw $t6, held_bubble_colour
throw_place:
    sw $t6, 0($t2)
    addiu $t2, $t2, 28
    addiu $t5, $t5, -1
    bnez $t5, throw_place
    sw $zero, held_bubble_count
    sw $zero, held_bubble_colour
    jal resolve_matches
    b action_done
throw_overflow:
    # Reject the entire overflowing throw and end the game without memory writes.
    li $t0, 1
    sw $t0, game_over
    b redraw

action_done:
    # Only a/d/s/w reach here; other keys do not advance the counter.
    lw $t0, key_count
    addiu $t0, $t0, 1
    sw $t0, key_count
    blt $t0, 10, check_loss
    sw $zero, key_count
    jal advance_row
check_loss:
    # Row 13 is the danger row. Test after matches have finished resolving.
    la $t0, board
    addiu $t0, $t0, 364
    li $t1, 7
loss_scan:
    lw $t2, 0($t0)
    bnez $t2, set_loss
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bnez $t1, loss_scan
    b redraw
set_loss:
    li $t0, 1
    sw $t0, game_over
    b redraw
quit:
    li $v0, 10
    syscall

# draw_rect(a0=x, a1=y, a2=width, a3=height, v1=RGB colour)
# Coordinates are logical bitmap units. Caller must supply in-bounds values.
# Clobbers t0..t4; preserves argument registers, v1, and saved registers.
draw_rect:
    lw $t0, ADDR_DSPL
    # A screen row has 32 units. Multiply y by 32, then add x.
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
    # A display row is 32 words = 128 bytes.
    addiu $t0, $t0, 128
    addiu $t2, $t2, -1
    bnez $t2, rect_row
    jr $ra

# Push the board down one row, then generate seven random cells at the top.
# Matches are checked on the next throw, not when a row arrives.
advance_row:
    addiu $sp, $sp, -8
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    la $t0, board
    li $t1, 388
shift_row:
    # Copy from bottom to top, so earlier copies do not overwrite source cells.
    addu $t2, $t0, $t1
    lw $t3, -28($t2)
    sw $t3, 0($t2)
    addiu $t1, $t1, -4
    bge $t1, 28, shift_row
    li $s0, 0
new_row:
    li $v0, 42
    li $a0, 0
    li $a1, 4
    syscall
    addiu $a0, $a0, 1
    sll $t0, $s0, 2
    la $t1, board
    addu $t0, $t0, $t1
    sw $a0, 0($t0)
    addiu $s0, $s0, 1
    blt $s0, 7, new_row
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    addiu $sp, $sp, 8
    jr $ra

# Resolve vertical runs of three or more. Each pass marks and deletes all current
# vertical matches simultaneously, compacts bubbles upward in every column, and
# repeats if gravity created another vertical match. This implements chains.
# bubbles_to_clear is separate from board so discovery finishes before deletion.
# Preserves all saved registers used here and ra; clobbers temporary registers.
resolve_matches:
    addiu $sp, $sp, -24
    # Save the caller's return address and saved registers before using them.
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
resolve_round:
    la $t0, bubbles_to_clear
    li $t1, 98
clear_marks:
    sw $zero, 0($t0)
    addiu $t0, $t0, 4
    addiu $t1, $t1, -1
    bnez $t1, clear_marks
    li $s0, 0
    li $s1, 0
seed_scan:
    # Only rows 0..11 can start a vertical triple inside a 14-row board.
    # The two cells below are 28 and 56 bytes away.
    sll $t0, $s0, 2
    la $t1, board
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, seed_next
    lw $t3, 28($t1)
    bne $t2, $t3, seed_next
    lw $t3, 56($t1)
    bne $t2, $t3, seed_next
    la $t1, bubbles_to_clear
    addu $t1, $t1, $t0
    li $t2, 1
    sw $t2, 0($t1)
    sw $t2, 28($t1)
    sw $t2, 56($t1)
    li $s1, 1
seed_next:
    addiu $s0, $s0, 1
    blt $s0, 84, seed_scan
    beqz $s1, resolve_return

    li $t0, 0
delete_marked:
    la $t1, bubbles_to_clear
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, delete_next
    la $t1, board
    addu $t1, $t1, $t0
    sw $zero, 0($t1)
delete_next:
    addiu $t0, $t0, 4
    blt $t0, 392, delete_marked

    # Gravity: compact each column toward row 0, preserving bubble order.
    # s1 is the next free destination row; s2 scans source rows 0..13.
    li $s0, 0
gravity_column:
    li $s1, 0
    li $s2, 0
gravity_scan:
    # Source address = board + 4*(row*7 + column).
    li $t0, 7
    multu $s2, $t0
    mflo $t0
    addu $t0, $t0, $s0
    sll $t0, $t0, 2
    la $t1, board
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, gravity_scan_next

    # Copy each bubble to the next occupied slot, if there is a gap above it.
    li $t0, 7
    multu $s1, $t0
    mflo $t0
    addu $t0, $t0, $s0
    sll $t0, $t0, 2
    la $t1, board
    addu $t1, $t1, $t0
    sw $t2, 0($t1)
    addiu $s1, $s1, 1
gravity_scan_next:
    addiu $s2, $s2, 1
    blt $s2, 14, gravity_scan

    # Clear leftover cells below the compacted stack, if any.
    bge $s1, 14, gravity_next_column
gravity_clear_tail:
    li $t0, 7
    multu $s1, $t0
    mflo $t0
    addu $t0, $t0, $s0
    sll $t0, $t0, 2
    la $t1, board
    addu $t1, $t1, $t0
    sw $zero, 0($t1)
    addiu $s1, $s1, 1
    blt $s1, 14, gravity_clear_tail
gravity_next_column:
    addiu $s0, $s0, 1
    blt $s0, 7, gravity_column

    # Gravity may have made another vertical triple; resolve the next chain.
    b resolve_round

resolve_return:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addiu $sp, $sp, 24
    jr $ra
