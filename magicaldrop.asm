# CSC258 Magical Drop - core game (Milestones 1-3)
# Student: Norah Liu (1012004545) & Tony Lin 
# Attribution: Core implementation generated with assistance from Codex.
# Controls: a/d move, s grabs, w throws, q quits. Lowercase keys.
# P pauses/resumes. R retries after losing. A new row arrives every 5 seconds.
# Extra features: easy #1 (timer), #4 (loss screen/retry), #6 (pause).
# Vertical match-3 triggers connected-colour removal and upward chain reactions.
# Reaching row 13 ends play after the current action resolves.
# Game over shows GAME OVER, R RETRY, and Q QUIT in bitmap pixels.
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
player_col: .word 3
# All held bubbles have one colour, so a colour and a count are enough.
held_colour: .word 0
held_count: .word 0
# Timing uses the low 32 bits of system time; subtraction handles wraparound.
row_interval: .word 5000
last_tick: .word 0
row_elapsed: .word 0
paused: .word 0
game_over: .word 0
# Marking first avoids changing the board while neighbours are still checked.
marks: .space 392

# Small 3-by-5 font: each word holds one letter, from A through Z.
font: .word 11245, 0, 0, 27502, 31143, 0, 31087, 0, 29847, 0, 0, 0, 24557, 0, 31599, 27556, 31609, 27565, 31183, 29842, 23407, 23402, 0, 0, 23186, 0
text_paused: .word 15, 0, 20, 18, 4, 3, -1
text_game: .word 6, 0, 12, 4, -1
text_over: .word 14, 21, 4, 17, -1
text_retry: .word 17, 26, 17, 4, 19, 17, 24, -1
text_quit: .word 16, 26, 16, 20, 8, 19, -1

.text
.globl main
main:
    li $t0, 3
    sw $t0, player_col
    sw $zero, held_colour
    sw $zero, held_count
    sw $zero, row_elapsed
    sw $zero, paused
    # A retry must also remove the previous round's matching scratch data.
    la $t0, marks
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

    # Start the clock after initialization so setup does not consume play time.
    li $v0, 30
    syscall
    sw $a0, last_tick
redraw:
    li $a0, 0
    li $a1, 11
    li $a2, 8
    li $a3, 9
    li $v1, 0
    jal draw_rect
    # Restore the left wall if the pause banner covered it.
    li $a0, 8
    li $a1, 11
    li $a2, 1
    li $a3, 9
    li $v1, 0x0090a4ae
    jal draw_rect
    li $a0, 24
    li $a1, 11
    li $a2, 1
    li $a3, 9
    li $v1, 0
    jal draw_rect
    li $a0, 23
    li $a1, 11
    li $v1, 0x0090a4ae
    jal draw_rect
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
    b show_game_over

game_loop:
    li $v0, 32
    li $a0, 16
    syscall
    # Timer updates continue even when the player does not press anything.
    jal update_timer
    bnez $v0, check_loss
poll_keyboard:
    lw $t0, ADDR_KBRD
    lw $t1, 0($t0)
    andi $t1, $t1, 1
    beqz $t1, game_loop
    lw $t1, 4($t0)
handle_key:
    beq $t1, 0x71, quit
    lw $t0, game_over
    bnez $t0, loss_input
    beq $t1, 0x70, toggle_pause
    lw $t0, paused
    bnez $t0, game_loop
    beq $t1, 0x61, move_left
    beq $t1, 0x64, move_right
    beq $t1, 0x73, grab
    beq $t1, 0x77, throw
    b game_loop
loss_input:
    beq $t1, 0x72, main
    b game_loop

toggle_pause:
    lw $t0, paused
    beqz $t0, pause_game
    sw $zero, paused
    # Start measuring again from now, excluding all time spent paused.
    li $v0, 30
    syscall
    sw $a0, last_tick
    b redraw
pause_game:
    li $t0, 1
    sw $t0, paused
    # This only changes the screen. The board and held bubbles stay in memory.
    li $a0, 2
    li $a1, 11
    li $a2, 28
    li $a3, 9
    li $v1, 0x00151c28
    jal draw_rect
    li $a0, 4
    li $a1, 13
    la $a2, text_paused
    li $v1, 0x00ffffff
    jal draw_text
    b game_loop

move_left:
    # Stop at column 0 instead of allowing the player to leave the board.
    lw $t0, player_col
    beqz $t0, action_done
    addiu $t0, $t0, -1
    sw $t0, player_col
    b action_done
move_right:
    # Column 6 is the last of the seven columns.
    lw $t0, player_col
    beq $t0, 6, action_done
    addiu $t0, $t0, 1
    sw $t0, player_col
    b action_done
grab:
    # Scan upward from row 13 for this column's bottom-most bubble.
    lw $t0, player_col
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
    lw $t5, held_count
    beqz $t5, begin_grab
    lw $t6, held_colour
    bne $t6, $t4, action_done
begin_grab:
    sw $t4, held_colour
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
    sw $t5, held_count
    b action_done
throw:
    lw $t5, held_count
    beqz $t5, action_done
    lw $t0, player_col
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
    lw $t6, held_colour
throw_place:
    sw $t6, 0($t2)
    addiu $t2, $t2, 28
    addiu $t5, $t5, -1
    bnez $t5, throw_place
    sw $zero, held_count
    sw $zero, held_colour
    jal resolve_matches
    b action_done
throw_overflow:
    # Reject the entire overflowing throw and end the game without memory writes.
    li $t0, 1
    sw $t0, game_over
    b redraw

action_done:
    # Keyboard actions no longer advance rows; the wall clock does that.
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
# Does not resolve matches: automatic matches are checked on the next throw.
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

# Resolve all vertical triggers, connected components, and subsequent chains.
# marks is separate from board: discover the whole removal set before deleting.
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
    la $t0, marks
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
    la $t1, marks
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

    # Flood fill by repeated propagation; 98 cells bound the work.
expand_pass:
    li $s0, 0
    li $s2, 0
expand_cell:
    sll $t0, $s0, 2
    la $t1, marks
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, expand_next
    la $t1, board
    addu $t1, $t1, $t0
    lw $s3, 0($t1)
    move $a1, $s3
    blt $s0, 7, expand_down
    addiu $a0, $s0, -7
    jal mark_neighbour
    or $s2, $s2, $v0
expand_down:
    bge $s0, 91, expand_left
    addiu $a0, $s0, 7
    jal mark_neighbour
    or $s2, $s2, $v0
expand_left:
    # Checking the column prevents the last cell of one row wrapping to the next.
    li $t0, 7
    divu $s0, $t0
    mfhi $t1
    beqz $t1, expand_right
    addiu $a0, $s0, -1
    jal mark_neighbour
    or $s2, $s2, $v0
expand_right:
    li $t0, 7
    divu $s0, $t0
    mfhi $t1
    beq $t1, 6, expand_next
    addiu $a0, $s0, 1
    jal mark_neighbour
    or $s2, $s2, $v0
expand_next:
    addiu $s0, $s0, 1
    blt $s0, 98, expand_cell
    bnez $s2, expand_pass

    li $t0, 0
delete_marked:
    la $t1, marks
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    beqz $t2, delete_next
    la $t1, board
    addu $t1, $t1, $t0
    sw $zero, 0($t1)
delete_next:
    addiu $t0, $t0, 4
    blt $t0, 392, delete_marked

    # Compact each column toward row 0, preserving bubble order.
    li $s0, 0
gravity_column:
    li $s1, 0
    li $s2, 0
gravity_read:
    # s1 scans each row; s2 is where the next nonempty bubble should be written.
    # Moving upward in this order keeps the remaining bubbles in the same order.
    mul $t0, $s1, 7
    addu $t0, $t0, $s0
    sll $t0, $t0, 2
    la $t1, board
    addu $t0, $t0, $t1
    lw $t2, 0($t0)
    beqz $t2, gravity_next
    sw $zero, 0($t0)
    mul $t3, $s2, 7
    addu $t3, $t3, $s0
    sll $t3, $t3, 2
    addu $t3, $t3, $t1
    sw $t2, 0($t3)
    addiu $s2, $s2, 1
gravity_next:
    addiu $s1, $s1, 1
    blt $s1, 14, gravity_read
    addiu $s0, $s0, 1
    blt $s0, 7, gravity_column
    # Closing a gap may create a new triple, so scan the settled board again.
    b resolve_round
resolve_return:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    addiu $sp, $sp, 24
    jr $ra

# mark_neighbour(a0=valid cell index, a1=trigger colour).
# v0=1 only when a new cell was marked. Clobbers t0..t3.
mark_neighbour:
    li $v0, 0
    sll $t0, $a0, 2
    la $t1, board
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    bne $t2, $a1, mark_return
    la $t1, marks
    addu $t1, $t1, $t0
    lw $t2, 0($t1)
    bnez $t2, mark_return
    li $v0, 1
    sw $v0, 0($t1)
mark_return:
    jr $ra

# update_timer returns v0=1 if a row was added, otherwise 0.
# It is called once per idle/input loop, rather than once per keystroke.
update_timer:
    li $v0, 0
    lw $t0, paused
    bnez $t0, timer_return
    lw $t0, game_over
    bnez $t0, timer_return
    li $v0, 30
    syscall
    lw $t0, last_tick
    # syscall 30 puts the current time in a0 (low word) and a1 (high word).
    # Subtract the previous reading to find how many milliseconds passed.
    subu $t1, $a0, $t0
    sw $a0, last_tick
    lw $t2, row_elapsed
    addu $t2, $t2, $t1
    sw $t2, row_elapsed
    lw $t3, row_interval
    li $v0, 0
    bltu $t2, $t3, timer_return
    # Add at most one row per frame, even after a long simulator stall.
    # Keeping the small remainder avoids accumulating frame timing errors.
    divu $t2, $t3
    mfhi $t2
    sw $t2, row_elapsed
    addiu $sp, $sp, -8
    sw $ra, 0($sp)
    jal advance_row
    lw $ra, 0($sp)
    addiu $sp, $sp, 8
    li $v0, 1
timer_return:
    jr $ra

show_game_over:
    # The loss screen replaces the board, but only R starts a fresh round.
    li $a0, 0
    li $a1, 0
    li $a2, 32
    li $a3, 32
    li $v1, 0x00151c28
    jal draw_rect
    li $a0, 8
    li $a1, 5
    la $a2, text_game
    li $v1, 0x00ef5350
    jal draw_text
    li $a0, 8
    li $a1, 12
    la $a2, text_over
    jal draw_text
    li $a0, 2
    li $a1, 21
    la $a2, text_retry
    li $v1, 0x0066bb6a
    jal draw_text
    li $a0, 4
    li $a1, 27
    la $a2, text_quit
    li $v1, 0x00ffffff
    jal draw_text
    b game_loop

# draw_text(a0=x, a1=y, a2=letter array, v1=colour).
# Letter arrays end in -1; 26 means a blank space.
# Text uses bitmap pixels, so it appears in the game rather than the console.
# s0=letter pointer, s1=x, s2=y, s3=glyph, s4=bit mask, s5=pixel index.
draw_text:
    addiu $sp, $sp, -32
    # Save the caller's return address and saved registers before using them.
    sw $ra, 0($sp)
    sw $s0, 4($sp)
    sw $s1, 8($sp)
    sw $s2, 12($sp)
    sw $s3, 16($sp)
    sw $s4, 20($sp)
    sw $s5, 24($sp)
    move $s0, $a2
    move $s1, $a0
    move $s2, $a1
text_letter:
    lw $t0, 0($s0)
    bltz $t0, text_return
    beq $t0, 26, text_next
    sll $t0, $t0, 2
    la $t1, font
    addu $t0, $t0, $t1
    lw $s3, 0($t0)
    li $s4, 16384
    li $s5, 0
text_pixel:
    and $t0, $s3, $s4
    beqz $t0, text_skip
    li $t0, 3
    divu $s5, $t0
    mfhi $a0
    addu $a0, $a0, $s1
    mflo $a1
    addu $a1, $a1, $s2
    li $a2, 1
    li $a3, 1
    jal draw_rect
text_skip:
    srl $s4, $s4, 1
    addiu $s5, $s5, 1
    blt $s5, 15, text_pixel
text_next:
    addiu $s0, $s0, 4
    addiu $s1, $s1, 4
    b text_letter
text_return:
    lw $ra, 0($sp)
    lw $s0, 4($sp)
    lw $s1, 8($sp)
    lw $s2, 12($sp)
    lw $s3, 16($sp)
    lw $s4, 20($sp)
    lw $s5, 24($sp)
    addiu $sp, $sp, 32
    jr $ra
