`include "axi/assign.svh"

import "DPI-C" function int read_elf(input string filename);
import "DPI-C" function int get_section(output longint unsigned address,
                                        output longint unsigned len);
import "DPI-C" function int get_symbol(input string name,
                                       output longint unsigned address);
import "DPI-C" function longint unsigned read_section_word(input longint unsigned address,
                                                           input int unsigned word_index);

module s3k_testharness #(
  parameter config_pkg::cva6_cfg_t CVA6Cfg = cva6_config_pkg::cva6_cfg,
  parameter int unsigned AXI_USER_WIDTH    = ariane_pkg::AXI_USER_WIDTH,
  parameter int unsigned AXI_USER_EN       = ariane_pkg::AXI_USER_EN,
  parameter int unsigned AXI_ADDRESS_WIDTH = 64,
  parameter int unsigned AXI_DATA_WIDTH    = 64
) (
  input logic clk_i,
  input logic rst_ni,
  input logic rtc_i,
  output logic uart_tx_valid_o,
  output logic [7:0] uart_tx_data_o
);

  logic unused_rvfi;
  logic debug_axi;
  logic debug_mmio;
  int unsigned debug_axi_prints;
  int unsigned debug_mmio_prints;
  int unsigned axi_error_prints;
  longint unsigned cycle_count;
  localparam int unsigned AxiDebugSlots = 1 << ariane_axi::IdWidth;
  logic [AXI_ADDRESS_WIDTH-1:0] last_ar_addr_by_id [AxiDebugSlots];
  logic [7:0]                   last_ar_len_by_id  [AxiDebugSlots];
  logic [2:0]                   last_ar_size_by_id [AxiDebugSlots];
  logic [AXI_ADDRESS_WIDTH-1:0] last_aw_addr_by_id [AxiDebugSlots];
  logic [7:0]                   last_aw_len_by_id  [AxiDebugSlots];
  logic [2:0]                   last_aw_size_by_id [AxiDebugSlots];

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( ariane_axi::IdWidth ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) slave [s3k_addr_map_pkg::NrSlaves-1:0] ();

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH      ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH         ),
    .AXI_ID_WIDTH   ( s3k_axi_soc::IdWidthSlave ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH         )
  ) master [s3k_addr_map_pkg::NB_PERIPHERALS-1:0] ();

  axi_pkg::xbar_rule_64_t [s3k_addr_map_pkg::NB_PERIPHERALS-1:0] addr_map;

  assign addr_map = '{
    '{ idx: s3k_addr_map_pkg::DRAM,  start_addr: s3k_addr_map_pkg::DramBase,   end_addr: s3k_addr_map_pkg::DramBase + s3k_addr_map_pkg::DramLength },
    '{ idx: s3k_addr_map_pkg::UART,  start_addr: s3k_addr_map_pkg::UartBase,   end_addr: s3k_addr_map_pkg::UartBase + s3k_addr_map_pkg::UartLength },
    '{ idx: s3k_addr_map_pkg::CLINT, start_addr: s3k_addr_map_pkg::ClintBase,  end_addr: s3k_addr_map_pkg::ClintBase + s3k_addr_map_pkg::ClintLength },
    '{ idx: s3k_addr_map_pkg::SPM,   start_addr: s3k_addr_map_pkg::KernelBase, end_addr: s3k_addr_map_pkg::KernelBase + s3k_addr_map_pkg::KernelWindowLength }
  };

  localparam axi_pkg::xbar_cfg_t AXI_XBAR_CFG = '{
    NoSlvPorts: unsigned'(s3k_addr_map_pkg::NrSlaves),
    NoMstPorts: unsigned'(s3k_addr_map_pkg::NB_PERIPHERALS),
    MaxMstTrans: unsigned'(4),
    MaxSlvTrans: unsigned'(4),
    FallThrough: 1'b0,
    LatencyMode: axi_pkg::NO_LATENCY,
    AxiIdWidthSlvPorts: unsigned'(ariane_axi::IdWidth),
    AxiIdUsedSlvPorts: unsigned'(ariane_axi::IdWidth),
    UniqueIds: 1'b0,
    AxiAddrWidth: unsigned'(AXI_ADDRESS_WIDTH),
    AxiDataWidth: unsigned'(AXI_DATA_WIDTH),
    NoAddrRules: unsigned'(s3k_addr_map_pkg::NB_PERIPHERALS)
  };

  axi_xbar_intf #(
    .AXI_USER_WIDTH ( AXI_USER_WIDTH          ),
    .Cfg            ( AXI_XBAR_CFG            ),
    .rule_t         ( axi_pkg::xbar_rule_64_t )
  ) i_axi_xbar (
    .clk_i                 ( clk_i   ),
    .rst_ni                ( rst_ni  ),
    .test_i                ( 1'b0    ),
    .slv_ports             ( slave   ),
    .mst_ports             ( master  ),
    .addr_map_i            ( addr_map ),
    .en_default_mst_port_i ( '0      ),
    .default_mst_port_i    ( '0      )
  );

  logic ipi;
  logic timer_irq;

  s3k_axi_soc::req_slv_t  axi_clint_req;
  s3k_axi_soc::resp_slv_t axi_clint_resp;

  clint #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH       ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH          ),
    .AXI_ID_WIDTH   ( s3k_axi_soc::IdWidthSlave ),
    .NR_CORES       ( 1                       ),
    .axi_req_t      ( s3k_axi_soc::req_slv_t ),
    .axi_resp_t     ( s3k_axi_soc::resp_slv_t )
  ) i_clint (
    .clk_i       ( clk_i         ),
    .rst_ni      ( rst_ni        ),
    .testmode_i  ( 1'b0          ),
    .axi_req_i   ( axi_clint_req ),
    .axi_resp_o  ( axi_clint_resp ),
    .rtc_i       ( rtc_i         ),
    .timer_irq_o ( timer_irq     ),
    .ipi_o       ( ipi           )
  );

  `AXI_ASSIGN_TO_REQ(axi_clint_req, master[s3k_addr_map_pkg::CLINT])
  `AXI_ASSIGN_FROM_RESP(master[s3k_addr_map_pkg::CLINT], axi_clint_resp)

  s3k_uart_subsystem #(
    .AXI_ADDRESS_WIDTH ( AXI_ADDRESS_WIDTH       ),
    .AXI_DATA_WIDTH    ( AXI_DATA_WIDTH          ),
    .AXI_ID_WIDTH      ( s3k_axi_soc::IdWidthSlave ),
    .AXI_USER_WIDTH    ( AXI_USER_WIDTH          )
  ) i_uart (
    .clk_i          ( clk_i                        ),
    .rst_ni         ( rst_ni                       ),
    .axi            ( master[s3k_addr_map_pkg::UART] ),
    .uart_tx_valid_o( uart_tx_valid_o              ),
    .uart_tx_data_o ( uart_tx_data_o               )
  );

  s3k_axi_sram #(
    .AXI_USER_WIDTH    ( AXI_USER_WIDTH            ),
    .AXI_USER_EN       ( AXI_USER_EN               ),
    .AXI_ADDRESS_WIDTH ( AXI_ADDRESS_WIDTH         ),
    .AXI_DATA_WIDTH    ( AXI_DATA_WIDTH            ),
    .AXI_ID_WIDTH      ( s3k_axi_soc::IdWidthSlave ),
    .NUM_WORDS         ( s3k_addr_map_pkg::KernelWords )
  ) i_kernel_mem (
    .clk_i  ( clk_i ),
    .rst_ni ( rst_ni ),
    .axi    ( master[s3k_addr_map_pkg::SPM] )
  );

  s3k_axi_sram #(
    .AXI_USER_WIDTH    ( AXI_USER_WIDTH            ),
    .AXI_USER_EN       ( AXI_USER_EN               ),
    .AXI_ADDRESS_WIDTH ( AXI_ADDRESS_WIDTH         ),
    .AXI_DATA_WIDTH    ( AXI_DATA_WIDTH            ),
    .AXI_ID_WIDTH      ( s3k_axi_soc::IdWidthSlave ),
    .NUM_WORDS         ( s3k_addr_map_pkg::DramWords )
  ) i_dram_mem (
    .clk_i  ( clk_i ),
    .rst_ni ( rst_ni ),
    .axi    ( master[s3k_addr_map_pkg::DRAM] )
  );

  function automatic logic [31:0] encode_jal(input logic signed [20:0] imm);
    logic [31:0] inst;
    inst = '0;
    inst[31]    = imm[20];
    inst[30:21] = imm[10:1];
    inst[20]    = imm[11];
    inst[19:12] = imm[19:12];
    inst[6:0]   = 7'b1101111;
    return inst;
  endfunction

  function automatic logic [15:0] encode_cj(input logic signed [11:0] imm);
    logic [15:0] inst;
    inst = '0;
    inst[15:13] = 3'b101;
    inst[12]    = imm[11];
    inst[11]    = imm[4];
    inst[10]    = imm[9];
    inst[9]     = imm[8];
    inst[8]     = imm[10];
    inst[7]     = imm[6];
    inst[6]     = imm[7];
    inst[5]     = imm[3];
    inst[4]     = imm[2];
    inst[3]     = imm[1];
    inst[2]     = imm[5];
    inst[1:0]   = 2'b01;
    return inst;
  endfunction

  ariane_axi::req_t        core_noc_req;
  ariane_axi::resp_t       core_noc_resp;
  cvxif_pkg::cvxif_req_t   unused_cvxif_req;
  cvxif_pkg::cvxif_resp_t  unused_cvxif_resp;

  assign unused_cvxif_resp = '0;

  cva6 #(
    .CVA6Cfg        ( CVA6Cfg                      ),
    .IsRVFI         ( 1'b0                         ),
`ifdef S3K_CLB
    .S3KClbEn       ( 1'b1                         ),
`endif
    .rvfi_probes_t  ( logic                        ),
    .axi_ar_chan_t  ( ariane_axi::ar_chan_t        ),
    .axi_aw_chan_t  ( ariane_axi::aw_chan_t        ),
    .axi_w_chan_t   ( ariane_axi::w_chan_t         ),
    .noc_req_t      ( ariane_axi::req_t            ),
    .noc_resp_t     ( ariane_axi::resp_t           )
  ) i_core (
    .clk_i            ( clk_i                         ),
    .rst_ni           ( rst_ni                        ),
    .boot_addr_i      ( s3k_addr_map_pkg::KernelBase  ),
    .hart_id_i        ( '0                            ),
    .irq_i            ( '0                            ),
    .ipi_i            ( ipi                           ),
    .time_irq_i       ( timer_irq                     ),
    .debug_req_i      ( 1'b0                          ),
    .clic_irq_valid_i ( 1'b0                          ),
    .clic_irq_id_i    ( '0                            ),
    .clic_irq_level_i ( '0                            ),
    .clic_irq_priv_i  ( '0                            ),
    .clic_irq_shv_i   ( 1'b0                          ),
    .clic_irq_ready_o (                               ),
    .clic_kill_req_i  ( 1'b0                          ),
    .clic_kill_ack_o  (                               ),
    .rvfi_probes_o    ( unused_rvfi                   ),
    .cvxif_req_o      ( unused_cvxif_req              ),
    .cvxif_resp_i     ( unused_cvxif_resp             ),
    .noc_req_o        ( core_noc_req                  ),
    .noc_resp_i       ( core_noc_resp                 )
  );

  `AXI_ASSIGN_FROM_REQ(slave[0], core_noc_req)
  `AXI_ASSIGN_TO_RESP(core_noc_resp, slave[0])

  initial begin
    debug_axi = $test$plusargs("debug_axi");
    debug_mmio = $test$plusargs("debug_mmio");
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      cycle_count <= '0;
      debug_axi_prints <= '0;
      debug_mmio_prints <= '0;
    end else begin
      cycle_count <= cycle_count + 1;

      if (debug_axi && (debug_axi_prints < 64)) begin
        if (slave[0].ar_valid && slave[0].ar_ready) begin
          $display("[s3k-axi] cycle=%0d AR addr=0x%016h len=%0d size=%0d",
                   cycle_count, slave[0].ar_addr, slave[0].ar_len, slave[0].ar_size);
          debug_axi_prints <= debug_axi_prints + 1;
        end
        if ((debug_axi_prints < 64) && slave[0].aw_valid && slave[0].aw_ready) begin
          $display("[s3k-axi] cycle=%0d AW addr=0x%016h len=%0d size=%0d",
                   cycle_count, slave[0].aw_addr, slave[0].aw_len, slave[0].aw_size);
          debug_axi_prints <= debug_axi_prints + 1;
        end
        if ((debug_axi_prints < 64) && slave[0].r_valid && slave[0].r_ready) begin
          $display("[s3k-axi] cycle=%0d R data=0x%016h resp=%0d last=%0d",
                   cycle_count, slave[0].r_data, slave[0].r_resp, slave[0].r_last);
          debug_axi_prints <= debug_axi_prints + 1;
        end
      end

      if (debug_mmio && (debug_mmio_prints < 128)) begin
        if (master[s3k_addr_map_pkg::CLINT].aw_valid && master[s3k_addr_map_pkg::CLINT].aw_ready) begin
          $display("[s3k-mmio] cycle=%0d CLINT AW addr=0x%016h size=%0d",
                   cycle_count,
                   master[s3k_addr_map_pkg::CLINT].aw_addr,
                   master[s3k_addr_map_pkg::CLINT].aw_size);
          debug_mmio_prints <= debug_mmio_prints + 1;
        end
        if ((debug_mmio_prints < 128) &&
            master[s3k_addr_map_pkg::CLINT].w_valid &&
            master[s3k_addr_map_pkg::CLINT].w_ready) begin
          $display("[s3k-mmio] cycle=%0d CLINT W data=0x%016h strb=0x%0h",
                   cycle_count,
                   master[s3k_addr_map_pkg::CLINT].w_data,
                   master[s3k_addr_map_pkg::CLINT].w_strb);
          debug_mmio_prints <= debug_mmio_prints + 1;
        end
        if ((debug_mmio_prints < 128) &&
            master[s3k_addr_map_pkg::CLINT].ar_valid &&
            master[s3k_addr_map_pkg::CLINT].ar_ready) begin
          $display("[s3k-mmio] cycle=%0d CLINT AR addr=0x%016h size=%0d",
                   cycle_count,
                   master[s3k_addr_map_pkg::CLINT].ar_addr,
                   master[s3k_addr_map_pkg::CLINT].ar_size);
          debug_mmio_prints <= debug_mmio_prints + 1;
        end
        if ((debug_mmio_prints < 128) &&
            master[s3k_addr_map_pkg::UART].aw_valid &&
            master[s3k_addr_map_pkg::UART].aw_ready) begin
          $display("[s3k-mmio] cycle=%0d UART AW addr=0x%016h size=%0d",
                   cycle_count,
                   master[s3k_addr_map_pkg::UART].aw_addr,
                   master[s3k_addr_map_pkg::UART].aw_size);
          debug_mmio_prints <= debug_mmio_prints + 1;
        end
        if ((debug_mmio_prints < 128) &&
            master[s3k_addr_map_pkg::UART].w_valid &&
            master[s3k_addr_map_pkg::UART].w_ready) begin
          $display("[s3k-mmio] cycle=%0d UART W data=0x%016h strb=0x%0h",
                   cycle_count,
                   master[s3k_addr_map_pkg::UART].w_data,
                   master[s3k_addr_map_pkg::UART].w_strb);
          debug_mmio_prints <= debug_mmio_prints + 1;
        end
        if ((debug_mmio_prints < 128) &&
            master[s3k_addr_map_pkg::UART].ar_valid &&
            master[s3k_addr_map_pkg::UART].ar_ready) begin
          $display("[s3k-mmio] cycle=%0d UART AR addr=0x%016h size=%0d",
                   cycle_count,
                   master[s3k_addr_map_pkg::UART].ar_addr,
                   master[s3k_addr_map_pkg::UART].ar_size);
          debug_mmio_prints <= debug_mmio_prints + 1;
        end
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      axi_error_prints <= '0;
      for (int i = 0; i < AxiDebugSlots; i++) begin
        last_ar_addr_by_id[i] <= '0;
        last_ar_len_by_id[i]  <= '0;
        last_ar_size_by_id[i] <= '0;
        last_aw_addr_by_id[i] <= '0;
        last_aw_len_by_id[i]  <= '0;
        last_aw_size_by_id[i] <= '0;
      end
    end else begin
      if (slave[0].ar_valid && slave[0].ar_ready) begin
        last_ar_addr_by_id[slave[0].ar_id] <= slave[0].ar_addr;
        last_ar_len_by_id[slave[0].ar_id]  <= slave[0].ar_len;
        last_ar_size_by_id[slave[0].ar_id] <= slave[0].ar_size;
      end
      if (slave[0].aw_valid && slave[0].aw_ready) begin
        last_aw_addr_by_id[slave[0].aw_id] <= slave[0].aw_addr;
        last_aw_len_by_id[slave[0].aw_id]  <= slave[0].aw_len;
        last_aw_size_by_id[slave[0].aw_id] <= slave[0].aw_size;
      end

      if (slave[0].r_ready &&
          slave[0].r_valid &&
          slave[0].r_resp inside {axi_pkg::RESP_DECERR, axi_pkg::RESP_SLVERR}) begin
        if (axi_error_prints < 64) begin
          $warning("AXI read response errored id=%0d addr=0x%016h len=%0d size=%0d resp=%0d last=%0d",
                   slave[0].r_id,
                   last_ar_addr_by_id[slave[0].r_id],
                   last_ar_len_by_id[slave[0].r_id],
                   last_ar_size_by_id[slave[0].r_id],
                   slave[0].r_resp,
                   slave[0].r_last);
          axi_error_prints <= axi_error_prints + 1;
        end
      end
      if (slave[0].b_ready &&
          slave[0].b_valid &&
          slave[0].b_resp inside {axi_pkg::RESP_DECERR, axi_pkg::RESP_SLVERR}) begin
        if (axi_error_prints < 64) begin
          $warning("AXI write response errored id=%0d addr=0x%016h len=%0d size=%0d resp=%0d",
                   slave[0].b_id,
                   last_aw_addr_by_id[slave[0].b_id],
                   last_aw_len_by_id[slave[0].b_id],
                   last_aw_size_by_id[slave[0].b_id],
                   slave[0].b_resp);
          axi_error_prints <= axi_error_prints + 1;
        end
      end
    end
  end

  initial begin : preload_elfs
    logic [AXI_DATA_WIDTH-1:0] mem_row;
    longint unsigned address;
    longint unsigned len;
    int unsigned load_index;
    int unsigned num_words;
    int section_status;
    bit section_is_kernel;
    bit use_fast_boot;
    bit verbose_boot;
    int unsigned app_elf_count;
    string app_elf_key;
    string kernel_elf = "";
    string app_elf = "";
    longint unsigned zero_bss_addr;
    longint unsigned init_addr;
    longint unsigned fast_boot_patch_pc;
    longint signed fast_boot_delta;
    logic signed [11:0] fast_boot_cj_imm;
    logic signed [20:0] fast_boot_imm;
    logic [15:0] fast_boot_patch_cj;
    logic [31:0] fast_boot_patch;

    if (!$value$plusargs("kernel_elf=%s", kernel_elf)) begin
      $fatal(1, "missing +kernel_elf=<path>");
    end
    if (!$value$plusargs("app_elf_count=%d", app_elf_count)) begin
      if (!$value$plusargs("app_elf=%s", app_elf)) begin
        $fatal(1, "missing +app_elf=<path>");
      end
      app_elf_count = 1;
    end
    use_fast_boot = $test$plusargs("fast_boot");
    verbose_boot = $test$plusargs("debug_boot");

    i_kernel_mem.clear_all();
    i_dram_mem.clear_all();

    if (read_elf(kernel_elf) != 0) begin
      $fatal(1, "failed to read kernel ELF %s", kernel_elf);
    end
    for (int app_elf_idx = 0; app_elf_idx < app_elf_count; ++app_elf_idx) begin
      if (app_elf_count == 1 && app_elf != "") begin
        app_elf_key = app_elf;
      end else begin
        app_elf_key = $sformatf("app_elf_%0d=%%s", app_elf_idx);
        if (!$value$plusargs(app_elf_key, app_elf)) begin
          $fatal(1, "missing +app_elf_%0d=<path>", app_elf_idx);
        end
      end

      if (read_elf(app_elf) != 0) begin
        $fatal(1, "failed to read app ELF %s", app_elf);
      end
    end

    section_status = get_section(address, len);
    while (section_status != 0) begin
      num_words = int'((len + 7) >> 3);
      section_is_kernel = 1'b0;

      if ((address >= s3k_addr_map_pkg::KernelBase) &&
          ((address + len) <= (s3k_addr_map_pkg::KernelBase + s3k_addr_map_pkg::KernelWindowLength))) begin
        section_is_kernel = 1'b1;
        load_index = int'((address - s3k_addr_map_pkg::KernelBase) >> 3);
        if ((load_index + num_words) > s3k_addr_map_pkg::KernelWords) begin
          $fatal(1, "kernel section out of range at 0x%0h", address);
        end
      end else if ((address >= s3k_addr_map_pkg::DramBase) &&
                   ((address + len) <= (s3k_addr_map_pkg::DramBase + s3k_addr_map_pkg::DramLength))) begin
        load_index = int'((address - s3k_addr_map_pkg::DramBase) >> 3);
        if ((load_index + num_words) > s3k_addr_map_pkg::DramWords) begin
          $fatal(1, "dram section out of range at 0x%0h", address);
        end
      end else begin
        $fatal(1, "ELF section at unsupported address 0x%0h (len 0x%0h)", address, len);
      end

      for (int i = 0; i < num_words; i++) begin
        mem_row = read_section_word(address, i);
        if (section_is_kernel) begin
          i_kernel_mem.write_init_word(load_index + i, mem_row);
        end else begin
          i_dram_mem.write_init_word(load_index + i, mem_row);
        end
      end

      section_status = get_section(address, len);
    end

    if (verbose_boot) begin
      $display("[s3k-preload] kernel[0]=0x%016h kernel[1]=0x%016h dram[0]=0x%016h",
               i_kernel_mem.i_sram.i_tc_sram.sram[0],
               i_kernel_mem.i_sram.i_tc_sram.sram[1],
               i_dram_mem.i_sram.i_tc_sram.sram[0]);
    end

    if (use_fast_boot) begin
      if (get_symbol("_zero_bss", zero_bss_addr) == 0) begin
        $fatal(1, "fast boot could not locate _zero_bss");
      end
      if (get_symbol("_init", init_addr) == 0) begin
        $fatal(1, "fast boot could not locate _init");
      end
      if ((zero_bss_addr < s3k_addr_map_pkg::KernelBase) ||
          (init_addr < s3k_addr_map_pkg::KernelBase) ||
          (zero_bss_addr >= (s3k_addr_map_pkg::KernelBase + s3k_addr_map_pkg::KernelWindowLength)) ||
          (init_addr >= (s3k_addr_map_pkg::KernelBase + s3k_addr_map_pkg::KernelWindowLength))) begin
        $fatal(1, "fast boot symbols are outside kernel memory");
      end

      if (zero_bss_addr < (s3k_addr_map_pkg::KernelBase + 4)) begin
        $fatal(1, "fast boot patch point underflowed");
      end
      fast_boot_patch_pc = zero_bss_addr - 4;
      fast_boot_delta = $signed(init_addr) - $signed(fast_boot_patch_pc);
      if ((fast_boot_delta >= -2048) && (fast_boot_delta <= 2046) && !fast_boot_delta[0]) begin
        fast_boot_cj_imm = fast_boot_delta[11:0];
        fast_boot_patch_cj = encode_cj(fast_boot_cj_imm);
        i_kernel_mem.patch_init_halfword(int'(fast_boot_patch_pc - s3k_addr_map_pkg::KernelBase),
                                         fast_boot_patch_cj);
        if (verbose_boot) begin
          $display("[s3k-fast-boot] patched 0x%016h with c.j to _init@0x%016h",
                   fast_boot_patch_pc, init_addr);
        end
      end else begin
        if ((fast_boot_delta < -1048576) || (fast_boot_delta > 1048574) || fast_boot_delta[0]) begin
          $fatal(1, "fast boot jump delta %0d cannot be encoded", fast_boot_delta);
        end

        fast_boot_imm = fast_boot_delta[20:0];
        fast_boot_patch = encode_jal(fast_boot_imm);
        i_kernel_mem.patch_init_word32(int'(fast_boot_patch_pc - s3k_addr_map_pkg::KernelBase),
                                       fast_boot_patch);
        if (verbose_boot) begin
          $display("[s3k-fast-boot] patched 0x%016h with jal to _init@0x%016h",
                   fast_boot_patch_pc, init_addr);
        end
      end
    end
  end

endmodule
