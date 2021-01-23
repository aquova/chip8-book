# Opcodes Table {#ot}

Understanding the Opcode column:

- Any hexadecimal digits (0-9, A-F) that appear in an opcode are interpreted literally, and are used to determine the operation in question.
- The X or Y wild card uses the value stored in VX/VY.
- N refers to a literal hexadecimal value. NN or NNN refer to two or three digit hex numbers respectively.

Example: The instruction 0xD123 would match with the `DXYN` opcode, where VX is V1, VY is V2, and N is 3 (draw a 8x3 sprite at (V1, V2))

| Opcode |                      Description                             |                                         Notes                                         |
| ------ | ------------------------------------------------------------ | ------------------------------------------------------------------------------------- |
| 0000   | Nop                                                          | Do nothing, progress to next opcode                                                   |
| 00E0   | Clear screen                                                 |                                                                                       |
| 00EE   | Return from subroutine                                       |                                                                                       |
| 1NNN   | Jump to address 0xNNN                                        |                                                                                       |
| 2NNN   | Call 0xNNN                                                   | Enter subroutine at 0xNNN, adding current PC onto stack so we can return here         |
| 3XNN   | Skip if VX == 0xNN                                           |                                                                                       |
| 4XNN   | Skip if VX != 0xNN                                           |                                                                                       |
| 5XY0   | Skip if VX == VY                                             |                                                                                       |
| 6XNN   | VX = 0xNN                                                    |                                                                                       |
| 7XNN   | VX += 0xNN                                                   | Doesn't affect carry flag                                                             |
| 8XY0   | VX = VY                                                      |                                                                                       |
| 8XY1   | VX \|= VY                                                    |                                                                                       |
| 8XY2   | VX &= VY                                                     |                                                                                       |
| 8XY3   | VX ^= VY                                                     |                                                                                       |
| 8XY4   | VX += VY                                                     | Sets VF if carry                                                                      |
| 8XY5   | VX -= VY                                                     | Clears VF if borrow                                                                   |
| 8XY6   | VX >>= 1                                                     | Store dropped bit in VF                                                               |
| 8XY7   | VX = VY - VX                                                 | Clears VF if borrow                                                                   |
| 8XYE   | VX <<= 1                                                     | Store dropped bit in VF                                                               |
| 9XY0   | Skip if VX != VY                                             |                                                                                       |
| ANNN   | I = 0xNNN                                                    |                                                                                       |
| BNNN   | Jump to V0 + 0xNNN                                           |                                                                                       |
| CXNN   | VX = rand() & 0xNN                                           |                                                                                       |
| DXYN   | Draw sprite at (VX, VY)                                      | Sprite is 0xN pixels tall, on/off based on value in I, VF set if any pixels flipped   |
| EX9E   | Skip if key index in VX is pressed                           |                                                                                       |
| EXA1   | Skip if key index in VX isn't pressed                        |                                                                                       |
| FX07   | VX = Delay Timer                                             |                                                                                       |
| FX0A   | Waits for key press, stores index in VX                      | Blocking operation                                                                    |
| FX15   | Delay Timer = VX                                             |                                                                                       |
| FX18   | Sound Timer = VX                                             |                                                                                       |
| FX1E   | I += VX                                                      |                                                                                       |
| FX29   | Set I to address of font character in VX                     |                                                                                       |
| FX33   | Stores BCD encoding of VX into I                             |                                                                                       |
| FX55   | Stores V0 thru VX into RAM address starting at I             | Inclusive range                                                                       |
| FX65   | Fills V0 thru VX with RAM values starting at address in I    | Inclusive                                                                             |

\newpage
