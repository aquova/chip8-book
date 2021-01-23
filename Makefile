pdf:
	cd src && \
	pandoc -s -o chip8.pdf \
		intro.md \
		basics.md \
		setup.md \
		methods.md \
		instr.md \
		frontend.md \
		wasm.md \
		opcodes.md \
		changes.md \
		metadata.yaml

desktop:
	cd code/desktop && \
	cargo build --release

web:
	cd code/wasm && \
	wasm-pack build --target web && \
	mv pkg/wasm_bg.wasm ../web && \
	mv pkg/wasm.js ../web

clean: clean_pdf clean_desktop clean_web

clean_pdf:
	rm -f src/chip8.pdf

clean_desktop:
	cd code/desktop && \
	cargo clean

clean_web:
	rm -f code/web/wasm_bg.wasm && \
	rm -f code/web/wasm.js && \
	cd code/wasm && \
	cargo clean

.PHONY: pdf desktop web clean
