# s3k-verilator

Simulating the [s3k](https://github.com/seven7-org/s3k) operating system on the [CVA6](https://github.com/openhwgroup/cva6) RISC-V processor using Verilator.

## Prerequisites

- [Verilator](https://veripool.org/verilator/) 5.018
- RISC-V GNU toolchain (cross-compiler for `riscv64-unknown-elf`)

## Usage

```bash
cd sim/verilator

# Build the hello firmware
make build-hello

# Build the Verilator simulation model and run it
make all run
```

The simulation boots s3k and runs the hello application. Key parameters (set via environment variables):

| Variable | Default | Description |
|---|---|---|
| `MAX_CYCLES` | 200000 | Max simulation cycles before exit |
| `FAST_BOOT` | 1 | Skip boot ROM, jump directly to kernel entry |
| `HELLO_BUILDDIR` | `s3k/projects/hello/builddir_verilator_cheshire` | Hello project build directory |
| `APP_ELFS` | `$(HELLO_BUILDDIR)/app1/app1.elf` | Application ELF(s) to load |
| `DEBUG_CPU` | 0 | Enable CPU debug tracing |

Clean build artifacts:

```bash
make clean
```
