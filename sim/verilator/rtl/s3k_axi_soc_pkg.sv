package s3k_axi_soc;

  localparam int unsigned UserWidth = ariane_axi::UserWidth;
  localparam int unsigned AddrWidth = ariane_axi::AddrWidth;
  localparam int unsigned DataWidth = ariane_axi::DataWidth;
  localparam int unsigned StrbWidth = DataWidth / 8;
  localparam int unsigned IdWidth = ariane_axi::IdWidth;
  localparam int unsigned IdWidthSlave = IdWidth + $clog2(s3k_addr_map_pkg::NrSlaves);

  typedef logic [IdWidth-1:0] id_t;
  typedef logic [IdWidthSlave-1:0] id_slv_t;
  typedef logic [AddrWidth-1:0] addr_t;
  typedef logic [DataWidth-1:0] data_t;
  typedef logic [StrbWidth-1:0] strb_t;
  typedef logic [UserWidth-1:0] user_t;

  typedef struct packed {
    id_slv_t         id;
    addr_t           addr;
    axi_pkg::len_t   len;
    axi_pkg::size_t  size;
    axi_pkg::burst_t burst;
    logic            lock;
    axi_pkg::cache_t cache;
    axi_pkg::prot_t  prot;
    axi_pkg::qos_t   qos;
    axi_pkg::region_t region;
    axi_pkg::atop_t  atop;
    user_t           user;
  } aw_chan_slv_t;

  typedef struct packed {
    id_slv_t        id;
    axi_pkg::resp_t resp;
    user_t          user;
  } b_chan_slv_t;

  typedef struct packed {
    id_slv_t         id;
    addr_t           addr;
    axi_pkg::len_t   len;
    axi_pkg::size_t  size;
    axi_pkg::burst_t burst;
    logic            lock;
    axi_pkg::cache_t cache;
    axi_pkg::prot_t  prot;
    axi_pkg::qos_t   qos;
    axi_pkg::region_t region;
    user_t           user;
  } ar_chan_slv_t;

  typedef struct packed {
    id_slv_t        id;
    data_t          data;
    axi_pkg::resp_t resp;
    logic           last;
    user_t          user;
  } r_chan_slv_t;

  typedef struct packed {
    aw_chan_slv_t    aw;
    logic            aw_valid;
    ariane_axi::w_chan_t w;
    logic            w_valid;
    logic            b_ready;
    ar_chan_slv_t    ar;
    logic            ar_valid;
    logic            r_ready;
  } req_slv_t;

  typedef struct packed {
    logic       aw_ready;
    logic       ar_ready;
    logic       w_ready;
    logic       b_valid;
    b_chan_slv_t b;
    logic       r_valid;
    r_chan_slv_t r;
  } resp_slv_t;

endpackage
