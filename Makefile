pdf:
	cd src && \
	pandoc -s -o chip8.pdf \
		1-intro.md \
		2-basics.md \
		3-setup.md \
		4-methods.md \
		5-instr.md \
		6-frontend.md \
		7-wasm.md \
		8-opcodes.md \
		9-changes.md \
		metadata.yaml

epub:
	cd src && \
	pandoc -s -o chip8.epub \
		1-intro.md \
		2-basics.md \
		3-setup.md \
		4-methods.md \
		5-instr.md \
		6-frontend.md \
		7-wasm.md \
		8-opcodes.md \
		9-changes.md \
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

clean_epub:
	rm -f src/chip8.epub

clean_desktop:
	cd code/desktop && \
	cargo clean

clean_web:
	rm -f code/web/wasm_bg.wasm && \
	rm -f code/web/wasm.js && \
	cd code/wasm && \
	cargo clean

.PHONY: pdf desktop web clean
