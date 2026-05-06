#include "sim_utils.hpp"

#include "Vs3k_testharness.h"
#include "Vs3k_testharness___024root.h"

#include <cstdio>

namespace
{

uint64_t read_gpr(Vs3k_testharness___024root *root, unsigned reg)
{
    if (reg == 0) {
        return 0;
    }

    const auto &mem =
        root->s3k_testharness__DOT__i_core__DOT__issue_stage_i__DOT__i_issue_read_operands__DOT__gen_asic_regfile__DOT__i_ariane_regfile__DOT__mem;
    return static_cast<uint64_t>(mem[reg * 2]) | (static_cast<uint64_t>(mem[reg * 2 + 1]) << 32);
}

} // namespace

CpuState read_cpu_state(Vs3k_testharness *top)
{
    auto *root = top->rootp;
    CpuState state;

    state.npc = root->s3k_testharness__DOT__i_core__DOT__i_frontend__DOT__npc_q;
    state.pc_id = root->s3k_testharness__DOT__i_core__DOT__pc_id_ex;
    state.mepc = root->s3k_testharness__DOT__i_core__DOT__csr_regfile_i__DOT__mepc_q;
    state.mcause = root->s3k_testharness__DOT__i_core__DOT__csr_regfile_i__DOT__mcause_q;
    state.mstatus = root->s3k_testharness__DOT__i_core__DOT__csr_regfile_i__DOT__mstatus_q;
    state.mip = root->s3k_testharness__DOT__i_core__DOT__csr_regfile_i__DOT__mip_q;
    state.mie = root->s3k_testharness__DOT__i_core__DOT__csr_regfile_i__DOT__mie_q;
    state.mtime = root->s3k_testharness__DOT__i_clint__DOT__mtime_q;
    state.mtimecmp = root->s3k_testharness__DOT__i_clint__DOT__mtimecmp_q;
    state.x6_t1 = read_gpr(root, 6);
    state.x10_a0 = read_gpr(root, 10);
    state.x11_a1 = read_gpr(root, 11);
    state.x12_a2 = read_gpr(root, 12);
    state.x13_a3 = read_gpr(root, 13);
    state.x14_a4 = read_gpr(root, 14);
    state.x15_a5 = read_gpr(root, 15);
    state.x16_a6 = read_gpr(root, 16);
    state.x17_a7 = read_gpr(root, 17);
    state.x28_t3 = read_gpr(root, 28);
    state.x29_t4 = read_gpr(root, 29);
    state.x30_t5 = read_gpr(root, 30);
    state.priv = root->s3k_testharness__DOT__i_core__DOT__csr_regfile_i__DOT__priv_lvl_q;

    return state;
}

bool cpu_state_changed(const CpuState &prev, const CpuState &next)
{
    return next.npc != prev.npc || next.pc_id != prev.pc_id || next.mepc != prev.mepc || next.mcause != prev.mcause
           || next.mstatus != prev.mstatus || next.mip != prev.mip || next.mie != prev.mie || next.mtime != prev.mtime
           || next.mtimecmp != prev.mtimecmp || next.x6_t1 != prev.x6_t1 || next.x10_a0 != prev.x10_a0
           || next.x11_a1 != prev.x11_a1 || next.x12_a2 != prev.x12_a2 || next.x13_a3 != prev.x13_a3
           || next.x14_a4 != prev.x14_a4 || next.x15_a5 != prev.x15_a5 || next.x16_a6 != prev.x16_a6
           || next.x17_a7 != prev.x17_a7 || next.x28_t3 != prev.x28_t3
           || next.x29_t4 != prev.x29_t4 || next.x30_t5 != prev.x30_t5 || next.priv != prev.priv;
}

void print_cpu_state(uint64_t cycle, const CpuState &state)
{
    std::fprintf(stderr,
                 "[s3k-cpu] cycle=%llu npc=0x%016llx pc_id=0x%016llx priv=%u "
                 "mepc=0x%016llx mcause=0x%016llx mstatus=0x%016llx mip=0x%016llx "
                 "mie=0x%016llx mtime=%llu mtimecmp=%llu "
                 "t1=%llu a0=0x%016llx a1=0x%016llx a2=0x%016llx a3=0x%016llx "
                 "a4=%llu a5=0x%016llx a6=0x%016llx a7=0x%016llx "
                 "t3=0x%016llx t4=0x%016llx t5=0x%016llx\n",
                 static_cast<unsigned long long>(cycle), static_cast<unsigned long long>(state.npc),
                 static_cast<unsigned long long>(state.pc_id), static_cast<unsigned>(state.priv),
                 static_cast<unsigned long long>(state.mepc), static_cast<unsigned long long>(state.mcause),
                 static_cast<unsigned long long>(state.mstatus), static_cast<unsigned long long>(state.mip),
                 static_cast<unsigned long long>(state.mie), static_cast<unsigned long long>(state.mtime),
                 static_cast<unsigned long long>(state.mtimecmp), static_cast<unsigned long long>(state.x6_t1),
                 static_cast<unsigned long long>(state.x10_a0), static_cast<unsigned long long>(state.x11_a1),
                 static_cast<unsigned long long>(state.x12_a2), static_cast<unsigned long long>(state.x13_a3),
                 static_cast<unsigned long long>(state.x14_a4), static_cast<unsigned long long>(state.x15_a5),
                 static_cast<unsigned long long>(state.x16_a6), static_cast<unsigned long long>(state.x17_a7),
                 static_cast<unsigned long long>(state.x28_t3), static_cast<unsigned long long>(state.x29_t4),
                 static_cast<unsigned long long>(state.x30_t5));
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

void print_uart_tx(Vs3k_testharness *top)
{
    if (!top->uart_tx_valid_o) {
        return;
    }

    std::fputc(static_cast<unsigned char>(top->uart_tx_data_o), stdout);
    std::fflush(stdout);
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
