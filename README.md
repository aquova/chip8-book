# An Introduction to Chip-8 Emulation using the Rust Programming Language

https://github.com/aquova/chip8-book

This is a introductory tutorial for how to develop your first Chip-8 emulator using the Rust language, targeting both desktop computers and web browsers via WebAssembly. This assumes no prior emulation experience, and only basic knowledge of Rust. The guide first gives a general overview of the different components of what emulation is, how all of the parts of the emulated system work, and what steps the emulation developer needs to implement them. Following this is a step-by-step walkthrough of the implementation of a Chip-8 emulator, describing each section of code and why it is needed.

- Source code for the completed emulator is found in `code`
- Source code for the PDF book is in `src`
- Sample Chip-8 ROMs are in `roms`

You can download the latest copy of the book here: https://github.com/aquova/chip8-book/releases

To build a copy of the PDF yourself, first install [pandoc](https://pandoc.org/) then run `make pdf` (or `make epub` for an ePub version). Details on how to setup the build environment for the source code are provided in the PDF, but once installed the completed emulator can be built with `make desktop` or `make web`

## Credits

The provided Chip-8 games are supplied from [Zophar's Domain](https://www.zophar.net/pdroms/chip8/chip-8-games-pack.html). Original author unknown.
