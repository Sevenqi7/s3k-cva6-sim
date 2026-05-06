#include "Vs3k_testharness.h"
#include "sim_utils.hpp"
#include "verilated.h"
#include "verilated_vcd_c.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

static vluint64_t main_time = 0;

double sc_time_stamp()
{
    return static_cast<double>(main_time);
}

namespace
{

struct Options {
    std::string kernel_elf;
    std::vector<std::string> app_elfs;
    std::string trace_file;
    uint64_t max_cycles = 200000;
    uint64_t reset_cycles = 16;
    uint64_t rtc_div = 50;
    uint64_t uart_idle_exit_cycles = 1024;
    std::string uart_exit_string;
    bool debug_axi = false;
    bool debug_cpu = false;
    bool debug_mmio = false;
    bool debug_clb = false;
    bool fast_boot = false;
};

void usage(const char *argv0)
{
    std::fprintf(stderr,
                 "Usage: %s --kernel-elf <path> --app-elf <path> [--app-elf <path> ...] "
                 "[--max-cycles N] [--rtc-div N] [--uart-idle-exit-cycles N] "
                 "[--uart-exit-string TEXT] [--trace FILE] [--debug-axi] [--debug-cpu] "
                 "[--debug-mmio] [--debug-clb] [--fast-boot]\n",
                 argv0);
}

bool parse_args(int argc, char **argv, Options *opts)
{
    for (int i = 1; i < argc; ++i) {
        const std::string arg = argv[i];
        auto need_value = [&](const char *name) -> const char * {
            if (i + 1 >= argc) {
                std::fprintf(stderr, "missing value for %s\n", name);
                return nullptr;
            }
            return argv[++i];
        };

        if (arg == "--kernel-elf") {
            const char *value = need_value("--kernel-elf");
            if (!value)
                return false;
            opts->kernel_elf = value;
        } else if (arg == "--app-elf") {
            const char *value = need_value("--app-elf");
            if (!value)
                return false;
            opts->app_elfs.push_back(value);
        } else if (arg == "--max-cycles") {
            const char *value = need_value("--max-cycles");
            if (!value)
                return false;
            opts->max_cycles = std::strtoull(value, nullptr, 0);
        } else if (arg == "--rtc-div") {
            const char *value = need_value("--rtc-div");
            if (!value)
                return false;
            opts->rtc_div = std::strtoull(value, nullptr, 0);
        } else if (arg == "--uart-idle-exit-cycles") {
            const char *value = need_value("--uart-idle-exit-cycles");
            if (!value)
                return false;
            opts->uart_idle_exit_cycles = std::strtoull(value, nullptr, 0);
        } else if (arg == "--uart-exit-string") {
            const char *value = need_value("--uart-exit-string");
            if (!value)
                return false;
            opts->uart_exit_string = value;
        } else if (arg == "--trace") {
            const char *value = need_value("--trace");
            if (!value)
                return false;
            opts->trace_file = value;
        } else if (arg == "--debug-axi") {
            opts->debug_axi = true;
        } else if (arg == "--debug-cpu") {
            opts->debug_cpu = true;
        } else if (arg == "--debug-mmio") {
            opts->debug_mmio = true;
        } else if (arg == "--debug-clb") {
            opts->debug_clb = true;
        } else if (arg == "--fast-boot") {
            opts->fast_boot = true;
        } else if (arg == "--help" || arg == "-h") {
            return false;
        } else {
            std::fprintf(stderr, "unknown option: %s\n", arg.c_str());
            return false;
        }
    }

    return !opts->kernel_elf.empty() && !opts->app_elfs.empty();
}

bool rtc_level_for_cycle(const Options &opts, uint64_t cycle)
{
    if (opts.rtc_div == 0) {
        return false;
    }

    // CVA6's CLINT synchronizes rtc_i and counts only rising edges. If we drive
    // rtc_i high every cycle, the synchronizer sees a constant level and mtime
    // advances only once. Keep RTC_DIV>=2 unchanged and special-case RTC_DIV=1
    // to the fastest edge-visible pattern.
    if (opts.rtc_div == 1) {
        return (cycle & 1ULL) == 0;
    }

    return (cycle % opts.rtc_div) == 0;
}

void run_half_cycle(Vs3k_testharness *top, VerilatedVcdC *trace)
{
    top->eval();
    if (trace != nullptr) {
        trace->dump(main_time);
    }
    ++main_time;
}

} // namespace

int main(int argc, char **argv)
{
    Options opts;
    if (!parse_args(argc, argv, &opts)) {
        usage(argv[0]);
        return 1;
    }

    std::vector<std::string> plusarg_storage;
    plusarg_storage.push_back(argv[0]);
    plusarg_storage.push_back("+kernel_elf=" + opts.kernel_elf);
    plusarg_storage.push_back("+app_elf_count=" + std::to_string(opts.app_elfs.size()));
    for (size_t i = 0; i < opts.app_elfs.size(); ++i) {
        plusarg_storage.push_back("+app_elf_" + std::to_string(i) + "=" + opts.app_elfs[i]);
    }
    if (opts.debug_axi) {
        plusarg_storage.push_back("+debug_axi=1");
    }
    if (opts.debug_mmio) {
        plusarg_storage.push_back("+debug_mmio=1");
    }
    if (opts.debug_clb) {
        plusarg_storage.push_back("+debug_clb=1");
    }
    if (opts.debug_axi || opts.debug_cpu || opts.debug_mmio || opts.debug_clb) {
        plusarg_storage.push_back("+debug_boot=1");
    }
    if (opts.fast_boot) {
        plusarg_storage.push_back("+fast_boot=1");
    }

    std::vector<char *> plusargs;
    plusargs.reserve(plusarg_storage.size());
    for (auto &arg : plusarg_storage) {
        plusargs.push_back(arg.data());
    }

    Verilated::commandArgs(static_cast<int>(plusargs.size()), plusargs.data());
    Verilated::traceEverOn(!opts.trace_file.empty());

    auto *top = new Vs3k_testharness;
    VerilatedVcdC *trace = nullptr;

    if (!opts.trace_file.empty()) {
        trace = new VerilatedVcdC;
        top->trace(trace, 99);
        trace->open(opts.trace_file.c_str());
    }

    top->clk_i = 0;
    top->rst_ni = 0;
    top->rtc_i = 0;
    CpuDebugState cpu_debug_state;
    UartExitState uart_exit_state;
    bool completed_via_uart_idle = false;
    bool completed_via_uart_string = false;
    size_t uart_exit_match = 0;
    if (opts.debug_cpu || opts.debug_axi) {
        print_memory_snapshot(top);
    }

    for (uint64_t cycle = 0; cycle < opts.max_cycles && !Verilated::gotFinish(); ++cycle) {
        top->rtc_i = 0;
        top->clk_i = 0;
        top->rst_ni = (cycle >= opts.reset_cycles);
        run_half_cycle(top, trace);

        top->rtc_i = rtc_level_for_cycle(opts, cycle) ? 1 : 0;
        top->clk_i = 1;
        run_half_cycle(top, trace);

        if (opts.debug_cpu && top->rst_ni && cpu_debug_state.prints < kMaxCpuDebugPrints) {
            const CpuState cpu_state = read_cpu_state(top);
            if (cpu_state_changed(cpu_debug_state.last, cpu_state)) {
                print_cpu_state(cycle, cpu_state);
                cpu_debug_state.last = cpu_state;
                ++cpu_debug_state.prints;
            }
        }

        if (top->rst_ni) {
            print_uart_tx(top);
            if (!opts.uart_exit_string.empty() && top->uart_tx_valid_o) {
                const char ch = static_cast<char>(top->uart_tx_data_o);
                if (ch == opts.uart_exit_string[uart_exit_match]) {
                    ++uart_exit_match;
                } else {
                    uart_exit_match = (ch == opts.uart_exit_string[0]) ? 1 : 0;
                }
                if (uart_exit_match == opts.uart_exit_string.size()) {
                    completed_via_uart_string = true;
                    break;
                }
            }
        }

        if (top->rst_ni && opts.uart_idle_exit_cycles != 0 &&
            uart_idle_exit_reached(top, opts.uart_idle_exit_cycles, &uart_exit_state)) {
            completed_via_uart_idle = true;
            break;
        }
    }

    const bool timed_out = !completed_via_uart_idle && !completed_via_uart_string && !Verilated::gotFinish();

    if (timed_out) {
        std::fprintf(stderr, "[s3k-verilator] timeout after %llu cycles\n",
                     static_cast<unsigned long long>(opts.max_cycles));
        print_cpu_state(opts.max_cycles, read_cpu_state(top));
    }

    if (trace != nullptr) {
        trace->close();
        delete trace;
    }
    delete top;

    if (timed_out) {
        return 2;
    }

    return 0;
}
