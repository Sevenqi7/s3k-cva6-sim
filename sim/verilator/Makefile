ROOT_DIR := $(abspath $(CURDIR)/../..)
CVA6_DIR := $(ROOT_DIR)/cva6
S3K_DIR := $(ROOT_DIR)/s3k

VERILATOR_LOCAL_INSTALL := $(CURDIR)/tools/verilator-v5.018/bin/verilator
VERILATOR_LOCAL_BUILD := $(CURDIR)/tools/verilator-v5.018/verilator/bin/verilator
VERILATOR_SYSTEM := $(shell command -v verilator 2>/dev/null)

ifndef VERILATOR
  ifneq ($(VERILATOR_SYSTEM),)
    VERILATOR := $(VERILATOR_SYSTEM)
  else ifneq ($(wildcard $(VERILATOR_LOCAL_INSTALL)),)
    VERILATOR := $(VERILATOR_LOCAL_INSTALL)
  else ifneq ($(wildcard $(VERILATOR_LOCAL_BUILD)),)
    VERILATOR := $(VERILATOR_LOCAL_BUILD)
  else
    VERILATOR := verilator
  endif
endif

ifndef VERILATOR_ROOT
  ifeq ($(VERILATOR),$(VERILATOR_LOCAL_BUILD))
    VERILATOR_ROOT := $(CURDIR)/tools/verilator-v5.018/verilator
  endif
endif


# Maximum number of cycles to run the simulation before exiting.
MAX_CYCLES ?= 200000

# Skip the boot ROM and start executing directly from the kernel entry point. 
# This requires the kernel to be linked with the correct entry point and without a boot header, 
# but can significantly reduce boot time.
FAST_BOOT ?= 1

RTC_DIV ?= 100  
UART_IDLE_EXIT_CYCLES ?= 1024
UART_EXIT_STRING ?=
DEBUG_CPU ?= 0
DEBUG_MMIO ?= 0
DEBUG_CLB ?= 0
S3K_CLB ?= 0
HELLO_BUILDDIR ?= $(S3K_DIR)/projects/hello/builddir_verilator_cheshire
KERNEL_ELF ?= $(HELLO_BUILDDIR)/subprojects/s3k/kern/s3k.elf
APP_ELF ?= $(HELLO_BUILDDIR)/app1/app1.elf
APP_ELFS ?= $(APP_ELF)
VERILATOR_OUTPUT_SPLIT ?= 12000
VERILATOR_OUTPUT_SPLIT_CFUNCS ?= 2000
VERILATOR_BUILD_JOBS ?= 1
CXX_OPT_LEVEL ?= -O3

OBJ_DIR ?= $(CURDIR)/build/obj_dir
MODEL := $(OBJ_DIR)/Vs3k_testharness

RUN_FLAGS :=
RUN_FLAGS += --uart-idle-exit-cycles $(UART_IDLE_EXIT_CYCLES)
ifneq ($(UART_EXIT_STRING),)
RUN_FLAGS += --uart-exit-string "$(UART_EXIT_STRING)"
endif
ifeq ($(FAST_BOOT),1)
RUN_FLAGS += --fast-boot
endif
ifeq ($(DEBUG_CPU),1)
RUN_FLAGS += --debug-cpu
endif
ifeq ($(DEBUG_MMIO),1)
RUN_FLAGS += --debug-mmio
endif
ifeq ($(DEBUG_CLB),1)
RUN_FLAGS += --debug-clb
endif

ifeq ($(S3K_CLB),1)
CLB_PKG_SRCS := $(CVA6_DIR)/core/clb/s3k_clb_pkg.sv
CLB_CORE_SRCS := $(filter-out $(CVA6_DIR)/core/clb/s3k_clb_pkg.sv, $(wildcard $(CVA6_DIR)/core/clb/*.sv))
CLB_VFLAGS := +define+S3K_CLB
endif

PKG_SRCS := \
	$(CVA6_DIR)/core/include/config_pkg.sv \
	rtl/cva6_config_pkg.sv \
	$(CVA6_DIR)/core/include/riscv_pkg.sv \
	$(CVA6_DIR)/vendor/openhwgroup/cvfpu/src/fpnew_pkg.sv \
	$(CVA6_DIR)/core/include/ariane_pkg.sv \
	$(CVA6_DIR)/core/include/acc_pkg.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_pkg.sv \
	$(CVA6_DIR)/corev_apu/tb/ariane_axi_pkg.sv \
	$(CVA6_DIR)/core/include/wt_cache_pkg.sv \
	$(CVA6_DIR)/core/include/std_cache_pkg.sv \
	$(CVA6_DIR)/corev_apu/tb/axi_intf.sv \
	$(CVA6_DIR)/core/include/cvxif_pkg.sv \
	$(CLB_PKG_SRCS) \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/cf_math_pkg.sv \
	$(CVA6_DIR)/core/include/instr_tracer_pkg.sv \
	rtl/s3k_addr_map_pkg.sv \
	rtl/s3k_axi_soc_pkg.sv

COMMON_SRCS := \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/addr_decode.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/cc_onehot.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/cdc_2phase.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/counter.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/delta_counter.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/exp_backoff.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/fifo_v3.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/lfsr.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/lfsr_16bit.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/lfsr_8bit.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/lzc.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/onehot_to_bin.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/plru_tree.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/popcount.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/rr_arb_tree.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/rstgen.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/rstgen_bypass.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/shift_reg.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/spill_register.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/spill_register_flushable.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_arbiter.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_arbiter_flushable.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_delay.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_demux.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_mux.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/stream_register.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/sync.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/unread.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/deprecated/fifo_v1.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/deprecated/fifo_v2.sv \
	$(CVA6_DIR)/vendor/pulp-platform/common_cells/src/deprecated/rrarbiter.sv

AXI_SRCS := \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_multicut.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_cut.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_join.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_delayer.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_to_axi_lite.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_id_prepend.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_atop_filter.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_err_slv.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_mux.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_demux.sv \
	$(CVA6_DIR)/vendor/pulp-platform/axi/src/axi_xbar.sv

TECH_SRCS := \
	$(CVA6_DIR)/vendor/pulp-platform/tech_cells_generic/src/rtl/tc_clk.sv \
	$(CVA6_DIR)/vendor/pulp-platform/tech_cells_generic/src/rtl/tc_sram.sv \
	$(CVA6_DIR)/vendor/pulp-platform/tech_cells_generic/src/deprecated/cluster_clk_cells.sv \
	$(CVA6_DIR)/vendor/pulp-platform/tech_cells_generic/src/deprecated/pulp_clk_cells.sv

CORE_SRCS := \
	$(filter-out \
	$(CVA6_DIR)/core/cva6_rvfi.sv \
	$(CVA6_DIR)/core/cva6_rvfi_probes.sv, \
	$(wildcard $(CVA6_DIR)/core/*.sv)) \
	$(wildcard $(CVA6_DIR)/core/frontend/*.sv) \
	$(CLB_CORE_SRCS) \
	$(CVA6_DIR)/core/cache_subsystem/amo_alu.sv \
	$(CVA6_DIR)/core/cache_subsystem/axi_adapter.sv \
	$(CVA6_DIR)/core/cache_subsystem/cache_ctrl.sv \
	$(CVA6_DIR)/core/cache_subsystem/cva6_icache.sv \
	$(CVA6_DIR)/core/cache_subsystem/cva6_icache_axi_wrapper.sv \
	$(CVA6_DIR)/core/cache_subsystem/miss_handler.sv \
	$(CVA6_DIR)/core/cache_subsystem/std_cache_subsystem.sv \
	$(CVA6_DIR)/core/cache_subsystem/std_nbdcache.sv \
	$(CVA6_DIR)/core/cache_subsystem/tag_cmp.sv \
	$(CVA6_DIR)/core/cache_subsystem/wt_axi_adapter.sv \
	$(CVA6_DIR)/core/cache_subsystem/wt_cache_subsystem.sv \
	$(CVA6_DIR)/core/cache_subsystem/wt_dcache.sv \
	$(CVA6_DIR)/core/cache_subsystem/wt_dcache_ctrl.sv \
	$(CVA6_DIR)/core/cache_subsystem/wt_dcache_mem.sv \
	$(CVA6_DIR)/core/cache_subsystem/wt_dcache_missunit.sv \
	$(CVA6_DIR)/core/cache_subsystem/wt_dcache_wbuffer.sv \
	$(wildcard $(CVA6_DIR)/core/mmu_sv39/*.sv) \
	$(wildcard $(CVA6_DIR)/core/mmu_sv39x4/*.sv) \
	$(wildcard $(CVA6_DIR)/core/pmp/src/*.sv)

CVA6_SOC_SRCS := \
	$(CVA6_DIR)/common/local/util/tc_sram_wrapper.sv \
	$(CVA6_DIR)/common/local/util/sram_pulp.sv \
	$(wildcard $(CVA6_DIR)/corev_apu/clint/*.sv) \
	$(wildcard $(CVA6_DIR)/corev_apu/fpga/src/axi2apb/src/*.sv) \
	$(wildcard $(CVA6_DIR)/corev_apu/fpga/src/axi_slice/src/*.sv) \
	$(wildcard $(CVA6_DIR)/corev_apu/src/axi_riscv_atomics/src/*.sv) \
	$(wildcard $(CVA6_DIR)/corev_apu/axi_mem_if/src/*.sv) \
	$(CVA6_DIR)/corev_apu/tb/common/mock_uart.sv

LOCAL_RTL_SRCS := \
	$(CURDIR)/rtl/s3k_axi_sram.sv \
	$(CURDIR)/rtl/s3k_uart_subsystem.sv \
	$(CURDIR)/rtl/s3k_testharness.sv

CPP_SRCS := $(CURDIR)/cpp/sim_main.cpp $(CURDIR)/cpp/sim_utils.cpp $(CURDIR)/cpp/elfloader.cpp

INCDIRS := \
	+incdir+rtl \
	+incdir+$(CVA6_DIR)/core/include \
	+incdir+$(CVA6_DIR)/vendor/pulp-platform/common_cells/include \
	+incdir+$(CVA6_DIR)/vendor/pulp-platform/axi/include \
	+incdir+$(CVA6_DIR)/common/local/util \
	+incdir+$(CVA6_DIR)/core/cvxif_example/include \
	+incdir+$(CVA6_DIR)/corev_apu/register_interface/include

VERILATOR_INPUTS := $(PKG_SRCS) $(COMMON_SRCS) $(AXI_SRCS) $(TECH_SRCS) $(CORE_SRCS) $(CVA6_SOC_SRCS) $(LOCAL_RTL_SRCS)

VFLAGS := \
	--sv \
	--cc \
	--exe \
	--build \
	--no-timing \
	--trace \
	--top-module s3k_testharness \
	--Mdir $(OBJ_DIR) \
	--output-split $(VERILATOR_OUTPUT_SPLIT) \
	--output-split-cfuncs $(VERILATOR_OUTPUT_SPLIT_CFUNCS) \
	--unroll-count 256 \
	-O3 \
	$(CLB_VFLAGS) \
	-Wall \
	-Wno-fatal \
	-Wno-PINCONNECTEMPTY \
	-Wno-ASSIGNDLY \
	-Wno-DECLFILENAME \
	-Wno-UNUSED \
	-Wno-UNOPTFLAT \
	-Wno-BLKANDNBLK \
	-Wno-style \
	-MAKEFLAGS "OBJCACHE= -j$(VERILATOR_BUILD_JOBS) OPT_FAST=$(CXX_OPT_LEVEL) OPT_SLOW=$(CXX_OPT_LEVEL)" \
	-CFLAGS "-std=c++17 $(CXX_OPT_LEVEL)" \
	$(INCDIRS)

.PHONY: all clean build-hello run

all: $(MODEL)

$(MODEL): $(VERILATOR_INPUTS) $(CPP_SRCS)
	mkdir -p $(OBJ_DIR)
	$(if $(VERILATOR_ROOT),VERILATOR_ROOT="$(VERILATOR_ROOT)") $(VERILATOR) $(VFLAGS) $(VERILATOR_INPUTS) $(CPP_SRCS)

build-hello:
	./scripts/build_hello.sh

run: $(MODEL)
	$(MODEL) --kernel-elf $(KERNEL_ELF) $(foreach elf,$(APP_ELFS),--app-elf $(elf)) --max-cycles $(MAX_CYCLES) --rtc-div $(RTC_DIV) $(RUN_FLAGS)

clean:
	rm -rf build
