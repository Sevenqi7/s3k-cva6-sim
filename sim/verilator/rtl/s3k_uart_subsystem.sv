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

  s3k_axi_mock_uart_flexible #(
    .AXI_ADDRESS_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH    ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH      ( AXI_ID_WIDTH      ),
    .AXI_USER_WIDTH    ( AXI_USER_WIDTH    )
  ) i_mock_uart (
    .clk_i           ( clk_i           ),
    .rst_ni          ( rst_ni          ),
    .axi             ( axi             ),
    .uart_tx_valid_o ( uart_tx_valid_o ),
    .uart_tx_data_o  ( uart_tx_data_o  )
  );

endmodule

module s3k_axi_mock_uart_flexible #(
  parameter int unsigned AXI_ADDRESS_WIDTH = 64,
  parameter int unsigned AXI_DATA_WIDTH    = 64,
  parameter int unsigned AXI_ID_WIDTH      = s3k_axi_soc::IdWidthSlave,
  parameter int unsigned AXI_USER_WIDTH    = 1
) (
  input  logic       clk_i,
  input  logic       rst_ni,
  AXI_BUS.Slave      axi,
  output logic       uart_tx_valid_o,
  output logic [7:0] uart_tx_data_o
);

  localparam int unsigned AxiStrbWidth = AXI_DATA_WIDTH / 8;

  localparam logic [2:0] RegThr = 3'd0;
  localparam logic [2:0] RegIer = 3'd1;
  localparam logic [2:0] RegIir = 3'd2;
  localparam logic [2:0] RegFcr = 3'd2;
  localparam logic [2:0] RegLcr = 3'd3;
  localparam logic [2:0] RegMcr = 3'd4;
  localparam logic [2:0] RegLsr = 3'd5;
  localparam logic [2:0] RegMsr = 3'd6;
  localparam logic [2:0] RegScr = 3'd7;

  logic [7:0] lcr_q;
  logic [7:0] dll_q;
  logic [7:0] dlm_q;
  logic [7:0] ier_q;
  logic [7:0] mcr_q;
  logic [7:0] lsr_q;
  logic [7:0] msr_q;
  logic [7:0] scr_q;
  logic       fifo_enabled_q;

  logic                              aw_pending_q;
  logic                              w_pending_q;
  logic [AXI_ID_WIDTH-1:0]           aw_id_q;
  logic [AXI_ADDRESS_WIDTH-1:0]      aw_addr_q;
  logic [AXI_USER_WIDTH-1:0]         aw_user_q;
  logic [AXI_DATA_WIDTH-1:0]         w_data_q;
  logic [AxiStrbWidth-1:0]           w_strb_q;
  logic                              b_valid_q;
  logic [AXI_ID_WIDTH-1:0]           b_id_q;
  logic [AXI_USER_WIDTH-1:0]         b_user_q;
  logic                              r_valid_q;
  logic [AXI_ID_WIDTH-1:0]           r_id_q;
  logic [AXI_DATA_WIDTH-1:0]         r_data_q;
  logic [AXI_USER_WIDTH-1:0]         r_user_q;

  logic aw_fire;
  logic w_fire;
  logic ar_fire;

  assign axi.aw_ready = !b_valid_q && !aw_pending_q;
  assign axi.w_ready  = !b_valid_q && !w_pending_q;
  assign axi.b_id     = b_id_q;
  assign axi.b_resp   = axi_pkg::RESP_OKAY;
  assign axi.b_valid  = b_valid_q;
  assign axi.b_user   = b_user_q;

  assign axi.ar_ready = !r_valid_q;
  assign axi.r_id     = r_id_q;
  assign axi.r_data   = r_data_q;
  assign axi.r_resp   = axi_pkg::RESP_OKAY;
  assign axi.r_last   = 1'b1;
  assign axi.r_valid  = r_valid_q;
  assign axi.r_user   = r_user_q;

  assign aw_fire = axi.aw_valid && axi.aw_ready;
  assign w_fire  = axi.w_valid && axi.w_ready;
  assign ar_fire = axi.ar_valid && axi.ar_ready;

  function automatic logic [2:0] decode_reg(input logic [AXI_ADDRESS_WIDTH-1:0] addr);
    logic [4:0] offset;
    offset = addr[4:0];
    if (offset < 5'd8) begin
      decode_reg = offset[2:0];
    end else begin
      decode_reg = offset[4:2];
    end
  endfunction

  function automatic logic [7:0] read_reg_byte(input logic [2:0] reg_index);
    unique case (reg_index)
      RegThr: read_reg_byte = lcr_q[7] ? dll_q : 8'b0;
      RegIer: read_reg_byte = lcr_q[7] ? dlm_q : ier_q;
      RegIir: read_reg_byte = fifo_enabled_q ? 8'hc0 : 8'h00;
      RegLcr: read_reg_byte = lcr_q;
      RegMcr: read_reg_byte = mcr_q;
      RegLsr: read_reg_byte = lsr_q | 8'h60;
      RegMsr: read_reg_byte = msr_q;
      RegScr: read_reg_byte = scr_q;
      default: read_reg_byte = 8'b0;
    endcase
  endfunction

  function automatic logic [AXI_DATA_WIDTH-1:0] align_read_byte(
    input logic [AXI_ADDRESS_WIDTH-1:0] addr,
    input logic [7:0]                   value
  );
    int unsigned byte_lane;
    align_read_byte = '0;
    byte_lane = int'(addr[$clog2(AxiStrbWidth)-1:0]);
    align_read_byte[(byte_lane * 8) +: 8] = value;
  endfunction

  function automatic logic [7:0] extract_write_byte(
    input logic [AXI_ADDRESS_WIDTH-1:0] addr,
    input logic [AXI_DATA_WIDTH-1:0]    data
  );
    int unsigned byte_lane;
    byte_lane = int'(addr[$clog2(AxiStrbWidth)-1:0]);
    extract_write_byte = data[(byte_lane * 8) +: 8];
  endfunction

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lcr_q <= '0;
      dll_q <= '0;
      dlm_q <= '0;
      ier_q <= '0;
      mcr_q <= '0;
      lsr_q <= '0;
      msr_q <= '0;
      scr_q <= '0;
      fifo_enabled_q <= 1'b0;
      aw_pending_q <= 1'b0;
      w_pending_q <= 1'b0;
      aw_id_q <= '0;
      aw_addr_q <= '0;
      aw_user_q <= '0;
      w_data_q <= '0;
      w_strb_q <= '0;
      b_valid_q <= 1'b0;
      b_id_q <= '0;
      b_user_q <= '0;
      r_valid_q <= 1'b0;
      r_id_q <= '0;
      r_data_q <= '0;
      r_user_q <= '0;
      uart_tx_valid_o <= 1'b0;
      uart_tx_data_o <= '0;
    end else begin
      automatic logic write_ready;
      automatic logic [AXI_ID_WIDTH-1:0] write_id;
      automatic logic [AXI_ADDRESS_WIDTH-1:0] write_addr;
      automatic logic [AXI_USER_WIDTH-1:0] write_user;
      automatic logic [AXI_DATA_WIDTH-1:0] write_data;
      automatic logic [AxiStrbWidth-1:0] write_strb;
      automatic logic [7:0] write_byte;
      automatic logic [2:0] write_reg;

      uart_tx_valid_o <= 1'b0;

      if (b_valid_q && axi.b_ready) begin
        b_valid_q <= 1'b0;
      end
      if (r_valid_q && axi.r_ready) begin
        r_valid_q <= 1'b0;
      end

      if (aw_fire) begin
        aw_pending_q <= 1'b1;
        aw_id_q <= axi.aw_id;
        aw_addr_q <= axi.aw_addr;
        aw_user_q <= axi.aw_user;
      end
      if (w_fire) begin
        w_pending_q <= 1'b1;
        w_data_q <= axi.w_data;
        w_strb_q <= axi.w_strb;
      end

      write_ready = (aw_pending_q || aw_fire) && (w_pending_q || w_fire) && !b_valid_q;
      if (write_ready) begin
        write_id = aw_fire ? axi.aw_id : aw_id_q;
        write_addr = aw_fire ? axi.aw_addr : aw_addr_q;
        write_user = aw_fire ? axi.aw_user : aw_user_q;
        write_data = w_fire ? axi.w_data : w_data_q;
        write_strb = w_fire ? axi.w_strb : w_strb_q;
        write_byte = extract_write_byte(write_addr, write_data);
        write_reg = decode_reg(write_addr);

        if (write_strb[int'(write_addr[$clog2(AxiStrbWidth)-1:0])]) begin
          unique case (write_reg)
            RegThr: begin
              if (lcr_q[7]) begin
                dll_q <= write_byte;
              end else begin
                uart_tx_valid_o <= 1'b1;
                uart_tx_data_o <= write_byte;
              end
            end
            RegIer: begin
              if (lcr_q[7]) begin
                dlm_q <= write_byte;
              end else begin
                ier_q <= write_byte[3:0];
              end
            end
            RegFcr: fifo_enabled_q <= write_byte[0];
            RegLcr: lcr_q <= write_byte;
            RegMcr: mcr_q <= write_byte[4:0];
            RegLsr: lsr_q <= write_byte;
            RegMsr: msr_q <= write_byte;
            RegScr: scr_q <= write_byte;
            default: ;
          endcase
        end

        aw_pending_q <= 1'b0;
        w_pending_q <= 1'b0;
        b_valid_q <= 1'b1;
        b_id_q <= write_id;
        b_user_q <= write_user;
      end

      if (ar_fire) begin
        r_valid_q <= 1'b1;
        r_id_q <= axi.ar_id;
        r_data_q <= align_read_byte(axi.ar_addr, read_reg_byte(decode_reg(axi.ar_addr)));
        r_user_q <= axi.ar_user;
      end
    end
  end

endmodule

module s3k_mock_uart_flexible (
  input  logic        clk_i,
  input  logic        rst_ni,
  input  logic        penable_i,
  input  logic        pwrite_i,
  input  logic [31:0] paddr_i,
  input  logic        psel_i,
  input  logic [31:0] pwdata_i,
  output logic [31:0] prdata_o,
  output logic        pready_o,
  output logic        pslverr_o,
  output logic        uart_tx_valid_o,
  output logic [7:0]  uart_tx_data_o
);

  localparam logic [2:0] RegThr = 3'd0;
  localparam logic [2:0] RegIer = 3'd1;
  localparam logic [2:0] RegIir = 3'd2;
  localparam logic [2:0] RegFcr = 3'd2;
  localparam logic [2:0] RegLcr = 3'd3;
  localparam logic [2:0] RegMcr = 3'd4;
  localparam logic [2:0] RegLsr = 3'd5;
  localparam logic [2:0] RegMsr = 3'd6;
  localparam logic [2:0] RegScr = 3'd7;

  logic [7:0] lcr_q;
  logic [7:0] dll_q;
  logic [7:0] dlm_q;
  logic [7:0] ier_q;
  logic [7:0] mcr_q;
  logic [7:0] lsr_q;
  logic [7:0] msr_q;
  logic [7:0] scr_q;
  logic       fifo_enabled_q;
  logic [2:0] reg_index;

  assign pready_o = 1'b1;
  assign pslverr_o = 1'b0;

  function automatic logic [2:0] decode_reg(input logic [31:0] addr);
    logic [4:0] offset;
    offset = addr[4:0];
    if (offset < 5'd8) begin
      decode_reg = offset[2:0];
    end else begin
      decode_reg = offset[4:2];
    end
  endfunction

  assign reg_index = decode_reg(paddr_i);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      lcr_q <= '0;
      dll_q <= '0;
      dlm_q <= '0;
      ier_q <= '0;
      mcr_q <= '0;
      lsr_q <= '0;
      msr_q <= '0;
      scr_q <= '0;
      fifo_enabled_q <= 1'b0;
      uart_tx_valid_o <= 1'b0;
      uart_tx_data_o <= '0;
    end else begin
      uart_tx_valid_o <= 1'b0;
      if (psel_i && penable_i && pwrite_i) begin
        unique case (reg_index)
          RegThr: begin
            if (lcr_q[7]) begin
              dll_q <= pwdata_i[7:0];
            end else begin
              uart_tx_valid_o <= 1'b1;
              uart_tx_data_o <= pwdata_i[7:0];
            end
          end
          RegIer: begin
            if (lcr_q[7]) begin
              dlm_q <= pwdata_i[7:0];
            end else begin
              ier_q <= pwdata_i[3:0];
            end
          end
          RegFcr: fifo_enabled_q <= pwdata_i[0];
          RegLcr: lcr_q <= pwdata_i[7:0];
          RegMcr: mcr_q <= pwdata_i[4:0];
          RegLsr: lsr_q <= pwdata_i[7:0];
          RegMsr: msr_q <= pwdata_i[7:0];
          RegScr: scr_q <= pwdata_i[7:0];
          default: ;
        endcase
      end
    end
  end

  always_comb begin
    prdata_o = '0;
    if (psel_i && penable_i && !pwrite_i) begin
      unique case (reg_index)
        RegThr: begin
          if (lcr_q[7]) begin
            prdata_o = {24'b0, dll_q};
          end
        end
        RegIer: begin
          if (lcr_q[7]) begin
            prdata_o = {24'b0, dlm_q};
          end else begin
            prdata_o = {24'b0, ier_q};
          end
        end
        RegIir: prdata_o = {24'b0, fifo_enabled_q ? 8'hc0 : 8'h00};
        RegLcr: prdata_o = {24'b0, lcr_q};
        RegMcr: prdata_o = {24'b0, mcr_q};
        RegLsr: prdata_o = {24'b0, lsr_q | 8'h60};
        RegMsr: prdata_o = {24'b0, msr_q};
        RegScr: prdata_o = {24'b0, scr_q};
        default: ;
      endcase
    end
  end

endmodule
