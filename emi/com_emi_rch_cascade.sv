/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/16-14:49:00
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_rch_cascade_v
`define com_emi_rch_cascade_v
module com_emi_rch_cascade #( parameter
    AW      = 32        , //emi bus addr bit_width
    DW      = 128       , //emi bus data bit_width
    RCH     = 4         , //number of read channel
    MAX_RCH = 16        , //number of max read channels
    MAX_OSD = 16        , //number of max outstanding
    MAX_LEN = 16        , //number of max burst len
    USR_W   = 0         , //emi bus user signal bit_width, typical value=0; maybe used by cache control, and any DIY functions
    BOUND_BYTES = 4096  , //4k boundary split required by interleave dram bank; modify this value must be 2^n, typical value is (512, 1024, 2048, 4096)

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_RCH) ,

    RAM_DEPTH = 0, //read channel data ram depth, typical value is 0,  available vaule is [0,MAX_OSD*MAX_LEN] \
                   //recommend use the default value, for user send read request, must make sure read data can by received, \
                   //so emi bus don't need storaged read data \
                   //when RAM_DEPTH==0, the spram_if(cen,we..) don't need connect to sram;
    RAM_ONE_DEPTH = RAM_DEPTH/2,
    RAM_ONE_AW= $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2),
    RAM_DW    = USR_W + 1 + IW + DW//, //{user,rlast,rid,data}
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg&status---
input  wire [7:0]               max_burst_len       ,
output wire                     clr_ongoing         ,
//sram_if---
output wire [1:0]                 emi_rch_ram_cen   ,
output wire [1:0]                 emi_rch_ram_we    ,
output wire [1:0][RAM_ONE_AW-1:0] emi_rch_ram_addr  ,
output wire [1:0][RAM_DW-1:0]     emi_rch_ram_din   ,
input  wire [1:0][RAM_DW-1:0]     emi_rch_ram_qout  ,
//dp---
com_emi_if.usr_rch_rx           usr_emi_ifs[RCH-1:0],
com_emi_if.usr_rch_tx           usr_emi_ifm         //,
);
//localparam-----------------------------------------------------------------
localparam RCH_FIFO_DEPTH = RAM_DEPTH;
localparam RCH_FIFO_DW    = USR_W + 1 + IW + DW; //{user,rlast,rid,data}
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

//arb---
wire          arb_arvalid  ;
wire          arb_arready  ;
wire [IW-1:0] arb_arid     ;
wire [AW-1:0] arb_araddr   ;
wire [7:0]    arb_arlen    ;
wire [UW-1:0] arb_aruser   ;
wire          arb_rvalid   ;
wire          arb_rready   ;
wire [IW-1:0] arb_rid      ;
wire [DW-1:0] arb_rdata    ;
wire          arb_rlast    ;
wire [UW-1:0] arb_ruser    ;
com_emi_rch_arb #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .RCH        ( RCH        ), //4
    .MAX_RCH    ( MAX_RCH    ), //16
    .USR_W      ( USR_W      )  //0
)u_com_emi_rch_arb
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .usr_emi_ifs          ( usr_emi_ifs          ), //if

    .tx_arvalid           ( arb_arvalid          ), //o
    .tx_arready           ( arb_arready          ), //i
    .tx_arid              ( arb_arid             ), //o
    .tx_araddr            ( arb_araddr           ), //o
    .tx_arlen             ( arb_arlen            ), //o
    .tx_aruser            ( arb_aruser           ), //o

    .tx_rvalid            ( arb_rvalid           ), //i
    .tx_rready            ( arb_rready           ), //o
    .tx_rid               ( arb_rid              ), //i
    .tx_rdata             ( arb_rdata            ), //i
    .tx_rlast             ( arb_rlast            ), //i
    .tx_ruser             ( arb_ruser            )  //i
);

//split&dp_fifo_ram---
//dp fifo ram-
wire           dp_rx_rvalid   ;
wire           dp_rx_rready   ;
wire [IW-1:0]  dp_rx_rid      ;
wire [DW-1:0]  dp_rx_rdata    ;
wire           dp_rx_rlast    ;
wire [UW-1:0]  dp_rx_ruser    ;

wire           dp_tx_rvalid   ;
wire           dp_tx_rready   ;
wire [IW-1:0]  dp_tx_rid      ;
wire [DW-1:0]  dp_tx_rdata    ;
wire           dp_tx_rlast    ;
wire [UW-1:0]  dp_tx_ruser    ;

wire                   dp_wr_en    = dp_rx_rvalid && dp_rx_rready;
wire [RCH_FIFO_DW-1:0] dp_wr_data  ;
wire                   dp_wr_full  ;
wire                   dp_rd_en    = dp_tx_rvalid && dp_tx_rready;
wire [RCH_FIFO_DW-1:0] dp_rd_data  ;
wire                   dp_rd_empty ;
com_sync_fifo_ram_1p2bank #(
    .DW         ( RCH_FIFO_DW     ), //8
    .RAM_DEPTH  ( RCH_FIFO_DEPTH  )//, //4
)r_com_sync_fifo_ram_1p2bank_dp
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( dp_wr_en             ), //i
    .wr_data              ( dp_wr_data           ), //i
    .wr_full              ( dp_wr_full           ), //o
    .rd_en                ( dp_rd_en             ), //i
    .rd_data              ( dp_rd_data           ), //o
    .rd_empty             ( dp_rd_empty          ), //o
    .water_level          (                      ), //o

    .ram_cen              ( emi_rch_ram_cen      ), //o
    .ram_we               ( emi_rch_ram_we       ), //o
    .ram_addr             ( emi_rch_ram_addr     ), //o
    .ram_din              ( emi_rch_ram_din      ), //o
    .ram_qout             ( emi_rch_ram_qout     )  //i
);
assign dp_tx_rvalid = !dp_rd_empty;
assign dp_rx_rready = !dp_wr_full;

assign arb_rvalid = dp_tx_rvalid;
assign arb_rid    = dp_tx_rid   ;
assign arb_rdata  = dp_tx_rdata ;
assign arb_rlast  = dp_tx_rlast ;
assign arb_ruser  = dp_tx_ruser ;
assign dp_tx_rready = arb_rready;

generate
  if( USR_W==0 ) begin:gen_no_usr
      assign dp_wr_data = {dp_rx_rlast,dp_rx_rid,dp_rx_rdata};
      assign {dp_tx_rlast,dp_tx_rid,dp_tx_rdata} = dp_rd_data;
      assign dp_tx_ruser = UW'(0);
  end
  else begin:gen_with_usr
      assign dp_wr_data = {dp_rx_ruser,dp_rx_rlast,dp_rx_rid,dp_rx_rdata};
      assign {dp_tx_ruser,dp_tx_rlast,dp_tx_rid,dp_tx_rdata} = dp_rd_data;
  end
endgenerate

//split-
wire           split_arvalid ;
wire           split_arready ;
wire [IW-1:0]  split_arid    ;
wire [AW-1:0]  split_araddr  ;
wire [7:0]     split_arlen   ;
wire [UW-1:0]  split_aruser  ;
wire           split_rvalid  ;
wire           split_rready  ;
wire [IW-1:0]  split_rid     ;
wire           split_rlast   ;
com_emi_rch_split #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .RCH        ( RCH        ), //4
    .MAX_RCH    ( MAX_RCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      ), //0
    .BOUND_BYTES ( BOUND_BYTES )//, //4096
)u_com_emi_rch_split
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg---
    .max_burst_len        ( max_burst_len        ), //i
    //dp---
    .rx_arvalid           ( arb_arvalid          ), //i
    .rx_arready           ( arb_arready          ), //o
    .rx_arid              ( arb_arid             ), //i
    .rx_araddr            ( arb_araddr           ), //i
    .rx_arlen             ( arb_arlen            ), //i
    .rx_aruser            ( arb_aruser           ), //i

    .rx_rvalid            ( dp_rx_rvalid         ), //o
    .rx_rready            ( dp_rx_rready         ), //i
    .rx_rid               ( dp_rx_rid            ), //o
    .rx_rlast             ( dp_rx_rlast          ), //o

    .tx_arvalid           ( split_arvalid        ), //o
    .tx_arready           ( split_arready        ), //i
    .tx_arid              ( split_arid           ), //o
    .tx_araddr            ( split_araddr         ), //o
    .tx_arlen             ( split_arlen          ), //o
    .tx_aruser            ( split_aruser         ), //o

    .tx_rvalid            ( split_rvalid         ), //i
    .tx_rready            ( split_rready         ), //o
    .tx_rid               ( split_rid            ), //i
    .tx_rlast             ( split_rlast          )  //i
);

//ext---
com_emi_rch_ext2usr #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .MAX_RCH    ( MAX_RCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      )  //0
)u_com_emi_rch_ext2usr
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i, cascaded externel path can be reset by clear;
    //dp---
    .rx_arvalid           ( split_arvalid        ), //i
    .rx_arready           ( split_arready        ), //o
    .rx_arid              ( split_arid           ), //i
    .rx_araddr            ( split_araddr         ), //i
    .rx_arlen             ( split_arlen          ), //i
    .rx_aruser            ( split_aruser         ), //i

    .rx_rvalid            ( split_rvalid         ), //o
    .rx_rready            ( split_rready         ), //i
    .rx_rid               ( split_rid            ), //o
    .rx_rdata             ( dp_rx_rdata          ), //o
    .rx_rlast             ( split_rlast          ), //o
    .rx_ruser             ( dp_rx_ruser          ), //o

    .usr_emi_ifm          ( usr_emi_ifm          )  //if
);

endmodule //end of com_emi_rch_cascade
`endif //end of com_emi_rch_cascade_v

