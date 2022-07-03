/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/18-09:42:49
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_wch_cascade_v
`define com_emi_wch_cascade_v
module com_emi_wch_cascade #( parameter
    AW      = 32        , //emi bus addr bit_width
    DW      = 128       , //emi bus data bit_width
    WCH     = 4         , //number of write channel
    MAX_WCH = 16        , //number of max write channels
    MAX_OSD = 16        , //number of max outstanding
    MAX_LEN = 16        , //number of max burst len
    USR_W   = 0         , //emi bus user signal bit_width, typical value=0; maybe used by cache control, and any DIY functions
    BOUND_BYTES = 4096  , //4k boundary split required by interleave dram bank; modify this value must be 2^n, typical value is (512, 1024, 2048, 4096)

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_WCH) ,

    RAM_DEPTH = 0, //write channel data ram depth, typical value is MAX_OSD*MAX_LEN,  available vaule is [0,MAX_OSD*MAX_LEN] \
                   //when RAM_DEPTH==0, the spram_if(cen,we..) don't need connect to sram;
    RAM_ONE_DEPTH = RAM_DEPTH/2,
    RAM_ONE_AW= $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2),
    RAM_DW    = USR_W + SW + DW//, //{user,strb,data}
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg&status---
input  wire [7:0]               max_burst_len       ,
output wire                     clr_ongoing         ,
//sram_if---
output wire [1:0]                 emi_wch_ram_cen   ,
output wire [1:0]                 emi_wch_ram_we    ,
output wire [1:0][RAM_ONE_AW-1:0] emi_wch_ram_addr  ,
output wire [1:0][RAM_DW-1:0]     emi_wch_ram_din   ,
input  wire [1:0][RAM_DW-1:0]     emi_wch_ram_qout  ,
//dp---
com_emi_if.usr_wch_rx           usr_emi_ifs[WCH-1:0],
com_emi_if.usr_wch_tx           usr_emi_ifm         //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

//arb---
wire          arb_awvalid    ;
wire          arb_awready    ;
wire [IW-1:0] arb_awid       ;
wire [AW-1:0] arb_awaddr     ;
wire [7:0]    arb_awlen      ;
wire [UW-1:0] arb_awuser     ;
wire          arb_wvalid     ;
wire          arb_wready     ;
wire [IW-1:0] arb_wid        ;
wire [DW-1:0] arb_wdata      ;
wire [SW-1:0] arb_wstrb      ;
wire          arb_wlast      ;
wire [UW-1:0] arb_wuser      ;
wire          arb_bvalid     ;
wire          arb_bready     ;
wire [IW-1:0] arb_bid        ;
wire [UW-1:0] arb_buser      ;
com_emi_wch_arb #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .WCH        ( WCH        ), //4
    .MAX_WCH    ( MAX_WCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      )  //0
)u_com_emi_wch_arb
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .usr_emi_ifs          ( usr_emi_ifs          ), //if

    .tx_awvalid           ( arb_awvalid          ), //o
    .tx_awready           ( arb_awready          ), //i
    .tx_awid              ( arb_awid             ), //o
    .tx_awaddr            ( arb_awaddr           ), //o
    .tx_awlen             ( arb_awlen            ), //o
    .tx_awuser            ( arb_awuser           ), //o

    .tx_wvalid            ( arb_wvalid           ), //o
    .tx_wready            ( arb_wready           ), //i
    .tx_wid               ( arb_wid              ), //o
    .tx_wdata             ( arb_wdata            ), //o
    .tx_wstrb             ( arb_wstrb            ), //o
    .tx_wlast             ( arb_wlast            ), //o
    .tx_wuser             ( arb_wuser            ), //o

    .tx_bvalid            ( arb_bvalid           ), //i
    .tx_bready            ( arb_bready           ), //o
    .tx_bid               ( arb_bid              ), //i
    .tx_buser             ( arb_buser            )  //i
);

//split&dp_ram---
//dp-
wire          dp_rx_wvalid    = arb_wvalid;
wire          dp_rx_wready    ;
wire [IW-1:0] dp_rx_wid       = IW'(0); //not implement wid;
wire [DW-1:0] dp_rx_wdata     = arb_wdata;
wire [SW-1:0] dp_rx_wstrb     = arb_wstrb;
wire          dp_rx_wlast     = arb_wlast;
wire [UW-1:0] dp_rx_wuser     = arb_wuser;

wire          dp_tx_wvalid    ;
wire          dp_tx_wready    ;
wire [IW-1:0] dp_tx_wid       = IW'(0);
wire [DW-1:0] dp_tx_wdata     ;
wire [SW-1:0] dp_tx_wstrb     ;
wire          dp_tx_wlast     ;
wire [UW-1:0] dp_tx_wuser     ;

wire              dp_wr_en    = dp_rx_wvalid && dp_rx_wready;
wire [RAM_DW-1:0] dp_wr_data  ;
wire              dp_wr_full  ;
wire              dp_rd_en    = dp_tx_wvalid && dp_tx_wready;
wire [RAM_DW-1:0] dp_rd_data  ;
wire              dp_rd_empty ;
com_sync_fifo_ram_1p2bank #(
    .DW         ( RAM_DW     ), //8
    .RAM_DEPTH  ( RAM_DEPTH  )//, //4
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

    .ram_cen              ( emi_wch_ram_cen      ), //o
    .ram_we               ( emi_wch_ram_we       ), //o
    .ram_addr             ( emi_wch_ram_addr     ), //o
    .ram_din              ( emi_wch_ram_din      ), //o
    .ram_qout             ( emi_wch_ram_qout     )  //i
);
assign dp_tx_wvalid = !dp_rd_empty;
assign dp_rx_wready = !dp_wr_full;
assign arb_wready = dp_rx_wready;

generate
  if( USR_W==0 ) begin:gen_no_usr
      assign dp_wr_data = {dp_rx_wstrb,dp_rx_wdata};
      assign {dp_tx_wstrb,dp_tx_wdata} = dp_rd_data;
      assign dp_tx_wuser = UW'(0);
  end
  else begin:gen_with_usr
      assign dp_wr_data = {dp_rx_wuser,dp_rx_wstrb,dp_rx_wdata};
      assign {dp_tx_wuser,dp_tx_wstrb,dp_tx_wdata} = dp_rd_data;
  end
endgenerate

//split-
wire          split_awvalid;
wire          split_awready;
wire [IW-1:0] split_awid   ;
wire [AW-1:0] split_awaddr ;
wire [7:0]    split_awlen  ;
wire [UW-1:0] split_awuser ;
wire          split_bvalid ;
wire          split_bready ;
com_emi_wch_split #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .WCH        ( WCH        ), //4
    .MAX_WCH    ( MAX_WCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      ), //0
    .BOUND_BYTES ( BOUND_BYTES )//, //4096
)u_com_emi_wch_split
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg---
    .max_burst_len        ( max_burst_len        ), //i
    //dp---
    .rx_awvalid           ( arb_awvalid          ), //i
    .rx_awready           ( arb_awready          ), //o
    .rx_awid              ( arb_awid             ), //i
    .rx_awaddr            ( arb_awaddr           ), //i
    .rx_awlen             ( arb_awlen            ), //i
    .rx_awuser            ( arb_awuser           ), //i

    // .rx_wvalid            ( dp_rx_wvalid         ), //i
    // .rx_wready            ( dp_rx_wready         ), //i
    // .rx_wlast             ( dp_rx_wlast          ), //i

    .rx_bvalid            ( arb_bvalid           ), //o
    .rx_bready            ( arb_bready           ), //i

    .tx_awvalid           ( split_awvalid        ), //o
    .tx_awready           ( split_awready        ), //i
    .tx_awid              ( split_awid           ), //o
    .tx_awaddr            ( split_awaddr         ), //o
    .tx_awlen             ( split_awlen          ), //o
    .tx_awuser            ( split_awuser         ), //o

    .tx_wvalid            ( dp_tx_wvalid         ), //i
    .tx_wready            ( dp_tx_wready         ), //i
    .tx_wlast             ( dp_tx_wlast          ), //o

    .tx_bvalid            ( split_bvalid         ), //i
    .tx_bready            ( split_bready         )//, //o
);

//ext---
com_emi_wch_ext2usr #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .MAX_WCH    ( MAX_WCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      )  //0
)u_com_emi_wch_ext2usr
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i, cascaded externel path can be reset by clear;
    //dp---
    .rx_awvalid           ( split_awvalid        ), //i
    .rx_awready           ( split_awready        ), //o
    .rx_awid              ( split_awid           ), //i
    .rx_awaddr            ( split_awaddr         ), //i
    .rx_awlen             ( split_awlen          ), //i
    .rx_awuser            ( split_awuser         ), //i

    .rx_wvalid            ( dp_tx_wvalid         ), //i
    .rx_wready            ( dp_tx_wready         ), //o
    .rx_wid               ( dp_tx_wid            ), //i
    .rx_wdata             ( dp_tx_wdata          ), //i
    .rx_wstrb             ( dp_tx_wstrb          ), //i
    .rx_wlast             ( dp_tx_wlast          ), //i
    .rx_wuser             ( dp_tx_wuser          ), //i

    .rx_bvalid            ( split_bvalid         ), //o
    .rx_bready            ( split_bready         ), //i
    .rx_bid               ( arb_bid              ), //o
    .rx_buser             ( arb_buser            ), //o

    .usr_emi_ifm          ( usr_emi_ifm          )  //if
);

endmodule //end of com_emi_wch_cascade
`endif //end of com_emi_wch_cascade_v

