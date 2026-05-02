#pragma once

#include <cstdint>

class Vs3k_testharness;

constexpr uint32_t kMaxCpuDebugPrints = 256;

struct CpuState {
    uint64_t npc = ~0ULL;
    uint64_t pc_id = ~0ULL;
    uint64_t mepc = ~0ULL;
    uint64_t mcause = ~0ULL;
    uint64_t mstatus = ~0ULL;
    uint64_t mip = ~0ULL;
    uint64_t mie = ~0ULL;
    uint64_t mtime = ~0ULL;
    uint64_t mtimecmp = ~0ULL;
    uint8_t priv = 0xff;
};

struct CpuDebugState {
    CpuState last;
    uint32_t prints = 0;
};

struct UartExitState {
    bool saw_tx = false;
    uint64_t idle_cycles = 0;
};

CpuState read_cpu_state(Vs3k_testharness *top);
bool cpu_state_changed(const CpuState &prev, const CpuState &next);
void print_cpu_state(uint64_t cycle, const CpuState &state);
void print_memory_snapshot(Vs3k_testharness *top);
bool uart_idle_exit_reached(Vs3k_testharness *top, uint64_t idle_exit_cycles, UartExitState *state);
