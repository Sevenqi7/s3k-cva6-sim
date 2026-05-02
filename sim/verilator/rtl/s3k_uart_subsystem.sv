module s3k_uart_subsystem #(
  parameter int unsigned AXI_ADDRESS_WIDTH = 64,
  parameter int unsigned AXI_DATA_WIDTH    = 64,
  parameter int unsigned AXI_ID_WIDTH      = s3k_axi_soc::IdWidthSlave,
  parameter int unsigned AXI_USER_WIDTH    = 1
) (
  input logic clk_i,
  input logic rst_ni,
  AXI_BUS.Slave axi,
  output logic uart_tx_valid_o,
  output logic [7:0] uart_tx_data_o
);

  logic        uart_penable;
  logic        uart_pwrite;
  logic [31:0] uart_paddr;
  logic        uart_psel;
  logic [31:0] uart_pwdata;
  logic [31:0] uart_prdata;
  logic        uart_pready;
  logic        uart_pslverr;
  logic        uart_tx_fire;

  axi2apb_64_32 #(
    .AXI4_ADDRESS_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI4_RDATA_WIDTH   ( AXI_DATA_WIDTH    ),
    .AXI4_WDATA_WIDTH   ( AXI_DATA_WIDTH    ),
    .AXI4_ID_WIDTH      ( AXI_ID_WIDTH      ),
    .AXI4_USER_WIDTH    ( AXI_USER_WIDTH    ),
    .BUFF_DEPTH_SLAVE   ( 2                 ),
    .APB_ADDR_WIDTH     ( 32                )
  ) i_axi2apb_64_32_uart (
    .ACLK       ( clk_i         ),
    .ARESETn    ( rst_ni        ),
    .test_en_i  ( 1'b0          ),
    .AWID_i     ( axi.aw_id     ),
    .AWADDR_i   ( axi.aw_addr   ),
    .AWLEN_i    ( axi.aw_len    ),
    .AWSIZE_i   ( axi.aw_size   ),
    .AWBURST_i  ( axi.aw_burst  ),
    .AWLOCK_i   ( axi.aw_lock   ),
    .AWCACHE_i  ( axi.aw_cache  ),
    .AWPROT_i   ( axi.aw_prot   ),
    .AWREGION_i ( axi.aw_region ),
    .AWUSER_i   ( axi.aw_user   ),
    .AWQOS_i    ( axi.aw_qos    ),
    .AWVALID_i  ( axi.aw_valid  ),
    .AWREADY_o  ( axi.aw_ready  ),
    .WDATA_i    ( axi.w_data    ),
    .WSTRB_i    ( axi.w_strb    ),
    .WLAST_i    ( axi.w_last    ),
    .WUSER_i    ( axi.w_user    ),
    .WVALID_i   ( axi.w_valid   ),
    .WREADY_o   ( axi.w_ready   ),
    .BID_o      ( axi.b_id      ),
    .BRESP_o    ( axi.b_resp    ),
    .BVALID_o   ( axi.b_valid   ),
    .BUSER_o    ( axi.b_user    ),
    .BREADY_i   ( axi.b_ready   ),
    .ARID_i     ( axi.ar_id     ),
    .ARADDR_i   ( axi.ar_addr   ),
    .ARLEN_i    ( axi.ar_len    ),
    .ARSIZE_i   ( axi.ar_size   ),
    .ARBURST_i  ( axi.ar_burst  ),
    .ARLOCK_i   ( axi.ar_lock   ),
    .ARCACHE_i  ( axi.ar_cache  ),
    .ARPROT_i   ( axi.ar_prot   ),
    .ARREGION_i ( axi.ar_region ),
    .ARUSER_i   ( axi.ar_user   ),
    .ARQOS_i    ( axi.ar_qos    ),
    .ARVALID_i  ( axi.ar_valid  ),
    .ARREADY_o  ( axi.ar_ready  ),
    .RID_o      ( axi.r_id      ),
    .RDATA_o    ( axi.r_data    ),
    .RRESP_o    ( axi.r_resp    ),
    .RLAST_o    ( axi.r_last    ),
    .RUSER_o    ( axi.r_user    ),
    .RVALID_o   ( axi.r_valid   ),
    .RREADY_i   ( axi.r_ready   ),
    .PENABLE    ( uart_penable  ),
    .PWRITE     ( uart_pwrite   ),
    .PADDR      ( uart_paddr    ),
    .PSEL       ( uart_psel     ),
    .PWDATA     ( uart_pwdata   ),
    .PRDATA     ( uart_prdata   ),
    .PREADY     ( uart_pready   ),
    .PSLVERR    ( uart_pslverr  )
  );

  mock_uart i_mock_uart (
    .clk_i     ( clk_i        ),
    .rst_ni    ( rst_ni       ),
    .penable_i ( uart_penable ),
    .pwrite_i  ( uart_pwrite  ),
    .paddr_i   ( uart_paddr   ),
    .psel_i    ( uart_psel    ),
    .pwdata_i  ( uart_pwdata  ),
    .prdata_o  ( uart_prdata  ),
    .pready_o  ( uart_pready  ),
    .pslverr_o ( uart_pslverr )
  );

  assign uart_tx_fire = uart_psel && uart_penable && uart_pwrite && uart_pready &&
                        ((((uart_paddr >> 'h2) & 'h7) == 32'h0)) &&
                        ((i_mock_uart.lcr & 8'h80) == '0);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      uart_tx_valid_o <= 1'b0;
      uart_tx_data_o <= '0;
    end else begin
      uart_tx_valid_o <= uart_tx_fire;
      if (uart_tx_fire) begin
        uart_tx_data_o <= uart_pwdata[7:0];
      end
    end
  end

endmodule
