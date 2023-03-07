# Introduction to WebAssembly

This section will discuss how to take our finished emulator and configure it to run in a web browser via a relatively new technology called *WebAssembly*. I encourage you to [read more](https://en.wikipedia.org/wiki/WebAssembly) about WebAssembly. It is a format for compiling programs into a binary executable, similar in scope to an .exe, but are meant to be run within a web browser. It is supported by all of the major web browsers, and is a cross-company standard being developed between them. This means that instead of having to write web code in JavaScript or other web-centric languages, you can write it in any language that supports compilation of .wasm files and still be able to run in a browser. At the time of writing, C, C++, and Rust are the major languages which support it, fortunately for us.

## Setting Up

While we could cross-compile to the WebAssembly Rust targets ourselves, a useful set of tools called [wasm-pack](https://github.com/rustwasm/wasm-pack) has been developed to allow us to easily compile to WebAssembly without manually adding the appropriate targets and dependencies. You will need to install it via:

```
$ cargo install wasm-pack
```

If you are on Windows the install might fail at the openssl-sys crate https://github.com/rustwasm/wasm-pack/issues/1108 and you will have to download it manually from https://rustwasm.github.io/wasm-pack/

I also mentioned that we will need to make a slight adjustment to our  `chip8_core` module to allow it to compile correctly to the `wasm` target. Rust uses a system called `wasm-bindgen` to create hooks that will work with WebAssembly. All of the `std` code we use is already fine, however we also use the `rand` crate in our backend, and it is not currently set to work correctly. Fortunately, it does support the functionality, we just need to enable it. In `chip8_core/Cargo.toml` we need to change

```toml
[dependencies]
rand = "^0.7.3"
```

to

```toml
[dependencies]
rand = { version = "^0.7.3", features = ["wasm-bindgen"] }
```

All this does is specifies that we will require `rand` to include the `wasm-bindgen` feature upon compilation, which will allow it to work correctly in our WebAssembly binary.

Note: In the time between writing this tutorial's code and finishing the write-up, the `rand` crate updated to version 0.8. Among other changes is that the `wasm-bindgen` feature has been removed. If you are wanting to use the most up-to-date `rand` crate, it appears that WebAssembly support has been moved out into its own separate crate. Since we are only using the most basic random function, I didn't feel the need to upgrade to 0.8, but if you wish to, it appears that additional integration would be required.

That's the last time you will need to edit your  `chip8_core` module, everything else will be done in our new frontend. Let's set that up now. First, lets crate another Rust module via:

```
$ cargo init wasm --lib
```

This command may look familiar, it will create another new Rust library called `wasm`. Just like `desktop`, we will need to edit `wasm/Cargo.toml` to point to where  `chip8_core` is located.

```toml
[dependencies]
chip8_core = { path = "../chip8_core" }
```

Now, a big difference between our `desktop` and our new `wasm` is that `desktop` was an executable project, it had a `main.rs` that we would compile and run. `wasm` will not have that, it is meant to be compiled into a .wasm file that we will load into a webpage. It is the webpage that will serve as the frontend, so let's add some basic HTML boilerplate, just to get us started. Create a new folder called `web` to hold the webpage specific code, and then create `web/index.html` and add basic HTML boilerplate.

```html
<!DOCTYPE html>
<html>
    <head>
        <title>Chip-8 Emulator</title>
        <meta charset="utf-8">
    </head>
    <body>
        <h1>My Chip-8 Emulator</h1>
    </body>
</html>
```

We'll add more to it later, but for now this will suffice. Our web program will not run if you simply open the file in a web browser, you will need to start a web server first. If you have Python 3 installed, which all modern Macs and many Linux distributions do, you can simply start a web server via:

```
$ python3 -m http.server
```

Navigate to `localhost` in your web browser. If you ran this in the `web` directory, you should see our `index.html` page displayed. I've tried to find a simple, built-in way to start a local web server on Windows, and I haven't really found one. I personally use Python 3, but you are welcome to use any other similar service, such as `npm` or even some Visual Studio Code extensions. It doesn't matter which, just so they can host a local web page.

## Defining our WebAssembly API

We have our  `chip8_core` created already, but we are now missing all of the functionality we added to `desktop`. Loading a file, handling key presses, telling it when to tick, etc. On the other hand, we have a web page that (will) run JavaScript, which needs to handle inputs from the user and display items. Our `wasm` crate is what goes in the middle. It will take inputs from JavaScript and convert them into the data types required by our  `chip8_core`.

Most importantly, we also need to somehow create a `chip8_core::Emu` object and keep it in scope for the entirety of our web page.

To begin, let's include a few external crates that we will need to allow Rust to interface with JavaScript. Open up `wasm/Cargo.toml` and add the following dependencies:

```toml
[dependencies]
chip8_core = { path = "../chip8_core" }
js-sys = "^0.3.46"
wasm-bindgen = "^0.2.69"

[dependencies.web-sys]
version = "^0.3.46"
features = []
```

You'll notice that we're handling `web-sys` differently than other dependencies. That crate is structured in such a way that instead of getting everything it contains simply by including it in our `Cargo.toml`, we also need to specify additional "features" which come with the crate, but aren't available by default. Keep this file open, as we'll be adding to the `web_sys` features soon enough.

Since this crate is going to be interfacing with another language, we need to specify how they are to communicate. Without getting too deep into the details, Rust can use the C language's ABI to easily communicate with other languages that support it, and it will greatly simplify our wasm binary to do so. So, we will need to tell `cargo` to use it. Add this in `wasm/Cargo.toml` as well:

```toml
[lib]
crate-type = ["cdylib"]
```

Excellent. Now to `wasm/src/lib.rs`. Let's create a struct that will house our `Emu` object as well as all the frontend functions we need to interface with JavaScript and operate. We'll also need to include all of our public items from  `chip8_core` as well.

```rust
use chip8_core::*;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct EmuWasm {
    chip8: Emu,
}
```

Note the `#[wasm_bindgen]` tag, which tells the compiler that this struct needs to be configured for WebAssembly. Any function or struct that is going to be called from within JavaScript will need to have it. Let's also define the constructor.

```rust
use chip8_core::*;
use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub struct EmuWasm {
    chip8: Emu,
}

#[wasm_bindgen]
impl EmuWasm {
    #[wasm_bindgen(constructor)]
    pub fn new() -> EmuWasm {
        EmuWasm {
            chip8: Emu::new(),
        }
    }
}
```

Pretty straight-forward. The biggest thing to note is that the `new` method requires the special `constructor` inclusion so the compiler knows what we're trying to do.

Now we have a struct containing our `chip8` emulation core object. Here, we will implement the same methods that we needed by our `desktop` frontend, such as passing key presses/releases to the core, loading in a file, and ticking. Let's begin with ticking the CPU and the timers, as it's the easiest.

```rust
#[wasm_bindgen]
impl EmuWasm {
    // -- Unchanged code omitted --

    #[wasm_bindgen]
    pub fn tick(&mut self) {
        self.chip8.tick();
    }

    #[wasm_bindgen]
    pub fn tick_timers(&mut self) {
        self.chip8.tick_timers();
    }
}
```

That's it, these are just thin wrappers to call the corresponding functions in the  `chip8_core`. These functions don't take any input, so there's nothing fancy for them to do except, well, tick.

Remember the `reset` function we created in the  `chip8_core`, but then never used? Well, we'll get to use it now. This will be a wrapper just like the previous two functions.

```rust
#[wasm_bindgen]
pub fn reset(&mut self) {
    self.chip8.reset();
}
```

Key pressing is the first of these functions that will deviate from what was done in `desktop`. This works in a similar fashion to what we did for `desktop`, but rather than taking in an SDL key press, we'll need to accept one from JavaScript. I promised we'd add some `web-sys` features, so lets do so now. Back in `wasm/Cargo.toml` add the `KeyboardEvent` feature

```toml
[dependencies.web-sys]
version = "^0.3.46"
features = [
    "KeyboardEvent"
]
```

```rust
use web_sys::KeyboardEvent;

// -- Unchanged code omitted --

impl EmuWasm {
    // -- Unchanged code omitted --

    #[wasm_bindgen]
    pub fn keypress(&mut self, evt: KeyboardEvent, pressed: bool) {
        let key = evt.key();
        if let Some(k) = key2btn(&key) {
            self.chip8.keypress(k, pressed);
        }
    }
}

fn key2btn(key: &str) -> Option<usize> {
    match key {
        "1" => Some(0x1),
        "2" => Some(0x2),
        "3" => Some(0x3),
        "4" => Some(0xC),
        "q" => Some(0x4),
        "w" => Some(0x5),
        "e" => Some(0x6),
        "r" => Some(0xD),
        "a" => Some(0x7),
        "s" => Some(0x8),
        "d" => Some(0x9),
        "f" => Some(0xE),
        "z" => Some(0xA),
        "x" => Some(0x0),
        "c" => Some(0xB),
        "v" => Some(0xF),
        _ =>   None,
    }
}
```

This is very similar to our implementation for our `desktop`, except we are going to take in a JavaScript `KeyboardEvent`, which will result in a string for us to parse. Note that the key strings are case sensitive, so keep everything lowercase unless you want your players to hold down shift a lot.

A similar story awaits us when we load a game, it will follow a similar style, except we will need to receive and handle a JavaScript object.

```rust
use js_sys::Uint8Array;
// -- Unchanged code omitted --

impl EmuWasm {
    // -- Unchanged code omitted --

    #[wasm_bindgen]
    pub fn load_game(&mut self, data: Uint8Array) {
        self.chip8.load(&data.to_vec());
    }
}
```

The only thing remaining is our function to actually render to a screen. I'm going to create an empty function here, but we'll hold off on implementing it for now, instead we'll turn our attention back to our web page, and begin working from the other direction.

```rust
impl EmuWasm {
    // -- Unchanged code omitted --

    #[wasm_bindgen]
    pub fn draw_screen(&mut self, scale: usize) {
        // TODO
    }
}
```

We'll come back here once we get our JavaScript setup and we know exactly how we're going to draw.

## Creating our Frontend Functionality

Time to get our hands dirty in JavaScript. First, let's add some additional elements to our very bland web page. When we created the emulator to run on a PC, we used SDL to create a window to draw upon. For a web page, we will use an element HTML5 gives us called a *canvas*. We'll also go ahead and point our web page to our (currently non-existent) JS script.

```html
<!DOCTYPE html>
<html>
    <head>
        <title>Chip-8 Emulator</title>
        <meta charset="utf-8">
    </head>
    <body>
        <h1>My Chip-8 Emulator</h1>
        <label for="fileinput">Upload a Chip-8 game: </label>
        <input type="file" id="fileinput" autocomplete="off"/>
        <br/>
        <canvas id="canvas">If you see this message, then your browser doesn't support HTML5</canvas>
    </body>
    <script type="module" src="index.js"></script>
</html>
```

We added three things here, first a button which when clicked will allow the users to select a Chip-8 game to run. Secondly, the `canvas` element, which includes a brief message for any unfortunate users with an out of date browser. Finally we told our web page to also load the `index.js` script we are about to create. Note that at the time of writing, in order to load a .wasm file via JavaScript, you need to specify that it is of `module` type.

Now, let's create `index.js` and we'll define some items we'll need. First, we need to tell JavaScript to load in our WebAssembly functions. Now, we aren't going to load it in directly here. When we compile with `wasm-pack`, it will generate not only our .wasm file, but also an auto-generated JavaScript "glue" that will wrap each function we defined around a JavaScript function we then can use here.

```js
import init, * as wasm from "./wasm.js"
```

This imports all of our functions, as well as a special `init` function that will need to be called first before we can use anything from `wasm`.

Let's define some constants and do some basic setup now.

```js
import init, * as wasm from "./wasm.js"

const WIDTH = 64
const HEIGHT = 32
const SCALE = 15
const TICKS_PER_FRAME = 10
let anim_frame = 0

const canvas = document.getElementById("canvas")
canvas.width = WIDTH * SCALE
canvas.height = HEIGHT * SCALE

const ctx = canvas.getContext("2d")
ctx.fillStyle = "black"
ctx.fillRect(0, 0, WIDTH * SCALE, HEIGHT * SCALE)

const input = document.getElementById("fileinput")
```

All of this will look familiar from our `desktop` build. We fetch the HTML canvas and adjust its size to the dimension of our Chip-8 screen, plus scaled up a bit (feel free to adjust this for your preferences).

Let's create a main `run` function that will load our `EmuWasm` object and handle the main emulation.

```js
async function run() {
    await init()
    let chip8 = new wasm.EmuWasm()

    document.addEventListener("keydown", function(evt) {
        chip8.keypress(evt, true)
    })

    document.addEventListener("keyup", function(evt) {
        chip8.keypress(evt, false)
    })

    input.addEventListener("change", function(evt) {
        // Handle file loading
    }, false)
}

run().catch(console.error)
```

Here, we called the mandatory `init` function which tells our browser to initialize our WebAssembly binary before we use it. We then create our emulator backend by making a new `EmuWasm` object.

We will now handle loading in a file when our button is pressed.

```js
input.addEventListener("change", function(evt) {
    // Stop previous game from rendering, if one exists
    if (anim_frame != 0) {
        window.cancelAnimationFrame(anim_frame)
    }

    let file = evt.target.files[0]
    if (!file) {
        alert("Failed to read file")
        return
    }

    // Load in game as Uint8Array, send to .wasm, start main loop
    let fr = new FileReader()
    fr.onload = function(e) {
        let buffer = fr.result
        const rom = new Uint8Array(buffer)
        chip8.reset()
        chip8.load_game(rom)
        mainloop(chip8)
    }
    fr.readAsArrayBuffer(file)
}, false)

function mainloop(chip8) {
}
```

This function adds an event listener to our `input` button which is triggered whenever it is clicked. Our `desktop` frontend used SDL to manage not only drawing to a window, but only to ensure that we were running at 60 FPS. The analogous feature for canvases is the "Animation Frames". Anytime we want to render something to the canvas, we request the window to animate a frame, and it will wait until the correct time has elapsed to ensure 60 FPS performance. We'll see how this works in a moment, but for now, we need to tell our program that if we're loading a new game, we need to stop the previous animation. We'll also reset our emulator before we load in the ROM, to ensure everything is just as it started, without having to reload the webpage.

Following that, we look at the file that the user has pointed us to. We don't need to check if it's actually a Chip-8 program, but we do need to make sure that it is a file of some sort. We then read it in and pass it to our backend via our `EmuWasm` object. Once the game is loaded, we can jump into our main emulation loop!

```js
function mainloop(chip8) {
    // Only draw every few ticks
    for (let i = 0; i < TICKS_PER_FRAME; i++) {
        chip8.tick()
    }
    chip8.tick_timers()

    // Clear the canvas before drawing
    ctx.fillStyle = "black"
    ctx.fillRect(0, 0, WIDTH * SCALE, HEIGHT * SCALE)
    // Set the draw color back to white before we render our frame
    ctx.fillStyle = "white"
    chip8.draw_screen(SCALE)

    anim_frame = window.requestAnimationFrame(() => {
        mainloop(chip8)
    })
}
```

This should look very similar to what we did for our `desktop` frontend. We tick several times before clearing the canvas and telling our `EmuWasm` object to draw the current frame to our canvas. Here is where we tell our window that we would like to render a frame, and we also save its ID for if we need to cancel it above. The `requestAnimationFrame` will wait to ensure 60 FPS performance, and then restart our `mainloop` when it is time, beginning the process all over again.

## Compiling our WebAssembly binary

Before we go any further, let's now try and build our Rust code and ensure that it can be loaded by our web page without issue. `wasm-pack` will handle the compilation of our .wasm binary, but we also need to specify that we don't wish to use any web packing systems like `npm`. To build, change directories into the `wasm` folder and run:

```
$ wasm-pack build --target web
```

Once it is completed, the targets will be built into a new `pkg` directory. There are several items in here, but the only ones we need are `wasm_bg.wasm` and `wasm.js`. `wasm_bg.wasm` is the combination of our `wasm` and  `chip8_core` Rust crates compiled into one, and `wasm.js` is the JavaScript "glue" that we included earlier. It is mainly wrappers around the API we defined in `wasm` as well as some initialization code. It is actually quite readable, so it's worth taking a look at what it is doing.

Running the page in a local web server should allow you to pick and load a game without any warnings coming up in the browser's console. However, we haven't written the screen rendering function yet, so let's finish that so we can see our game actually run.

## Drawing to the canvas

Here is the final step, rendering to the screen. We created an empty `draw_screen` function in our `EmuWasm` object, and we call it at the right time, but it currently doesn't do anything. Now, there are two ways we could handle this. We could either pass the frame buffer into JavaScript and render it, or we could obtain our canvas in our `EmuWasm` binary and render to it in Rust. Either method would work fine, but personally I found that handling the rendering in Rust is easier.

We've used the `web_sys` crate to handle JavaScript `KeyboardEvents` in Rust, but it has the functionality to manage many more JavaScript elements. Again, the ones we wish to use will need to be defined as features in `wasm/Cargo.toml`.

```toml
[dependencies.web-sys]
version = "^0.3.46"
features = [
    "CanvasRenderingContext2d",
    "Document",
    "Element",
    "HtmlCanvasElement",
    "ImageData",
    "KeyboardEvent",
    "Window"
]
```

Here is an overview of our next steps. In order to render to an HTML5 canvas, you need to obtain the canvas object and its *context* which is the object which gets the draw functions called upon it. Since our WebAssembly binary has been loaded by our webpage, it has access to all of its elements just as a JS script would. We will change our `new` constructor to grab the current window, canvas, and context much like you would in JavaScript.

```rust
use wasm_bindgen::JsCast;
use web_sys::{CanvasRenderingContext2d, HtmlCanvasElement, KeyboardEvent};

#[wasm_bindgen]
pub struct EmuWasm {
    chip8: Emu,
    ctx: CanvasRenderingContext2d,
}

#[wasm_bindgen]
impl EmuWasm {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Result<EmuWasm, JsValue> {
        let chip8 = Emu::new();

        let document = web_sys::window().unwrap().document().unwrap();
        let canvas = document.get_element_by_id("canvas").unwrap();
        let canvas: HtmlCanvasElement = canvas
            .dyn_into::<HtmlCanvasElement>()
            .map_err(|_| ())
            .unwrap();

        let ctx = canvas.get_context("2d")
            .unwrap().unwrap()
            .dyn_into::<CanvasRenderingContext2d>()
            .unwrap();

        Ok(EmuWasm{chip8, ctx})
    }

    // -- Unchanged code omitted --
}
```

This should look pretty familiar to those who have done JavaScript programming before. We grab our current window's canvas and get its 2D context, which is saved as a member variable of our `EmuWasm` struct. Now that we have an actual context to render to, we can update our `draw_screen` function to draw to it.

```rust
#[wasm_bindgen]
pub fn draw_screen(&mut self, scale: usize) {
    let disp = self.chip8.get_display();
    for i in 0..(SCREEN_WIDTH * SCREEN_HEIGHT) {
        if disp[i] {
            let x = i % SCREEN_WIDTH;
            let y = i / SCREEN_WIDTH;
            self.ctx.fill_rect(
                (x * scale) as f64,
                (y * scale) as f64,
                scale as f64,
                scale as f64
            );
        }
    }
}
```

We get the display buffer from our `chip8_core` and iterate through every pixel. If set, we draw it scaled up to the value passed in by our frontend. Don't forget that we already cleared the canvas to black and set the draw color to white before calling `draw_screen`, so it doesn't need to be done here.

That does it! The implementation is done. All that remains is to build it and try it for ourself.

Rebuild by moving into the `wasm` directory and running:

```
$ wasm-pack build --target web
$ mv pkg/wasm_bg.wasm ../web
$ mv pkg/wasm.js ../web
```

Now start your web server and pick a game. If everything has gone well, you should be able to play Chip-8 games just as well in the browser as on the desktop!

\newpage
