# Magical Drop - Demo 1 base game

This branch implements the detailed Milestones 1-3 checklist. The full-feature version remains on `master`.

## Run in Saturn

Open `magicaldrop.asm`. Under Ctrl+T > Bitmap, set display width/height to 256, both unit sizes to 8, and base address to `0x10008000`. Press Play and click the bitmap for keyboard focus. Use lowercase keys.

- **a / d:** move left/right within the seven columns.
- **s:** grab the bottom contiguous same-colour stack. When holding bubbles, only that colour can be collected.
- **w:** throw the held stack beneath the lowest bubble in the selected column, or at the top of an empty column.
- **q:** quit.

The board has 7 columns, 14 rows, and five random starting rows using four colours. Held bubbles appear on the right.

Every 10 a/d/s/w keypresses adds a random top row and pushes existing bubbles downward. Unsuccessful gameplay actions count; other keys do not. Waiting without input never advances rows.

After a throw, vertical runs of three or more clear simultaneously. Remaining bubbles compact upward within their columns while preserving order. The game repeats matching and gravity until no vertical match remains, producing chain reactions. Horizontal neighbours do not clear unless part of their own vertical run; there is no horizontal flood fill.

Reaching the bottom row after an action resolves, or attempting an overflowing throw, ends execution after redrawing the board. Stop/Play starts another game. There is no timer, pause, retry screen, score, sound, or menu.

## Worksheet interpretation

This branch implements vertical matching, gravity, and chain reactions for Milestone 3. It omits other features listed under Easy/Hard Features; the full implementation remains on `master`.

## Memory and validation

`board` and `bubbles_to_clear` each contain 98 words (392 bytes). Board values are 0 for empty and 1-4 for colours. Cell address is `board + 4*(row*7 + column)`. Player column, held colour/count, keystroke count, and game-over state have separate words. Drawing uses a 32 x 32 logical display with 2 x 2 units per bubble.

Run `python -m unittest discover -s tests -v` for the regression checks. The harness executes the MIPS instruction subset used here; assemble and play the branch in Saturn before submitting it.

Students: Norah Liu and Tony Lin. Fill in student numbers in the source header. The report should describe this branch's keystroke-based rows and vertical matching with gravity and chain reactions.
