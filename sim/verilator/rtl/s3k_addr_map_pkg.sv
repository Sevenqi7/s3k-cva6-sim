package s3k_addr_map_pkg;

  localparam int unsigned NrSlaves = 1;

  typedef enum int unsigned {
    DRAM  = 0,
    UART  = 1,
    CLINT = 2,
    SPM   = 3
  } axi_masters_t;

  localparam int unsigned NB_PERIPHERALS = SPM + 1;

  localparam logic [63:0] KernelBase         = 64'h0000_0000_1000_0000;
  localparam logic [63:0] KernelWindowLength = 64'h0000_0000_0002_0000;
  localparam logic [63:0] SpmBase            = 64'h0000_0000_1001_0000;
  localparam logic [63:0] SpmLength          = 64'h0000_0000_0001_0000;

  localparam logic [63:0] ClintBase   = 64'h0000_0000_0204_0000;
  localparam logic [63:0] ClintLength = 64'h0000_0000_000C_0000;

  localparam logic [63:0] UartBase   = 64'h0000_0000_0300_2000;
  localparam logic [63:0] UartLength = 64'h0000_0000_0000_1000;

  localparam logic [63:0] DramBase   = 64'h0000_0000_8000_0000;
  localparam logic [63:0] DramLength = 64'h0000_0000_0010_0000;

  localparam int unsigned KernelWords = int'(KernelWindowLength >> 3);
  localparam int unsigned DramWords   = int'(DramLength >> 3);

endpackage
