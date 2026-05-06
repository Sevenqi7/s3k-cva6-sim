# s3k-verilator

Simulating the [s3k](https://github.com/seven7-org/s3k) operating system on the [CVA6](https://github.com/openhwgroup/cva6) RISC-V processor using Verilator.

## Prerequisites

- [Verilator](https://veripool.org/verilator/) 5.018
- RISC-V GNU toolchain (cross-compiler for `riscv64-unknown-elf`)

## Usage

Initialize submodules:

```bash
git submodule update --init --recursive
```

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

## Experimental S3K CLB Simulation

The default flow above simulates the original S3K setup. To experiment with the
CLB-enabled S3K/CVA6 branches, initialize the submodules first and then switch
the relevant submodules:

```bash
git submodule update --init --recursive
git -C s3k checkout s3k-clb-test
git -C cva6 checkout s3k-clb
```

After switching branches, use the same Verilator flow from `sim/verilator`.

## Current S3K CLB Constraints

The in-core CLB implementation is currently scoped to the single-core S3K
bare-metal configuration used by this repository. The following constraints are
intentional and should be kept in mind when debugging or extending the design:

- CLB memory access control uses union-of-capabilities semantics: a user
  load/store is allowed when the current process owns any cached capability that
  covers the access range and has sufficient permission. Overlapping parent and
  child capabilities are therefore valid; a root capability may correctly allow
  access to a child region.
- CLB uses CVA6 dcache port 0, which is otherwise the PTW port in the current
  configuration. This requires `MMU_PRESENT == 0`, the write-back dcache
  backend, and CVXIF/RVV disabled.
- `uclb.delete` follows CVA6 store-buffer semantics: a write grant is treated as
  the completion point for the architectural CLB instruction.
- The CVA6 dcache request/response port used by CLB does not expose an explicit
  bus-error response, so CLB memory commands follow the same `gnt/rvalid`
  protocol as the surrounding cache-port users.
