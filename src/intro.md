\newpage

# An Introduction to Video Game Emulation with Rust

Developing a video game emulator is becoming an increasingly popular hobby project for developers. It requires knowledge of low-level hardware, modern programming languages, and graphics systems to successfully create one. It is an incredibly rewarding and excellent learning project; not only does it have clear goals, but it also very rewarding to successfully play games on an emulator you've written yourself. I am still a relatively new emulation developer, but I wouldn't have been able to reach the place I am now if it weren't for excellent guides and tutorials online. To that end, I wanted to give back to the community by writing a guide with some of the tricks I picked up, in hopes it is useful for someone else.

## Intro to Chip-8

Our target system is the [Chip-8](https://en.wikipedia.org/wiki/CHIP-8). The Chip-8 has become the "Hello World" for emulation development of a sort. While you might be tempted to begin with something more exciting like the NES or Game Boy, these are a level of complexity higher than the Chip-8 (although don't let that stop you if you're dead set on trying it!). The Chip-8 has a 1-bit monochrome display, a simple 1-channel single tone audio, and only 35 instructions (compared to ~500 for the Game Boy), but more on that later. This guide will cover the technical specifics of the Chip-8, what hardware systems need to be emulated and how, and how to interact with the user. This guide will also only focus on the original Chip-8 specification, and will not implement any of the many proposed extensions that have been created over the years, such as the Super Chip-8, Chip-16, or XO-Chip. Many of these were created independently of each other, and thus add contradictory features to one another. If you are curious, an extensive overview of many of these can be found [here](https://chip-8.github.io/extensions/).

## Chip-8 Technical Specifications

Some additional technical details about the Chip-8, which you will become very acquainted with.

- A 64x32 monochrome display, drawn to via sprites that are always 8px wide and between 1 and 16 pixels tall.

- Sixteen 8-bit general purpose registers, referred to as V0 thru VF. VF also doubles as the flag register for overflow operations.

- 16-bit program counter

- Single 16-bit register used as a pointer for memory access, called the *I Register*.

- An unstandardised amount of RAM, however most emulators allocate 4 KB.

- 16-bit stack used for calling and returning from subroutines.

- 16-key keyboard input.

- Two special registers which decrease each frame and trigger upon reaching zero:
    - Delay timer - Used for time-based game events.
    - Sound timer - Used to trigger the audio beep.

## Intro to Rust

Emulators can be (and have been) written in just about any programming language. This guide will specifically use the [Rust programming language](https://www.rust-lang.org/), although the steps outlined here are applicable to any language, in a higher level sense. Rust offers a number of great advantages - it is a compiled language with targets for the major platforms and it has an active community of external libraries we can utilize for our project. There is also great support for [WebAssembly](https://en.wikipedia.org/wiki/WebAssembly), which will allow us to recompile our code to work in a browser with a minimal amount of tweaking. This guide will assume you understand the basics of the Rust language and programming as a whole. I will be explaining the code as we go along, so a basic understanding should be enough, but as Rust has a notoriously high learning curve, I would recommend reading and referencing the excellent [official Rust book](https://doc.rust-lang.org/stable/book/title-page.html) on any concepts that are unfamiliar to you as the guide progresses. This guide also assumes that you have Rust installed and working correctly. Please consult the [installation instructions](https://www.rust-lang.org/tools/install) for your platform if need be.

## What you will need

Apart from the Rust language, there are a few items you will need before you begin.

### Text Editor

While you are free to use your favorite editor of choice, for those who are looking for an editor well suited for Rust, there are two I recommend which offer features like syntax highlighting, code suggestions, and debugger support.

- [Visual Studio Code](https://code.visualstudio.com/) is the editor I personally use for Rust, in combination with the [rust-analyzer](https://rust-analyzer.github.io/) extension.

- While JetBrains does not offer a dedicated Rust IDE, there is a Rust extension for many of its other products. In particular, the [extension](https://intellij-rust.github.io/) for [CLion](https://www.jetbrains.com/clion/) has additional functionality that the others do not, such as integrated debugger support. Keep in mind that CLion is a paid product, although it offers a 30 day trial as well as extended free periods for students.

If you do not care for any of these, Rust syntax and autocompletion plugins exist for many other editors, and it can be debugged fairly easily with many other debuggers, such as gdb.

### Test ROMs

An emulator isn't much use if you have nothing to run! Included with the source code for this book are a number of commonly distributed Chip-8 programs, which can also be found [here](https://www.zophar.net/pdroms/chip8/chip-8-games-pack.html). Some of these games will be shown as an example throughout this guide, but there are many more games in existence to use as well.

### Misc.

There are a few other items that may be helpful as we progress.

- If you are unfamiliar with [hexadecimal](https://en.wikipedia.org/wiki/Hexadecimal), we will be using it throughout the project, so it might be worth reading a refresher if its not something you're comfortable with.

- Since Chip-8 games are in a hexadecimal format, it is often helpful to be able to view the raw hex values as you debug. Standard text editors typically don't have support for viewing files in hexadecimal, instead a specialized [hex editor](https://en.wikipedia.org/wiki/Comparison_of_hex_editors) is required. Many offer similar features, but I personally like the [Reverse Engineer's Hex Editor](https://github.com/solemnwarning/rehex).

With that set, let's begin!

\newpage
