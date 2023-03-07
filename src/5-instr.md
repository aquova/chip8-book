# Opcode Execution

In the previous section, we fetched our opcode and were preparing to decode which instruction it corresponds to to execute that instruction. Currently, our `tick` function looks like this:

```rust
pub fn tick(&mut self) {
    // Fetch
    let op = self.fetch();
    // Decode
    // Execute
}
```

This implies that decode and execute will be their own separate functions. While they could be, for Chip-8 it's easier to simply perform the operation as we determine it, rather than involving another function call. Our `tick` function thus becomes this:

```rust
pub fn tick(&mut self) {
    // Fetch
    let op = self.fetch();
    // Decode & execute
    self.execute(op);
}

fn execute(&mut self, op: u16) {
    // TODO
}
```

Our next step is to *decode*, or determine exactly which operation we're dealing with. The [Chip-8 opcode cheatsheet](#ot) has all of the available opcodes, how to interpret their parameters, and some notes on what they mean. You will need to reference this often. For a complete emulator, each and every one of them must be implemented.

## Pattern Matching

Fortunately, Rust has a very robust and useful pattern matching feature we can use to our advantage. However, we will need to separate out each hex "digit" before we do so.

```rust
fn execute(&mut self, op: u16) {
    let digit1 = (op & 0xF000) >> 12;
    let digit2 = (op & 0x0F00) >> 8;
    let digit3 = (op & 0x00F0) >> 4;
    let digit4 = op & 0x000F;
}
```

Perhaps not the cleanest code, but we need each hex digit separately. From here, we can create a `match` statement where we can specify the patterns for all of our opcodes:

```rust
fn execute(&mut self, op: u16) {
    let digit1 = (op & 0xF000) >> 12;
    let digit2 = (op & 0x0F00) >> 8;
    let digit3 = (op & 0x00F0) >> 4;
    let digit4 = op & 0x000F;

    match (digit1, digit2, digit3, digit4) {
        (_, _, _, _) => unimplemented!("Unimplemented opcode: {}", op),
    }
}
```

Rust's `match` statement demands that all possible options be taken into account which is done with the `_` variable, which captures "everything else". Inside, we'll use the `unimplemented!` macro to cause the program to panic if it reaches that point. By the time we finish adding all opcodes, the Rust compiler demands that we still have an "everything else" statement, but we should never hit it.

While a long `match` statement would certainly work for other architectures, it is usually more common to implement instructions in their own functions, and either use a lookup table or programmatically determine which function is correct. Chip-8 is somewhat unusual because it stores instruction parameters into the opcode itself, meaning we need a lot of wild cards to match the instructions. Since there are a relatively small number of them, a `match` statement works well here.

With the framework setup, let's dive in!

## Intro to Implementing Opcodes

The following pages individually discuss how all of Chip-8's instructions work, and include code of how to implement them. You are welcome to simply follow along and implement instruction by instruction, but before you do that, you may want to look forward to the [next section](#dfe) and begin working on some of the frontend code. Currently we have no way of actually running our emulator, and it may be useful to some to be able to attempt to load and run a game for debugging. However, do remember that the emulator will likely crash rather quickly unless all of the instructions are implemented. Personally, I prefer to work on the instructions first before working on the other moving parts (hence why this guide is laid out the way it is).

With that disclaimer out of the way, let's proceed to working on each of the Chip-8 instructions in turn.

### 0000 - Nop

Our first instruction is the simplest one - do nothing. This may seem like a silly one to have, but sometimes it's needed for timing or alignment purposes. In any case, we simply need to move on to the next opcode (which was already done in `fetch`), and return.

```rust
match (digit1, digit2, digit3, digit4) {
    // NOP
    (0, 0, 0, 0) => return,
    (_, _, _, _) => unimplemented!("Unimplemented opcode: {}", op),
}
```

### 00E0 - Clear screen

Opcode 0x00E0 is the instruction to clear the screen, which means we need to reset our screen buffer to be empty again.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // CLS
    (0, 0, 0xE, 0) => {
        self.screen = [false; SCREEN_WIDTH * SCREEN_HEIGHT];
    },

    // -- Unchanged code omitted --
}
```

### 00EE - Return from Subroutine

We haven't yet spoken about subroutines (aka functions) and how they work. Entering into a subroutine works in the same way as a plain jump; we move the PC to the specified address and resume execution from there. Unlike a jump, a subroutine is expected to complete at some point, and we will need to return back to the point where we entered. This is where our stack comes in. When we enter a subroutine, we simply push our address onto the stack, run the routine's code, and when we're ready to return we pop that value off our stack and execute from that point again. A stack also allows us to maintain return addresses for nested subroutines while ensuring they are returned in the correct order.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // RET
    (0, 0, 0xE, 0xE) => {
        let ret_addr = self.pop();
        self.pc = ret_addr;
    },

    // -- Unchanged code omitted --
}
```

### 1NNN - Jump

The jump instruction is pretty easy to add, simply move the PC to the given address.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // JMP NNN
    (1, _, _, _) => {
        let nnn = op & 0xFFF;
        self.pc = nnn;
    },

    // -- Unchanged code omitted --
}
```

The main thing to notice here is that this opcode is defined by '0x1' being the most significant digit. The other digits are used as parameters for this operation, hence the `_` placeholder in our match statement, here we want anything starting with a 1, but ending in any three digits to enter this statement.

### 2NNN - Call Subroutine

The opposite of our 'Return from Subroutine' operation, we are going to add our current PC to the stack, and then jump to the given address. If you skipped straight here, I recommend reading the *Return* section for additional context.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // CALL NNN
    (2, _, _, _) => {
        let nnn = op & 0xFFF;
        self.push(self.pc);
        self.pc = nnn;
    },

    // -- Unchanged code omitted --
}
```

### 3XNN - Skip next if VX == NN

This opcode is first of a few that follow a similar pattern. For those who are unfamiliar with assembly, being able to skip a line gives similar functionality to an if-else block. We can make a comparison, and if true go to one instruction, and if false go somewhere else. This is also the first opcode which will use one of our *V registers*. In this case, the second digit tells us which register to use, while the last two digits provide the raw value.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // SKIP VX == NN
    (3, _, _, _) => {
        let x = digit2 as usize;
        let nn = (op & 0xFF) as u8;
        if self.v_reg[x] == nn {
            self.pc += 2;
        }
    },

    // -- Unchanged code omitted --
}
```

The implementation works like this: since we already have the second digit saved to a variable, we will reuse it for our 'X' index, although cast to a `usize`, as Rust requires all array indexing to be done with a `usize` variable. If that value stored in that register equals `nn`, then we skip the next opcode, which is the same as skipping our PC ahead by two bytes.

### 4XNN - Skip next if VX != NN

This opcode is exactly the same as the previous, except we skip if the compared values are not equal.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // SKIP VX != NN
    (4, _, _, _) => {
        let x = digit2 as usize;
        let nn = (op & 0xFF) as u8;
        if self.v_reg[x] != nn {
            self.pc += 2;
        }
    },

    // -- Unchanged code omitted --
}
```

### 5XY0 - Skip next if VX == VY

A similar operation again, however we now use the third digit to index into another *V Register*. You will also notice that the least significant digit is not used in the operation. This opcode requires it to be 0.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // SKIP VX == VY
    (5, _, _, 0) => {
        let x = digit2 as usize;
        let y = digit3 as usize;
        if self.v_reg[x] == self.v_reg[y] {
            self.pc += 2;
        }
    },

    // -- Unchanged code omitted --
}
```

### 6XNN - VX = NN

Set the *V Register* specified by the second digit to the value given.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX = NN
    (6, _, _, _) => {
        let x = digit2 as usize;
        let nn = (op & 0xFF) as u8;
        self.v_reg[x] = nn;
    },

    // -- Unchanged code omitted --
}
```

### 7XNN - VX += NN

This operation adds the given value to the VX register. In the event of an overflow, Rust will panic, so we need to use a different method than the typical addition operator. Note also that while Chip-8 has a carry flag (more on that later), it is not modified by this operation.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX += NN
    (7, _, _, _) => {
        let x = digit2 as usize;
        let nn = (op & 0xFF) as u8;
        self.v_reg[x] = self.v_reg[x].wrapping_add(nn);
    },

    // -- Unchanged code omitted --
}
```

### 8XY0 - VX = VY

Like the `VX = NN` operation, but the source value is from the VY register.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX = VY
    (8, _, _, 0) => {
        let x = digit2 as usize;
        let y = digit3 as usize;
        self.v_reg[x] = self.v_reg[y];
    },

    // -- Unchanged code omitted --
}
```

### 8XY1, 8XY2, 8XY3 - Bitwise operations

The `8XY1`, `8XY2`, and `8XY3` opcodes are all similar functions, so rather than repeat myself three times over, I'll implement the *OR* operation, and allow the reader to implement the other two.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX |= VY
    (8, _, _, 1) => {
        let x = digit2 as usize;
        let y = digit3 as usize;
        self.v_reg[x] |= self.v_reg[y];
    },

    // -- Unchanged code omitted --
}
```

### 8XY4 - VX += VY

This operation has two aspects to make note of. Firstly, this operation has the potential to overflow, which will cause a panic in Rust if not handled correctly. Secondly, this operation is the first to utilize the `VF` flag register. I've touched upon it previously, but while the first 15 *V* registers are general usage, the final 16th (0xF) register doubles as the *flag register*. Flag registers are common in many CPU processors; in the case of Chip-8 it also stores the *carry flag*, basically a special variable that notes if the last application operation resulted in an overflow/underflow. Here, if an overflow were to happen, we need to set the `VF` to be 1, or 0 if not. With these two aspects in mind, we will use Rust's `overflowing_add` attribute, which will return a tuple of both the wrapped sum, as well as a boolean of whether an overflow occurred.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX += VY
    (8, _, _, 4) => {
        let x = digit2 as usize;
        let y = digit3 as usize;

        let (new_vx, carry) = self.v_reg[x].overflowing_add(self.v_reg[y]);
        let new_vf = if carry { 1 } else { 0 };

        self.v_reg[x] = new_vx;
        self.v_reg[0xF] = new_vf;
    },

    // -- Unchanged code omitted --
}
```
### 8XY5 - VX -= VY

This is the same operation as the previous opcode, but with subtraction rather than addition. The key distinction is that the `VF` carry flag works in the opposite fashion. The addition operation would set the flag to 1 if an overflow occurred, here if an underflow occurs, it is set to 0, and vice versa. The `overflowing_sub` method will be of use to us here.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX -= VY
    (8, _, _, 5) => {
        let x = digit2 as usize;
        let y = digit3 as usize;

        let (new_vx, borrow) = self.v_reg[x].overflowing_sub(self.v_reg[y]);
        let new_vf = if borrow { 0 } else { 1 };

        self.v_reg[x] = new_vx;
        self.v_reg[0xF] = new_vf;
    },

    // -- Unchanged code omitted --
}
```

### 8XY6 - VX >>= 1

This operation performs a single right shift on the value in VX, with the bit that was dropped off being stored into the `VF` register. Unfortunately, there isn't a built-in Rust `u8` operator to catch the dropped bit, so we will have to do it ourself.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX >>= 1
    (8, _, _, 6) => {
        let x = digit2 as usize;
        let lsb = self.v_reg[x] & 1;
        self.v_reg[x] >>= 1;
        self.v_reg[0xF] = lsb;
    },

    // -- Unchanged code omitted --
}
```

### 8XY7 - VX = VY - VX

This operation works the same as the previous VX -= VY operation, but with the operands in the opposite direction.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX = VY - VX
    (8, _, _, 7) => {
        let x = digit2 as usize;
        let y = digit3 as usize;

        let (new_vx, borrow) = self.v_reg[y].overflowing_sub(self.v_reg[x]);
        let new_vf = if borrow { 0 } else { 1 };

        self.v_reg[x] = new_vx;
        self.v_reg[0xF] = new_vf;
    },

    // -- Unchanged code omitted --
}
```

### 8XYE - VX <<= 1

Similar to the right shift operation, but we store the value that is overflowed in the flag register.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX <<= 1
    (8, _, _, 0xE) => {
        let x = digit2 as usize;
        let msb = (self.v_reg[x] >> 7) & 1;
        self.v_reg[x] <<= 1;
        self.v_reg[0xF] = msb;
    },

    // -- Unchanged code omitted --
}
```

### 9XY0 - Skip if VX != VY

Done with the 0x8000 operations, it's time to go back and add an opcode that was notably missing, skipping the next line if VX != VY. This is the same code as the 5XY0 operation, but with an inequality.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // SKIP VX != VY
    (9, _, _, 0) => {
        let x = digit2 as usize;
        let y = digit3 as usize;
        if self.v_reg[x] != self.v_reg[y] {
            self.pc += 2;
        }
    },

    // -- Unchanged code omitted --
}
```

### ANNN - I = NNN

This is the first instruction to utilize the *I Register*, which will be used in several additional instructions, primarily as an address pointer to RAM. In this case, we are simply setting it to the 0xNNN value encoded in this opcode.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // I = NNN
    (0xA, _, _, _) => {
        let nnn = op & 0xFFF;
        self.i_reg = nnn;
    },

    // -- Unchanged code omitted --
}
```

### BNNN - Jump to V0 + NNN

While previous instructions have used the *V Register* specified within the opcode, this instruction always uses the first *V0* register. This operation moves the PC to the sum of the value stored in *V0* and the raw value 0xNNN supplied in the opcode.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // JMP V0 + NNN
    (0xB, _, _, _) => {
        let nnn = op & 0xFFF;
        self.pc = (self.v_reg[0] as u16) + nnn;
    },

    // -- Unchanged code omitted --
}
```

### CXNN - VX = rand() & NN

Finally, something to shake up the monotony! This opcode is Chip-8's random number generation, with a slight twist, in that the random number is then AND'd with the lower 8-bits of the opcode. While the Rust development team has released a random generation crate, it is not part of its standard library, so we shall have to add it to our project.

In `chip8_core/Cargo.toml`, add the following line somewhere under `[dependencies]`:

```toml
rand = "^0.7.3"
```

Note: If you are planning on following this guide completely to its end, there will be a future change to how we include this library for web browser support. However, at this stage in the project, it is enough to specify it as is.

Time now to add RNG support and implement this opcode. At the top of `lib.rs`, we will need to import a function from the `rand` crate:

```rust
use rand::random;
```

We will then use the `random` function when implementing our opcode:

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX = rand() & NN
    (0xC, _, _, _) => {
        let x = digit2 as usize;
        let nn = (op & 0xFF) as u8;
        let rng: u8 = random();
        self.v_reg[x] = rng & nn;
    },

    // -- Unchanged code omitted --
}
```

Note that specifying `rng` as a `u8` variable is necessary for the `random()` function to know which type it is supposed to generate.

### DXYN - Draw Sprite

This is probably the single most complicated opcode, so allow me to take a moment to describe how it works in detail. Rather than drawing individual pixels or rectangles to the screen at a time, the Chip-8 display works by drawing *sprites*, images stored in memory that are copied to the screen at a specified (x, y). For this opcode, the second and third digits give us which *V Registers* we are to fetch our (x, y) coordinates from. So far so good. Chip-8's sprites are always 8 pixels wide, but can be a variable number of pixels tall, from 1 to 16. This is specified in the final digit of our opcode. I mentioned earlier that the *I Register* is used frequently to store an address in memory, and this is the case here; our sprites are stored row by row *beginning* at the address stored in *I*. So if we are told to draw a 3px tall sprite, the first row's data is stored at \*I, followed by \*I + 1, then \*I + 2. This explains why all sprites are 8 pixels wide, each row is assigned a byte, which is 8-bits, one for each pixel, black or white. The last detail to note is that if *any* pixel is flipped from white to black or vice versa, the *VF* is set (and cleared otherwise). With these things in mind, let's begin.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // DRAW
    (0xD, _, _, _) => {
        // Get the (x, y) coords for our sprite
        let x_coord = self.v_reg[digit2 as usize] as u16;
        let y_coord = self.v_reg[digit3 as usize] as u16;
        // The last digit determines how many rows high our sprite is
        let num_rows = digit4;

        // Keep track if any pixels were flipped
        let mut flipped = false;
        // Iterate over each row of our sprite
        for y_line in 0..num_rows {
            // Determine which memory address our row's data is stored
            let addr = self.i_reg + y_line as u16;
            let pixels = self.ram[addr as usize];
            // Iterate over each column in our row
            for x_line in 0..8 {
                // Use a mask to fetch current pixel's bit. Only flip if a 1
                if (pixels & (0b1000_0000 >> x_line)) != 0 {
                    // Sprites should wrap around screen, so apply modulo
                    let x = (x_coord + x_line) as usize % SCREEN_WIDTH;
                    let y = (y_coord + y_line) as usize % SCREEN_HEIGHT;

                    // Get our pixel's index for our 1D screen array
                    let idx = x + SCREEN_WIDTH * y;
                    // Check if we're about to flip the pixel and set
                    flipped |= self.screen[idx];
                    self.screen[idx] ^= true;
                }
            }
        }

        // Populate VF register
        if flipped {
            self.v_reg[0xF] = 1;
        } else {
            self.v_reg[0xF] = 0;
        }
    },

    // -- Unchanged code omitted --
}
```

### EX9E - Skip if Key Pressed

Time at last to introduce user input. When setting up our emulator object, I mentioned that there are 16 possible keys numbered 0 to 0xF. This instruction checks if the index stored in VX is pressed, and if so, skips the next instruction.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // SKIP KEY PRESS
    (0xE, _, 9, 0xE) => {
        let x = digit2 as usize;
        let vx = self.v_reg[x];
        let key = self.keys[vx as usize];
        if key {
            self.pc += 2;
        }
    },

    // -- Unchanged code omitted --
}
```

### EXA1 - Skip if Key Not Pressed

Same as the previous instruction, however this time the next instruction is skipped if the key in question is not being pressed.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // SKIP KEY RELEASE
    (0xE, _, 0xA, 1) => {
        let x = digit2 as usize;
        let vx = self.v_reg[x];
        let key = self.keys[vx as usize];
        if !key {
            self.pc += 2;
        }
    },

    // -- Unchanged code omitted --
}
```

### FX07 - VX = DT

I mentioned the use of the *Delay Timer* when we were setting up the emulation structure. This timer ticks down every frame until reaching zero. However, that operation happens automatically, it would be really useful to be able to actually see what's in the *Delay Timer* for our game's timing purposes. This instruction does just that, and stores the current value into one of the *V Registers* for us to use.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // VX = DT
    (0xF, _, 0, 7) => {
        let x = digit2 as usize;
        self.v_reg[x] = self.dt;
    },

    // -- Unchanged code omitted --
}
```

### FX0A - Wait for Key Press

While we already had instructions to check if keys are either pressed or released, this instruction does something very different. Unlike those, which checked the key state and then moved on, this instruction is *blocking*, meaning the whole game will pause and wait for as long as it needs to until the player presses a key. That means it needs to loop endlessly until something in our `keys` array turns true. Once a key is found, it is stored into VX. If more than one key is currently being pressed, it takes the lowest indexed one.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // WAIT KEY
    (0xF, _, 0, 0xA) => {
        let x = digit2 as usize;
        let mut pressed = false;
        for i in 0..self.keys.len() {
            if self.keys[i] {
                self.v_reg[x] = i as u8;
                pressed = true;
                break;
            }
        }

        if !pressed {
            // Redo opcode
            self.pc -= 2;
        }
    },

    // -- Unchanged code omitted --
}
```

You may be looking at this implementation and asking "why are we resetting the opcode and going through the entire fetch sequence again, rather than simply doing this in a loop?". Simply put, while we want this instruction to block future instructions from running, we do not want to block any new key presses from being registered. By remaining in a loop, we would prevent our key press code from ever running, causing this loop to never end. Perhaps inefficient, but much simpler than some sort of asynchronous checking.

### FX15 - DT = VX

This operation works the other direction from our previous *Delay Timer* instruction. We need someway to reset the *Delay Timer* to a value, and this instruction allows us to copy over a value from a *V Register* of our choosing.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // DT = VX
    (0xF, _, 1, 5) => {
        let x = digit2 as usize;
        self.dt = self.v_reg[x];
    },

    // -- Unchanged code omitted --
}
```

### FX18 - ST = VX

Almost the exact same instruction as the previous, however this time we are going to store the value from VX into our *Sound Timer*.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // ST = VX
    (0xF, _, 1, 8) => {
        let x = digit2 as usize;
        self.st = self.v_reg[x];
    },

    // -- Unchanged code omitted --
}
```

### FX1E - I += VX

Instruction ANNN sets I to the encoded 0xNNN value, but sometimes it is useful to be able to simply increment the value. This instruction takes the value stored in VX and adds it to the *I Register*. In the case of an overflow, the register should simply roll over back to 0, which we can accomplish with Rust's `wrapping_add` method.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // I += VX
    (0xF, _, 1, 0xE) => {
        let x = digit2 as usize;
        let vx = self.v_reg[x] as u16;
        self.i_reg = self.i_reg.wrapping_add(vx);
    },

    // -- Unchanged code omitted --
}
```

### FX29 - Set I to Font Address

This is another tricky instruction where it may not be clear how to progress at first. If you recall, we stored an array of font data at the very beginning of RAM when initializing the emulator. This instruction wants us to take in the number to print on screen (from 0 to 0xF), and store the RAM address of that sprite into the *I Register*. We are actually free to store those sprites anywhere we wanted, so long as we are consistent and point to them correctly here. However, we stored them in a very convenient location, at the beginning of RAM. Let me show you what I mean by printing out some of the sprites and their RAM locations.

| Character | RAM Address |
| --------- | ----------- |
| 0         | 0           |
| 1         | 5           |
| 2         | 10          |
| 3         | 15          |
| ...       | ...         |
| E (14)    | 70          |
| F (15)    | 75          |

You'll notice that since all of our font sprites take up five bytes each, their RAM address is simply their value times 5. If we happened to store the fonts in a different RAM address, we could still follow this rule, however we'd have to apply an offset to where the block begins.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // I = FONT
    (0xF, _, 2, 9) => {
        let x = digit2 as usize;
        let c = self.v_reg[x] as u16;
        self.i_reg = c * 5;
    },

    // -- Unchanged code omitted --
}
```

### FX33 - I = BCD of VX

Most of the instructions for Chip-8 are rather self-explanitory, and can be implemented quite easily just by hearing a vague description. However, there are a few that are quite tricky, such as drawing to a screen and this one, storing the [Binary-Coded Decimal](https://en.wikipedia.org/wiki/Binary-coded_decimal) of a number stored in VX into the *I Register*. I encourage you to read up on BCD if you are unfamiliar with it, but a brief refresher goes like this. In this tutorial, we've been using hexadecimal quite a bit, which works by converting our normal decimal numbers into base-16, which is more easily understood by computers. For example, the decimal number 100 would become 0x64. This is good for computers, but not very accessible to humans, and certainly not to the general audience who are going to play your games. The main purpose of BCD is to convert a hexadecimal number back into a pseudo-decimal number to print out for the user, such as for your points or high scores. So while Chip-8 might store 0x64 internally, fetching its BCD would give us `0x1, 0x0, 0x0`, which we could print to the screen as "100". You'll notice that we've gone from one byte to three in order to store all three digits of our number, which is why we are going to store the BCD into RAM, beginning at the address currently in the *I Register* and moving along. Given that VX stores 8-bit numbers, which range from 0 to 255, we are always going to end up with three bytes, even if some are zero.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // BCD
    (0xF, _, 3, 3) => {
        let x = digit2 as usize;
        let vx = self.v_reg[x] as f32;

        // Fetch the hundreds digit by dividing by 100 and tossing the decimal
        let hundreds = (vx / 100.0).floor() as u8;
        // Fetch the tens digit by dividing by 10, tossing the ones digit and the decimal
        let tens = ((vx / 10.0) % 10.0).floor() as u8;
        // Fetch the ones digit by tossing the hundreds and the tens
        let ones = (vx % 10.0) as u8;

        self.ram[self.i_reg as usize] = hundreds;
        self.ram[(self.i_reg + 1) as usize] = tens;
        self.ram[(self.i_reg + 2) as usize] = ones;
    },

    // -- Unchanged code omitted --
}
```

For this implementation, I converted our VX value first into a `float`, so that I could use division and modulo arithmetic to get each decimal digit. This is not the fastest implementation nor is it probably the shortest. However, it is one of the easiest to understand. I'm sure there are some highly binary-savvy readers who are disgusted that I did it this way, but this solution is not for them. This is for readers who have never seen BCD before, where losing some speed for greater understanding is a better trade-off. However, once you have this implemented, I would encourage everyone to go out and look up more efficient BCD algorithms to add a bit of easy optimization into your code.

### FX55 - Store V0 - VX into I

We're on the home stretch! These final two instructions populate our *V Registers* V0 thru the specified VX (inclusive) with the same range of values from RAM, beginning with the address in the *I Register*. This first one stores the values into RAM, while the next one will load them the opposite way.

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // STORE V0 - VX
    (0xF, _, 5, 5) => {
        let x = digit2 as usize;
        let i = self.i_reg as usize;
        for idx in 0..=x {
            self.ram[i + idx] = self.v_reg[idx];
        }
    },

    // -- Unchanged code omitted --
}
```

### FX65 - Load I into V0 - VX

```rust
match (digit1, digit2, digit3, digit4) {
    // -- Unchanged code omitted --

    // LOAD V0 - VX
    (0xF, _, 6, 5) => {
        let x = digit2 as usize;
        let i = self.i_reg as usize;
        for idx in 0..=x {
            self.v_reg[idx] = self.ram[i + idx];
        }
    },

    // -- Unchanged code omitted --
}
```

### Final Thoughts

That's it! With this, we now have a fully implemented Chip-8 CPU. You may have noticed a lot of possible opcode values are never covered, particularly in the 0x0000, 0xE000, and 0xF000 ranges. This is okay. These opcodes are left as undefined by the original design, and thus if any game attempts to use them it will lead to a runtime panic. If you are still curious following the completion of this emulator, there are a number of Chip-8 extensions which do fill in some of these gaps to add additional functionality, but they will not be covered by this guide.

\newpage
