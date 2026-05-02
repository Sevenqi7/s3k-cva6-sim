#include "sim_utils.hpp"

#include "Vs3k_testharness.h"
#include "Vs3k_testharness___024root.h"

#include <cstdio>

CpuState read_cpu_state(Vs3k_testharness *top)
{
    auto *root = top->rootp;
    CpuState state;

    state.npc = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__i_frontend__DOT__npc_q;
    state.pc_id = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__pc_id_ex;
    state.mepc = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__csr_regfile_i__DOT__mepc_q;
    state.mcause = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__csr_regfile_i__DOT__mcause_q;
    state.mstatus = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__csr_regfile_i__DOT__mstatus_q;
    state.mip = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__csr_regfile_i__DOT__mip_q;
    state.mie = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__csr_regfile_i__DOT__mie_q;
    state.mtime = root->s3k_testharness__DOT__i_clint__DOT__mtime_q;
    state.mtimecmp = root->s3k_testharness__DOT__i_clint__DOT__mtimecmp_q;
    state.priv = root->s3k_testharness__DOT__i_ariane__DOT__i_cva6__DOT__csr_regfile_i__DOT__priv_lvl_q;

    return state;
}

bool cpu_state_changed(const CpuState &prev, const CpuState &next)
{
    return next.npc != prev.npc || next.pc_id != prev.pc_id || next.mepc != prev.mepc || next.mcause != prev.mcause
           || next.mstatus != prev.mstatus || next.mip != prev.mip || next.mie != prev.mie || next.mtime != prev.mtime
           || next.mtimecmp != prev.mtimecmp || next.priv != prev.priv;
}

void print_cpu_state(uint64_t cycle, const CpuState &state)
{
    std::fprintf(stderr,
                 "[s3k-cpu] cycle=%llu npc=0x%016llx pc_id=0x%016llx priv=%u "
                 "mepc=0x%016llx mcause=0x%016llx mstatus=0x%016llx mip=0x%016llx "
                 "mie=0x%016llx mtime=%llu mtimecmp=%llu\n",
                 static_cast<unsigned long long>(cycle), static_cast<unsigned long long>(state.npc),
                 static_cast<unsigned long long>(state.pc_id), static_cast<unsigned>(state.priv),
                 static_cast<unsigned long long>(state.mepc), static_cast<unsigned long long>(state.mcause),
                 static_cast<unsigned long long>(state.mstatus), static_cast<unsigned long long>(state.mip),
                 static_cast<unsigned long long>(state.mie), static_cast<unsigned long long>(state.mtime),
                 static_cast<unsigned long long>(state.mtimecmp));
}

void print_memory_snapshot(Vs3k_testharness *top)
{
    auto *root = top->rootp;
    std::fprintf(stderr,
                 "[s3k-mem] kernel.sram[0]=0x%016llx kernel.sram[1]=0x%016llx "
                 "kernel.init[0]=0x%016llx kernel.init[1]=0x%016llx\n",
                 static_cast<unsigned long long>(
                     root->s3k_testharness__DOT__i_kernel_mem__DOT__i_sram__DOT__i_tc_sram__DOT__sram[0]),
                 static_cast<unsigned long long>(
                     root->s3k_testharness__DOT__i_kernel_mem__DOT__i_sram__DOT__i_tc_sram__DOT__sram[1]),
                 static_cast<unsigned long long>(
                     root->s3k_testharness__DOT__i_kernel_mem__DOT__i_sram__DOT__i_tc_sram__DOT__init_val[0]),
                 static_cast<unsigned long long>(
                     root->s3k_testharness__DOT__i_kernel_mem__DOT__i_sram__DOT__i_tc_sram__DOT__init_val[1]));
}

bool uart_idle_exit_reached(Vs3k_testharness *top, uint64_t idle_exit_cycles, UartExitState *state)
{
    if (top->uart_tx_valid_o) {
        state->saw_tx = true;
        state->idle_cycles = 0;
        return false;
    }

    if (!state->saw_tx) {
        return false;
    }

    ++state->idle_cycles;
    return state->idle_cycles >= idle_exit_cycles;
}
