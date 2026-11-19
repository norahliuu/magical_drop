# Magical Drop - MIPS game

Open `magicaldrop.asm` in Saturn. Under Ctrl+T > Bitmap, set display width/height to 256, both unit sizes to 8, and the address to `0x10008000`. Press Play, then click the bitmap to give it keyboard focus.

- **a / d**: move one column; the player stops at the edges.
- **s**: grab the bottom contiguous chain of the same colour. While holding bubbles, only that colour can be collected.
- **w**: throw the entire held stack into the current column. An empty column receives the stack at the top; otherwise it attaches beneath the existing bubbles.
- **p**: pause/resume. The bitmap displays PAUSED; the timer and gameplay freeze.
- **r**: start a new game from the Game Over screen.
- **q**: exit at any time.

A random row arrives automatically every five seconds of active play, even without keyboard input. Paused time does not count. Change `row_interval` (milliseconds) to adjust this delay. The right-hand tally shows one coloured square for each held bubble.

Three or more vertical matching bubbles trigger removal of the whole connected same-colour component (four-way adjacency). Horizontal groups alone do not trigger. Remaining bubbles compact upwards in their columns; new vertical matches resolve repeatedly until stable. New rows are not automatically cleared until a throw triggers a match check.

Reaching the bottom board row after an action resolves ends the game. Throwing more bubbles than the column can hold also ends it without writing beyond the board. The bitmap displays GAME OVER, R RETRY, and Q QUIT. Press r to reset the board, player, held bubbles, matching data, pause flag, and timer, or q to exit. There is no score, sound, or difficulty menu.

Implemented extra features: easy #1 (timed rows), #4 (Game Over/retry), and #6 (pause).

The board stores 98 words in row-major order, separate from the display. Zero is empty; 1-4 are colours. `marks` stores the removal set; player column, held colour/count, timer, pause flag, and loss status have separate words. Display units are 32 x 32, with 2 x 2 units per board cell.

## Validation

Run `python -m unittest discover -s tests -v`. The deterministic test harness executes the MIPS instruction subset in the source file and checks board states and memory bounds. It is not a full MIPS assembler or a substitute for testing in Saturn.

The source header records Codex assistance. Fill in the student information and follow your course's attribution requirements.
