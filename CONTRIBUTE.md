# ZJView – Developer Guide

This document provides instructions for developers to clone, build, and run the ZJView project locally.

---

## Clone the Repository

```bash
git clone https://github.com/your-username/zjview.git
cd zjview
```

---

## Build the WebAssembly Module (Zig)

Make sure you have Zig version `0.13.0` installed.  
You can download it from: [https://ziglang.org/download/](https://ziglang.org/download/)

To build the WASM module:

```bash
zig build
mv zig-out/bin/zjview.wasm web/zjview.wasm
```

This will generate the optimized `.wasm` file in the `zig-out` directory and move it to web **directory**.

## Project Structure

- `src/` — Zig source code for WebAssembly logic
- `web/` — Web assets, HTML/JS to interact with the WASM module
- `README.md` — User-facing info
- `LICENSE.md` — License info
- `DEVELOPMENT.md` — Developer instructions (this file)

---

## Requirements

- Zig `0.13.0`