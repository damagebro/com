/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/08/30-11:31:12
*
*  Description:
*  - not include {axqos, axsize,axburst,axcache,axprot,axregion} signal;  axqos is important, other signal tie value by user;
*  - ${PROJ_NAME}_axi_dma, each project/subsys have their own xx_axi_dma module;  becasue com_axi_extd_rd need fifo_sram, sram_depth decide by "localparam RCH_BUF_DEPTH";
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_dma #( parameter
    WCH         = 3   , //range=[1:32], number of ebus write channals;
    RCH         = 5   , //range=[1:32], number of ebus read  channals;
    AW          = 32  , //range=[8:64]
    DW          = 128 , //range=[8::2^n]
    EBUS_LW     = 32  , //range=[8:AW] ebus max_burst_bytelen.bit_width;
    LW          = 8   , //range=[1:8], axi  max_burst_wordlen.bit_width;
    UW          = 1   , //range=[1:],  ebus_axusr and axi_axusr, axuser go-though this module;
    BOUND_BYTES = 4096, //range=[DW/8:4096:2^n], addr boundary split bytesize;
    MAX_OSD     = 128 , //range=[1:1024], max axi_cmd outstanding num
    MAX_LEN     = 4   , //range=[1:256], max axi_cmd burst_len, not minus 1;
    localparam SW = DW/8  //,
)
(
input  wire                         clk                  ,
input  wire                         rst_n                ,
input  wire                         clear                ,
input  wire [`COM_SYS_W-1:0]        mem_cfg              ,
// input  wire [`COM_SRAM_W-1:0]       i_cfg_sram_ctrl      ,
//cfg&status---
input  wire [7:0]                   i_cfg_max_blen_m1       , //range=[0:MAX_LEN-1];
input  wire [RCH-1:0][15:0]         i_cfg_rch_max_rdcmd_osd , //if(i_cfg_max_rdcmd_osd==0), axi_osd=MAX_OSD; else if(i_cfg_max_rdcmd_osd>0), axi_osd=min(MAX_OSD,i_cfg_max_rdcmd_osd,func(BUF_DEPTH,i_cfg_max_blen_m1))
output wire [RCH-1:0][15:0]         o_sta_rch_rdbuf_wl      , //the status of rdbuf water_level signal, wl is remain space of rd_buf;
output wire                         o_sta_rch_clr_ongoing   , //level signal;  axi_bus protect from synchrous clear,  if clear=1, this dma module wait all axi_transaction complete with o_sta_rch_clr_ongoing=1; after finish, o_sta_rch_clr_ongoing=0;
output wire                         o_sta_wch_clr_ongoing   , //level signal;  axi_bus protect from synchrous clear,  if clear=1, this dma module wait all axi_transaction complete with o_sta_wch_clr_ongoing=1; after finish, o_sta_wch_clr_ongoing=0;
//ebus
input  wire [WCH-1:0][UW-1:0]       i_rx_ebus_wa_user    ,
input  wire [WCH-1:0][AW-1:0]       i_rx_ebus_wa_addr    ,
input  wire [WCH-1:0][EBUS_LW-1:0]  i_rx_ebus_wa_bytelen ,
input  wire [WCH-1:0]               i_rx_ebus_wa_valid   , //ebus "addr_befor_data/addr_with_data/addr_after_data" all ok;
output wire [WCH-1:0]               o_rx_ebus_wa_ready   ,
input  wire [WCH-1:0][DW-1:0]       i_rx_ebus_wd_data    ,
input  wire [WCH-1:0]               i_rx_ebus_wd_valid   ,
output wire [WCH-1:0]               o_rx_ebus_wd_ready   ,
output wire [WCH-1:0]               o_rx_ebus_wb_valid   ,
input  wire [RCH-1:0][UW-1:0]       i_rx_ebus_ra_user    ,
input  wire [RCH-1:0][AW-1:0]       i_rx_ebus_ra_addr    ,
input  wire [RCH-1:0][EBUS_LW-1:0]  i_rx_ebus_ra_bytelen ,
input  wire [RCH-1:0]               i_rx_ebus_ra_valid   ,
output wire [RCH-1:0]               o_rx_ebus_ra_ready   ,
output wire [RCH-1:0][DW-1:0]       o_rx_ebus_rd_data    ,
output wire [RCH-1:0]               o_rx_ebus_rd_last    ,
output wire [RCH-1:0]               o_rx_ebus_rd_valid   ,
input  wire [RCH-1:0]               i_rx_ebus_rd_ready   ,
//axi,
//not include {axqos, axsize,axburst,axcache,axprot,axregion} signal;  axqos is important, other signal tie value by "user";
output wire [IW-1:0]                o_tx_axi_awid        ,
output wire [AW-1:0]                o_tx_axi_awaddr      ,
output wire [LW-1:0]                o_tx_axi_awlen       ,
output wire [UW-1:0]                o_tx_axi_awuser      ,
output wire                         o_tx_axi_awvalid     ,
input  wire                         i_tx_axi_awready     ,
output wire [DW-1:0]                o_tx_axi_wdata       ,
output wire [DW/8-1:0]              o_tx_axi_wstrb       ,
output wire                         o_tx_axi_wlast       ,
output wire                         o_tx_axi_wvalid      ,
input  wire                         i_tx_axi_wready      ,
input  wire [1:0]                   i_tx_axi_bresp       , //0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR
input  wire [IW-1:0]                i_tx_axi_bid         ,
input  wire                         i_tx_axi_bvalid      ,
output wire                         o_tx_axi_bready      ,
output wire [IW-1:0]                o_tx_axi_arid        ,
output wire [AW-1:0]                o_tx_axi_araddr      ,
output wire [LW-1:0]                o_tx_axi_arlen       ,
output wire [UW-1:0]                o_tx_axi_aruser      ,
output wire                         o_tx_axi_arvalid     ,
input  wire                         i_tx_axi_arready     ,
input  wire [1:0]                   i_tx_axi_rresp       , //0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR
input  wire [IW-1:0]                i_tx_axi_rid         ,
input  wire [DW-1:0]                i_tx_axi_rdata       ,
input  wire                         i_tx_axi_rlast       ,
input  wire                         i_tx_axi_rvalid      ,
output wire                         o_tx_axi_rready      //,
);
//localparam-----------------------------------------------------------------
localparam int RCH_MAX_REG_FIFO_DEPTH = 16;  //fifo_data_storage can use dff+sram, here specify max_dff_depth=16, largher than max_dff_depth(exceed part=BUF_DEPTH-max_dff_depth) use sram as storage;
parameter  int RCH_BUF_DEPTH[0:RCH-1] = '{0};  //here change by user, each project/subsys specify by actually Scenario; //若值数量少于数组长度，未赋值的元素默认为 0； 若值数量多于数组长度，编译报错
localparam int WCH_BUF_DEPTH = MAX_LEN+2;
//signal declare-------------------------------------------------------------

//instance signal--
wire [WCH-1:0][AW-1:0]       u_extd_wr_o_tx_axi_awaddr   ;
wire [WCH-1:0][LW-1:0]       u_extd_wr_o_tx_axi_awlen    ;
wire [WCH-1:0][UW-1:0]       u_extd_wr_o_tx_axi_awuser   ;
wire [WCH-1:0]               u_extd_wr_o_tx_axi_awvalid  ;
wire [WCH-1:0]               u_extd_wr_i_tx_axi_awready  ;
wire [WCH-1:0][DW-1:0]       u_extd_wr_o_tx_axi_wdata    ;
wire [WCH-1:0][DW/8-1:0]     u_extd_wr_o_tx_axi_wstrb    ;
wire [WCH-1:0]               u_extd_wr_o_tx_axi_wlast    ;
wire [WCH-1:0]               u_extd_wr_o_tx_axi_wvalid   ;
wire [WCH-1:0]               u_extd_wr_i_tx_axi_wready   ;
wire [WCH-1:0]               u_extd_wr_i_tx_axi_bvalid   ;
wire [WCH-1:0]               u_extd_wr_o_tx_axi_bready   ;
wire [WCH-1:0][AW-1:0]       u_wch_i_rx_axi_awaddr     ;
wire [WCH-1:0][LW-1:0]       u_wch_i_rx_axi_awlen      ;
wire [WCH-1:0][UW-1:0]       u_wch_i_rx_axi_awuser     ;
wire [WCH-1:0]               u_wch_i_rx_axi_awvalid    ;
wire [WCH-1:0]               u_wch_o_rx_axi_awready    ;
wire [WCH-1:0][DW-1:0]       u_wch_i_rx_axi_wdata      ;
wire [WCH-1:0][DW/8-1:0]     u_wch_i_rx_axi_wstrb      ;
wire [WCH-1:0]               u_wch_i_rx_axi_wlast      ;
wire [WCH-1:0]               u_wch_i_rx_axi_wvalid     ;
wire [WCH-1:0]               u_wch_o_rx_axi_wready     ;
wire [WCH-1:0][1:0]          u_wch_o_rx_axi_bresp      ; //tmp unused
wire [WCH-1:0]               u_wch_o_rx_axi_bvalid     ;
wire [WCH-1:0]               u_wch_i_rx_axi_bready     ;

wire [RCH-1:0][AW-1:0]       u_extd_rd_o_tx_axi_araddr   ;
wire [RCH-1:0][LW-1:0]       u_extd_rd_o_tx_axi_arlen    ;
wire [RCH-1:0][UW-1:0]       u_extd_rd_o_tx_axi_aruser   ;
wire [RCH-1:0]               u_extd_rd_o_tx_axi_arvalid  ;
wire [RCH-1:0]               u_extd_rd_i_tx_axi_arready  ;
wire [RCH-1:0][DW-1:0]       u_extd_rd_i_tx_axi_rdata    ;
wire [RCH-1:0]               u_extd_rd_i_tx_axi_rlast    ;
wire [RCH-1:0]               u_extd_rd_i_tx_axi_rvalid   ;
wire [RCH-1:0]               u_extd_rd_o_tx_axi_rready   ;
wire [RCH-1:0][AW-1:0]       u_rch_i_rx_axi_araddr     ;
wire [RCH-1:0][LW-1:0]       u_rch_i_rx_axi_arlen      ;
wire [RCH-1:0][UW-1:0]       u_rch_i_rx_axi_aruser     ;
wire [RCH-1:0]               u_rch_i_rx_axi_arvalid    ;
wire [RCH-1:0]               u_rch_o_rx_axi_arready    ;
wire [RCH-1:0][1:0]          u_rch_o_rx_axi_rresp      ;
wire [RCH-1:0][DW-1:0]       u_rch_o_rx_axi_rdata      ;
wire [RCH-1:0]               u_rch_o_rx_axi_rlast      ;
wire [RCH-1:0]               u_rch_o_rx_axi_rvalid     ;
wire [RCH-1:0]               u_rch_i_rx_axi_rready     ;
//statement------------------------------------------------------------------

//1. write channel---
assign u_extd_wr_i_tx_axi_awready  = u_wch_o_rx_axi_awready ;
assign u_extd_wr_i_tx_axi_wready   = u_wch_o_rx_axi_wready  ;
assign u_extd_wr_i_tx_axi_bvalid   = u_wch_o_rx_axi_bvalid  ;
com_axi_extd_wr #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .EBUS_LW                        ( EBUS_LW                       ), //32
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .BOUND_BYTES                    ( BOUND_BYTES                   ), //4096
    .MAX_OSD                        ( MAX_OSD                       ), //128
    .BUF_DEPTH                      ( WCH_BUF_DEPTH                 )  //8
)u1_com_axi_extd_wr[WCH-1:0] (
    .clk                 ( clk                        ), //i
    .rst_n               ( rst_n                      ), //i
    .clear               ( clear                      ), //i
    .i_cfg_max_blen_m1   ( i_cfg_max_blen_m1          ), //i
    .ebus_wa_user        ( i_rx_ebus_wa_user          ), //i
    .ebus_wa_addr        ( i_rx_ebus_wa_addr          ), //i
    .ebus_wa_bytelen     ( i_rx_ebus_wa_bytelen       ), //i
    .ebus_wa_valid       ( i_rx_ebus_wa_valid         ), //i
    .ebus_wa_ready       ( o_rx_ebus_wa_ready         ), //o
    .ebus_wd_data        ( i_rx_ebus_wd_data          ), //i
    .ebus_wd_valid       ( i_rx_ebus_wd_valid         ), //i
    .ebus_wd_ready       ( o_rx_ebus_wd_ready         ), //o
    .ebus_wb_valid       ( o_rx_ebus_wb_valid         ), //o
    .axi_awaddr          ( u_extd_wr_o_tx_axi_awaddr  ), //o
    .axi_awlen           ( u_extd_wr_o_tx_axi_awlen   ), //o
    .axi_awuser          ( u_extd_wr_o_tx_axi_awuser  ), //o
    .axi_awvalid         ( u_extd_wr_o_tx_axi_awvalid ), //o
    .axi_awready         ( u_extd_wr_i_tx_axi_awready ), //i
    .axi_wdata           ( u_extd_wr_o_tx_axi_wdata   ), //o
    .axi_wstrb           ( u_extd_wr_o_tx_axi_wstrb   ), //o
    .axi_wlast           ( u_extd_wr_o_tx_axi_wlast   ), //o
    .axi_wvalid          ( u_extd_wr_o_tx_axi_wvalid  ), //o
    .axi_wready          ( u_extd_wr_i_tx_axi_wready  ), //i
    .axi_bvalid          ( u_extd_wr_i_tx_axi_bvalid  ), //i
    .axi_bready          ( u_extd_wr_o_tx_axi_bready  )  //o
);

assign u_wch_i_rx_axi_awaddr   =  u_extd_wr_o_tx_axi_awaddr ;
assign u_wch_i_rx_axi_awlen    =  u_extd_wr_o_tx_axi_awlen  ;
assign u_wch_i_rx_axi_awuser   =  u_extd_wr_o_tx_axi_awuser ;
assign u_wch_i_rx_axi_awvalid  =  u_extd_wr_o_tx_axi_awvalid;
assign u_wch_i_rx_axi_wdata    =  u_extd_wr_o_tx_axi_wdata  ;
assign u_wch_i_rx_axi_wstrb    =  u_extd_wr_o_tx_axi_wstrb  ;
assign u_wch_i_rx_axi_wlast    =  u_extd_wr_o_tx_axi_wlast  ;
assign u_wch_i_rx_axi_wvalid   =  u_extd_wr_o_tx_axi_wvalid ;
assign u_wch_i_rx_axi_bready   =  u_extd_wr_o_tx_axi_bready ;
com_axi_wch #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .WCH                            ( WCH                           ), //4
    .MAX_OSD                        ( MAX_OSD                       ), //16
    .MAX_LEN                        ( MAX_LEN                       )  //4
)u1_com_axi_wch(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( clear                ), //i
    .o_sta_clr_ongoing   ( o_sta_wch_clr_ongoing      ), //o
    .i_rx_axi_awaddr     ( u_wch_i_rx_axi_awaddr      ), //i
    .i_rx_axi_awlen      ( u_wch_i_rx_axi_awlen       ), //i
    .i_rx_axi_awuser     ( u_wch_i_rx_axi_awuser      ), //i
    .i_rx_axi_awvalid    ( u_wch_i_rx_axi_awvalid     ), //i
    .o_rx_axi_awready    ( u_wch_o_rx_axi_awready     ), //o
    .i_rx_axi_wdata      ( u_wch_i_rx_axi_wdata       ), //i
    .i_rx_axi_wstrb      ( u_wch_i_rx_axi_wstrb       ), //i
    .i_rx_axi_wlast      ( u_wch_i_rx_axi_wlast       ), //i
    .i_rx_axi_wvalid     ( u_wch_i_rx_axi_wvalid      ), //i
    .o_rx_axi_wready     ( u_wch_o_rx_axi_wready      ), //o
    .o_rx_axi_bresp      ( u_wch_o_rx_axi_bresp       ), //o
    .o_rx_axi_bvalid     ( u_wch_o_rx_axi_bvalid      ), //o
    .i_rx_axi_bready     ( u_wch_i_rx_axi_bready      ), //i
    .o_tx_axi_awid       ( o_tx_axi_awid              ), //o
    .o_tx_axi_awaddr     ( o_tx_axi_awaddr            ), //o
    .o_tx_axi_awlen      ( o_tx_axi_awlen             ), //o
    .o_tx_axi_awuser     ( o_tx_axi_awuser            ), //o
    .o_tx_axi_awvalid    ( o_tx_axi_awvalid           ), //o
    .i_tx_axi_awready    ( i_tx_axi_awready           ), //i
    .o_tx_axi_wdata      ( o_tx_axi_wdata             ), //o
    .o_tx_axi_wstrb      ( o_tx_axi_wstrb             ), //o
    .o_tx_axi_wlast      ( o_tx_axi_wlast             ), //o
    .o_tx_axi_wvalid     ( o_tx_axi_wvalid            ), //o
    .i_tx_axi_wready     ( i_tx_axi_wready            ), //i
    .i_tx_axi_bresp      ( i_tx_axi_bresp             ), //i
    .i_tx_axi_bid        ( i_tx_axi_bid               ), //i
    .i_tx_axi_bvalid     ( i_tx_axi_bvalid            ), //i
    .o_tx_axi_bready     ( o_tx_axi_bready            )  //o
);


//2. read channel---
assign u_extd_rd_i_tx_axi_arready = u_rch_o_rx_axi_arready ;
assign u_extd_rd_i_tx_axi_rresp   = u_rch_o_rx_axi_rresp   ;
assign u_extd_rd_i_tx_axi_rdata   = u_rch_o_rx_axi_rdata   ;
assign u_extd_rd_i_tx_axi_rlast   = u_rch_o_rx_axi_rlast   ;
assign u_extd_rd_i_tx_axi_rvalid  = u_rch_o_rx_axi_rvalid  ;
generate
for( genvar gi=0; gi<RCH; gi++ )begin:gen_rch
    localparam BUF_DEPTH      = RCH_BUF_DEPTH[gi]; //range=[0::2],  fifo_ram //if BUF_DEPTH=0, axi_osd=MAX_OSD; if BUF_DEPTH>0, "to confirm rd_bus perfomance, only rd_buffer remain space then send rd_cmd to axi_bus", axi_osd=min(MAX_OSD, BUF_DEPTH/max_burst_len), and assert(BUF_DEPTH>max_burst_len)
    localparam RAM_FIFO_DEPTH = BUF_DEPTH>RCH_MAX_REG_FIFO_DEPTH ? BUF_DEPTH-RCH_MAX_REG_FIFO_DEPTH  : 0;
    localparam RAM_ONE_DEPTH  = RAM_FIFO_DEPTH/2;
    localparam RAM_ONE_AW     = $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2);
    localparam RAM_DW         = DW + 1 //, //{rlast,rdata}
    wire [1:0]                 u_extd_rd_o_rdfifo_ram_cen     ;
    wire [1:0]                 u_extd_rd_o_rdfifo_ram_we      ;
    wire [1:0][RAM_ONE_AW-1:0] u_extd_rd_o_rdfifo_ram_addr    ;
    wire [1:0][RAM_DW-1:0]     u_extd_rd_o_rdfifo_ram_wr_data ;
    wire [1:0][RAM_DW-1:0]     u_extd_rd_i_rdfifo_ram_rd_data ;
    com_axi_extd_rd #(
        .AW                             ( AW                            ), //32
        .DW                             ( DW                            ), //128
        .EBUS_LW                        ( EBUS_LW                       ), //32
        .LW                             ( LW                            ), //8
        .UW                             ( UW                            ), //1
        .BOUND_BYTES                    ( BOUND_BYTES                   ), //4096
        .MAX_OSD                        ( MAX_OSD                       ), //128
        .MAX_REG_FIFO_DEPTH             ( RCH_MAX_REG_FIFO_DEPTH        ), //16
        .BUF_DEPTH                      ( BUF_DEPTH                     )  //0
    )u2_com_axi_extd_rd(
        .clk                 ( clk                     ), //i
        .rst_n               ( rst_n                   ), //i
        .clear               ( clear                   ), //i
        .i_cfg_max_blen_m1   ( i_cfg_max_blen_m1       ), //i
        .i_cfg_max_rdcmd_osd ( i_cfg_rch_max_rdcmd_osd [gi] ), //i
        .o_sta_rdbuf_wl      ( o_sta_rch_rdbuf_wl      [gi] ), //o
        .o_rdfifo_ram_cen    ( o_rdfifo_ram_cen             ), //o
        .o_rdfifo_ram_we     ( o_rdfifo_ram_we              ), //o
        .o_rdfifo_ram_addr   ( o_rdfifo_ram_addr            ), //o
        .o_rdfifo_ram_wr_data( o_rdfifo_ram_wr_data         ), //o
        .i_rdfifo_ram_rd_data( i_rdfifo_ram_rd_data         ), //i
        .ebus_ra_user        ( i_rx_ebus_ra_user         [gi] ), //i
        .ebus_ra_addr        ( i_rx_ebus_ra_addr         [gi] ), //i
        .ebus_ra_bytelen     ( i_rx_ebus_ra_bytelen      [gi] ), //i
        .ebus_ra_valid       ( i_rx_ebus_ra_valid        [gi] ), //i
        .ebus_ra_ready       ( o_rx_ebus_ra_ready        [gi] ), //o
        .ebus_rd_data        ( o_rx_ebus_rd_data         [gi] ), //o
        .ebus_rd_last        ( o_rx_ebus_rd_last         [gi] ), //o
        .ebus_rd_valid       ( o_rx_ebus_rd_valid        [gi] ), //o
        .ebus_rd_ready       ( i_rx_ebus_rd_ready        [gi] ), //i
        .axi_araddr          ( u_extd_rd_o_tx_axi_araddr [gi] ), //o
        .axi_arlen           ( u_extd_rd_o_tx_axi_arlen  [gi] ), //o
        .axi_aruser          ( u_extd_rd_o_tx_axi_aruser [gi] ), //o
        .axi_arvalid         ( u_extd_rd_o_tx_axi_arvalid[gi] ), //o
        .axi_arready         ( u_extd_rd_i_tx_axi_arready[gi] ), //i
        .axi_rdata           ( u_extd_rd_i_tx_axi_rdata  [gi] ), //i
        .axi_rlast           ( u_extd_rd_i_tx_axi_rlast  [gi] ), //i
        .axi_rvalid          ( u_extd_rd_i_tx_axi_rvalid [gi] ), //i
        .axi_rready          ( u_extd_rd_o_tx_axi_rready [gi] )  //o
    );
    com_spram_cell #(
        .DATA_W     ( RAM_DW        ), //32
        .DEPTH      ( RAM_ONE_DEPTH )//, //512
    )zt_com_spram_cell[1:0]
    (
        .clk                  ( clk                  ), //i
        .mem_cfg              ( mem_cfg              ), //i
        .cen                  ( u_extd_rd_o_rdfifo_ram_cen     ), //i
        .we                   ( u_extd_rd_o_rdfifo_ram_we      ), //i
        .addr                 ( u_extd_rd_o_rdfifo_ram_addr    ), //i
        .din                  ( u_extd_rd_o_rdfifo_ram_wr_data ), //i
        .qout                 ( u_extd_rd_i_rdfifo_ram_rd_data )  //o
    );
end:gen_rch
endgenerate

assign u_rch_i_rx_axi_araddr   = u_extd_rd_o_tx_axi_araddr ;
assign u_rch_i_rx_axi_arlen    = u_extd_rd_o_tx_axi_arlen  ;
assign u_rch_i_rx_axi_aruser   = u_extd_rd_o_tx_axi_aruser ;
assign u_rch_i_rx_axi_arvalid  = u_extd_rd_o_tx_axi_arvalid;
assign u_rch_i_rx_axi_rready   = u_extd_rd_o_tx_axi_rready ;
com_axi_rch #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .RCH                            ( RCH                           ), //4
    .MAX_OSD                        ( MAX_OSD                       ), //16
    .MAX_LEN                        ( MAX_LEN                       )  //4
)u2_com_axi_rch(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( clear                ), //i
    .o_sta_clr_ongoing   ( o_sta_rch_clr_ongoing      ), //o
    .i_rx_axi_araddr     ( u_rch_i_rx_axi_araddr      ), //i
    .i_rx_axi_arlen      ( u_rch_i_rx_axi_arlen       ), //i
    .i_rx_axi_aruser     ( u_rch_i_rx_axi_aruser      ), //i
    .i_rx_axi_arvalid    ( u_rch_i_rx_axi_arvalid     ), //i
    .o_rx_axi_arready    ( u_rch_o_rx_axi_arready     ), //o
    .o_rx_axi_rresp      ( u_rch_o_rx_axi_rresp       ), //o
    .o_rx_axi_rdata      ( u_rch_o_rx_axi_rdata       ), //o
    .o_rx_axi_rlast      ( u_rch_o_rx_axi_rlast       ), //o
    .o_rx_axi_rvalid     ( u_rch_o_rx_axi_rvalid      ), //o
    .i_rx_axi_rready     ( u_rch_i_rx_axi_rready      ), //i
    .o_tx_axi_arid       ( o_tx_axi_arid              ), //o
    .o_tx_axi_araddr     ( o_tx_axi_araddr            ), //o
    .o_tx_axi_arlen      ( o_tx_axi_arlen             ), //o
    .o_tx_axi_aruser     ( o_tx_axi_aruser            ), //o
    .o_tx_axi_arvalid    ( o_tx_axi_arvalid           ), //o
    .i_tx_axi_arready    ( i_tx_axi_arready           ), //i
    .i_tx_axi_rresp      ( i_tx_axi_rresp             ), //i
    .i_tx_axi_rid        ( i_tx_axi_rid               ), //i
    .i_tx_axi_rdata      ( i_tx_axi_rdata             ), //i
    .i_tx_axi_rlast      ( i_tx_axi_rlast             ), //i
    .i_tx_axi_rvalid     ( i_tx_axi_rvalid            ), //i
    .o_tx_axi_rready     ( o_tx_axi_rready            )  //o
);


//assert----------------------------------
wire ebus_wa_hs = |(i_rx_ebus_wa_valid & o_rx_ebus_wa_ready);
wire ebus_ra_hs = |(i_rx_ebus_ra_valid & o_rx_ebus_ra_ready);
wire ebus_cmd_hs= ebus_wa_hs||ebus_ra_hs;
`COM_SIGNAL_ASSERT( a1, clk,rst_n,ebus_cmd_hs,(i_cfg_max_blen_m1<MAX_LEN) , "limit to i_cfg_max_blen_m1<MAX_LEN, the i_cfg_max_blen_m1 value illegal" );

endmodule //end of com_axi_dma

