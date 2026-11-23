"""Execute the game's MIPS instruction subset for deterministic regression checks.
This harness does not replace assembling/running the game in Saturn.
"""
from pathlib import Path
import re
import unittest

SOURCE = Path(__file__).resolve().parents[1] / 'magicaldrop.asm'

class Machine:
    def __init__(self):
        self.mem, self.labels, self.code, self.reg = {}, {}, [], {'$sp': 0x7fffeffc}
        self.hi = self.lo = 0
        section, addr = '', 0x10010000
        for raw in SOURCE.read_text().splitlines():
            line = raw.split('#')[0].strip()
            if not line: continue
            if line in ('.data', '.text'): section = line; continue
            if line.startswith(('.align', '.globl')): continue
            if ':' in line:
                label, line = line.split(':', 1)
                self.labels[label] = addr if section == '.data' else len(self.code)
                line = line.strip()
            if not line: continue
            if section == '.data':
                op, args = line.split(None, 1)
                if op == '.space': addr += int(args)
                elif op == '.word':
                    for val in args.split(','):
                        self.mem[addr] = int(val.strip(), 0); addr += 4
            else: self.code.append(re.split(r'[\s,]+', line))
        self.pc = 0
        self.random = 0
        self.now = 0

    def value(self, x):
        if x.startswith('$'): return 0 if x == '$zero' else self.reg.get(x, 0)
        return self.labels[x] if x in self.labels else int(x, 0)

    def put(self, x, val):
        if x != '$zero':
            val &= 0xffffffff
            self.reg[x] = val if val < 0x80000000 else val - 0x100000000

    def address(self, x):
        m = re.fullmatch(r'(-?\d+)\((\$\w+)\)', x)
        return self.value(m[2]) + int(m[1]) if m else self.value(x)

    def run(self, label, stop=None, limit=500000):
        self.pc = self.labels[label]
        self.reg['$ra'] = -1
        for _ in range(limit):
            if self.pc == -1 or (stop and self.pc == self.labels[stop]): return
            op, *a = self.code[self.pc]; self.pc += 1
            v = self.value
            if op in ('li', 'la', 'move'): self.put(a[0], v(a[1]))
            elif op == 'lw': self.put(a[0], self.mem.get(self.address(a[1]), 0))
            elif op == 'sw': self.mem[self.address(a[1])] = v(a[0])
            elif op in ('addu', 'addiu'): self.put(a[0], v(a[1]) + v(a[2]))
            elif op == 'subu': self.put(a[0], v(a[1]) - v(a[2]))
            elif op == 'and': self.put(a[0], v(a[1]) & v(a[2]))
            elif op == 'srl': self.put(a[0], (v(a[1]) & 0xffffffff) >> v(a[2]))
            elif op == 'mul': self.put(a[0], v(a[1]) * v(a[2]))
            elif op == 'sll': self.put(a[0], v(a[1]) << v(a[2]))
            elif op == 'andi': self.put(a[0], v(a[1]) & v(a[2]))
            elif op == 'or': self.put(a[0], v(a[1]) | v(a[2]))
            elif op == 'divu': self.lo, self.hi = divmod(v(a[0]) & 0xffffffff, v(a[1]) & 0xffffffff)
            elif op in ('mfhi', 'mflo'): self.put(a[0], self.hi if op == 'mfhi' else self.lo)
            elif op == 'b': self.pc = self.labels[a[0]]
            elif op in ('beq', 'bne', 'blt', 'bgt', 'bge', 'bltu'):
                x, y = v(a[0]), v(a[1])
                if {'beq': x == y, 'bne': x != y, 'blt': x < y, 'bgt': x > y, 'bge': x >= y, 'bltu': (x & 0xffffffff) < (y & 0xffffffff)}[op]: self.pc = self.labels[a[2]]
            elif op in ('beqz', 'bnez', 'bltz', 'bgez'):
                x = v(a[0])
                if {'beqz': x == 0, 'bnez': x != 0, 'bltz': x < 0, 'bgez': x >= 0}[op]: self.pc = self.labels[a[1]]
            elif op == 'jal': self.reg['$ra'] = self.pc; self.pc = self.labels[a[0]]
            elif op == 'jr': self.pc = v(a[0])
            elif op == 'syscall':
                if v('$v0') == 10: return
                if v('$v0') == 30: self.put('$a0', self.now)
                elif v('$v0') == 42:
                    self.put('$a0', self.random % v('$a1')); self.random += 1
                elif v('$v0') != 32: raise AssertionError('unsupported syscall')
            else: raise AssertionError(op)
        raise AssertionError('execution did not terminate')

    def cells(self): return [self.mem.get(self.labels['board'] + 4*i, 0) for i in range(98)]
    def cell(self, r, c, colour): self.mem[self.labels['board'] + 4*(7*r+c)] = colour
    def set(self, name, val): self.mem[self.labels[name]] = val
    def get(self, name): return self.mem.get(self.labels[name], 0)

class CoreTests(unittest.TestCase):
    def test_horizontal_does_not_trigger(self):
        m=Machine()
        for c in range(4): m.cell(0,c,1)
        before=m.cells(); m.run('resolve_matches'); self.assertEqual(m.cells(),before)

    def test_only_vertical_matches_clear_without_gravity(self):
        m=Machine()
        for r in range(3): m.cell(r,6,1)
        m.cell(1,5,1); m.cell(2,4,1); m.cell(3,0,1)
        m.run('resolve_matches')
        self.assertEqual(sum(x != 0 for x in m.cells()),3)
        self.assertEqual(m.cells()[12],1)
        self.assertEqual(m.cells()[18],1)
        self.assertEqual(m.cells()[21],1)

    def test_long_runs_clear_but_survivors_stay_in_place(self):
        m=Machine()
        for r, colour in enumerate([2,1,1,1,1,2,2]): m.cell(r,0,colour)
        m.run('resolve_matches')
        self.assertEqual([m.cells()[7*r] for r in range(7)],[2,0,0,0,0,2,2])

    def test_throw_empty_and_no_hands(self):
        m=Machine(); m.set('player_column',3); m.set('held_bubble_colour',2); m.set('held_bubble_count',2)
        m.run('throw',stop='redraw')
        self.assertEqual(m.cells()[3],2); self.assertEqual(m.cells()[10],2)
        self.assertEqual(m.get('held_bubble_count'),0)
        before=m.cells(); m.run('throw',stop='redraw'); self.assertEqual(m.cells(),before)

    def test_throw_match(self):
        m=Machine(); m.set('player_column',0); m.cell(0,0,2); m.set('held_bubble_colour',2); m.set('held_bubble_count',2)
        m.run('throw',stop='redraw'); self.assertFalse(any(m.cells()))

    def test_overflow_is_atomic(self):
        m=Machine(); m.set('player_column',0)
        for r in range(12): m.cell(r,0,1+(r%4))
        m.set('held_bubble_count',3); m.set('held_bubble_colour',2)
        before=m.cells(); m.run('throw',stop='redraw')
        self.assertEqual(m.cells(),before); self.assertEqual(m.get('game_over'),1)

    def test_grab_chain_colour_and_empty(self):
        m=Machine(); m.set('player_column',0)
        for r, colour in enumerate([1,2,2]): m.cell(r,0,colour)
        m.run('grab',stop='redraw'); self.assertEqual(m.get('held_bubble_count'),2)
        self.assertEqual(m.cells()[0],1)
        m.run('grab',stop='redraw'); self.assertEqual(m.get('held_bubble_count'),2)
        m.set('player_column',1); m.run('grab',stop='redraw'); self.assertEqual(m.get('held_bubble_count'),2)

    def test_tenth_gameplay_key_advances_row_and_bounds_hold(self):
        m=Machine(); m.set('player_column',0); m.cell(0,0,3); before=m.cells()
        for _ in range(9): m.run('move_left',stop='redraw')
        self.assertEqual(m.get('player_column'),0)
        self.assertEqual(m.cells(),before); self.assertEqual(m.get('key_count'),9)
        m.run('move_left',stop='redraw')
        self.assertEqual(m.get('key_count'),0); self.assertEqual(m.cells()[7],3)
        self.assertTrue(all(1 <= x <= 4 for x in m.cells()[:7]))
        m.set('player_column',6); m.run('move_right',stop='redraw')
        self.assertEqual(m.get('player_column'),6)

    def test_row_advancement_triggers_loss(self):
        m=Machine(); m.cell(12,0,4); m.set('key_count',9)
        m.run('move_left',stop='redraw')
        self.assertEqual(m.cells()[91],4); self.assertEqual(m.get('game_over'),1)
        m.run('redraw')
        self.assertEqual(m.reg['$v0'],10)

    def test_extra_keys_are_ignored(self):
        m=Machine(); m.cell(0,0,2); before=m.cells()
        for key in 'prxz':
            m.reg['$t1']=ord(key); m.run('handle_key',stop='game_loop')
        self.assertEqual(m.cells(),before); self.assertEqual(m.get('key_count'),0)

    def test_all_gameplay_keys_count_and_quit_exits(self):
        m=Machine()
        for key in 'adsw':
            m.reg['$t1']=ord(key); m.run('handle_key',stop='redraw')
        self.assertEqual(m.get('key_count'),4)
        m.reg['$t1']=ord('q'); m.run('handle_key')
        self.assertEqual(m.reg['$v0'],10)

    def test_startup_and_render_with_large_hand(self):
        m=Machine(); m.run('main',stop='game_loop')
        self.assertEqual(sum(x != 0 for x in m.cells()),35)
        m.set('held_bubble_count',98); m.set('held_bubble_colour',2)
        m.run('redraw',stop='game_loop')
        display=[x for x in m.mem if 0x10008000 <= x < 0x10010000]
        self.assertTrue(all(x < 0x10009000 for x in display))

if __name__ == '__main__': unittest.main()
