module s3k_axi_sram #(
  parameter int unsigned AXI_USER_WIDTH    = ariane_pkg::AXI_USER_WIDTH,
  parameter int unsigned AXI_USER_EN       = ariane_pkg::AXI_USER_EN,
  parameter int unsigned AXI_ADDRESS_WIDTH = 64,
  parameter int unsigned AXI_DATA_WIDTH    = 64,
  parameter int unsigned AXI_ID_WIDTH      = s3k_axi_soc::IdWidthSlave,
  parameter int unsigned NUM_WORDS         = 1024
) (
  input  logic clk_i,
  input  logic rst_ni,
  AXI_BUS.Slave axi
);

  localparam int unsigned WordIndexWidth = (NUM_WORDS > 1) ? $clog2(NUM_WORDS) : 1;
  localparam int unsigned BytesPerWord   = AXI_DATA_WIDTH / 8;

  AXI_BUS #(
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH   ( AXI_ID_WIDTH      ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) axi_raw ();

  logic                         req;
  logic                         we;
  logic [AXI_ADDRESS_WIDTH-1:0] addr;
  logic [AXI_DATA_WIDTH/8-1:0]  be;
  logic [AXI_DATA_WIDTH-1:0]    wdata;
  logic [AXI_DATA_WIDTH-1:0]    rdata;
  logic [AXI_USER_WIDTH-1:0]    wuser;
  logic [AXI_USER_WIDTH-1:0]    ruser;

  axi_riscv_atomics_wrap #(
    .AXI_ADDR_WIDTH     ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH     ( AXI_DATA_WIDTH    ),
    .AXI_ID_WIDTH       ( AXI_ID_WIDTH      ),
    .AXI_USER_WIDTH     ( AXI_USER_WIDTH    ),
    .AXI_MAX_WRITE_TXNS ( 1                 ),
    .RISCV_WORD_WIDTH   ( 64                )
  ) i_axi_riscv_atomics (
    .clk_i  ( clk_i   ),
    .rst_ni ( rst_ni  ),
    .mst    ( axi_raw ),
    .slv    ( axi     )
  );

  axi2mem #(
    .AXI_ID_WIDTH   ( AXI_ID_WIDTH      ),
    .AXI_ADDR_WIDTH ( AXI_ADDRESS_WIDTH ),
    .AXI_DATA_WIDTH ( AXI_DATA_WIDTH    ),
    .AXI_USER_WIDTH ( AXI_USER_WIDTH    )
  ) i_axi2mem (
    .clk_i  ( clk_i    ),
    .rst_ni ( rst_ni   ),
    .slave  ( axi_raw  ),
    .req_o  ( req      ),
    .we_o   ( we       ),
    .addr_o ( addr     ),
    .be_o   ( be       ),
    .user_o ( wuser    ),
    .data_o ( wdata    ),
    .user_i ( ruser    ),
    .data_i ( rdata    )
  );

  sram #(
    .DATA_WIDTH ( AXI_DATA_WIDTH ),
    .USER_WIDTH ( AXI_USER_WIDTH ),
    .USER_EN    ( AXI_USER_EN    ),
    .SIM_INIT   ( "none"         ),
    .NUM_WORDS  ( NUM_WORDS      )
  ) i_sram (
    .clk_i   ( clk_i ),
    .rst_ni  ( rst_ni ),
    .req_i   ( req ),
    .we_i    ( we ),
    .addr_i  ( addr[$clog2(NUM_WORDS)-1+$clog2(AXI_DATA_WIDTH/8):$clog2(AXI_DATA_WIDTH/8)] ),
    .wuser_i ( wuser ),
    .wdata_i ( wdata ),
    .be_i    ( be ),
    .ruser_o ( ruser ),
    .rdata_o ( rdata )
  );

  task automatic write_init_word(
    input int unsigned                 word_idx,
    input logic [AXI_DATA_WIDTH-1:0]   word_data
  );
    if (word_idx >= NUM_WORDS) begin
      $fatal(1, "s3k_axi_sram preload index %0d out of range (NUM_WORDS=%0d)", word_idx, NUM_WORDS);
    end
    i_sram.i_tc_sram.init_val[word_idx[WordIndexWidth-1:0]] = word_data[63:0];
    i_sram.i_tc_sram.sram[word_idx[WordIndexWidth-1:0]] = word_data[63:0];
  endtask

  task automatic clear_all();
    for (int unsigned word_idx = 0; word_idx < NUM_WORDS; word_idx++) begin
      i_sram.i_tc_sram.init_val[word_idx[WordIndexWidth-1:0]] = '0;
      i_sram.i_tc_sram.sram[word_idx[WordIndexWidth-1:0]] = '0;
    end
    i_sram.i_tc_sram.r_addr_q[0] = '0;
    i_sram.i_tc_sram.rdata_q[0][0] = '0;
  endtask

  task automatic patch_init_halfword(
    input int unsigned               byte_addr,
    input logic [15:0]               halfword_data
  );
    int unsigned word_idx;
    int unsigned byte_offset;
    int unsigned bit_offset;
    logic [AXI_DATA_WIDTH-1:0] word_data;

    if ((byte_addr + 2) > (NUM_WORDS * BytesPerWord)) begin
      $fatal(1, "s3k_axi_sram patch addr 0x%0x out of range", byte_addr);
    end

    word_idx = byte_addr / BytesPerWord;
    byte_offset = byte_addr % BytesPerWord;
    if (byte_offset > (BytesPerWord - 2)) begin
      $fatal(1, "s3k_axi_sram halfword patch crosses word boundary at 0x%0x", byte_addr);
    end

    bit_offset = byte_offset * 8;
    word_data = i_sram.i_tc_sram.init_val[word_idx[WordIndexWidth-1:0]];
    word_data[bit_offset +: 16] = halfword_data;
    i_sram.i_tc_sram.init_val[word_idx[WordIndexWidth-1:0]] = word_data;
    i_sram.i_tc_sram.sram[word_idx[WordIndexWidth-1:0]] = word_data;
  endtask

  task automatic patch_init_word32(
    input int unsigned               byte_addr,
    input logic [31:0]               word32_data
  );
    int unsigned word_idx;
    int unsigned byte_offset;
    int unsigned bit_offset;
    logic [AXI_DATA_WIDTH-1:0] word_data;

    if ((byte_addr + 4) > (NUM_WORDS * BytesPerWord)) begin
      $fatal(1, "s3k_axi_sram 32-bit patch addr 0x%0x out of range", byte_addr);
    end

    word_idx = byte_addr / BytesPerWord;
    byte_offset = byte_addr % BytesPerWord;
    if (byte_offset > (BytesPerWord - 4)) begin
      $fatal(1, "s3k_axi_sram 32-bit patch crosses word boundary at 0x%0x", byte_addr);
    end

    bit_offset = byte_offset * 8;
    word_data = i_sram.i_tc_sram.init_val[word_idx[WordIndexWidth-1:0]];
    word_data[bit_offset +: 32] = word32_data;
    i_sram.i_tc_sram.init_val[word_idx[WordIndexWidth-1:0]] = word_data;
    i_sram.i_tc_sram.sram[word_idx[WordIndexWidth-1:0]] = word_data;
  endtask

endmodule
