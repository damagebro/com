/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/18-09:42:38
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_wch_v
`define com_emi_wch_v
module com_emi_wch #( parameter
    AW      = 32        ,
    DW      = 128       ,
    WCH     = 4         ,
    MAX_WCH = 16        ,
    MAX_OSD = 16        ,
    MAX_LEN = 16        ,
    USR_W   = 0         ,
    BOUND_BYTES = 4096  ,
    STR_LOG_PREFIX = "" ,

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_WCH) ,

    RAM_DEPTH = MAX_OSD*MAX_LEN,
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
com_emi_if.ext_wch_tx           ext_emi_ifm         //,
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
// wire          dp_tx_wlast     ;
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
wire          split_wvalid ;
wire          split_wready ;
wire          split_wlast  ;
wire          split_bvalid ;
wire          split_bready ;
wire [IW-1:0] split_bid    ;
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

    .rx_wvalid            ( dp_rx_wvalid         ), //i
    .rx_wready            ( dp_rx_wready         ), //i
    .rx_wlast             ( dp_rx_wlast          ), //i

    .rx_bvalid            ( arb_bvalid           ), //o
    .rx_bready            ( arb_bready           ), //i
    .rx_bid               ( arb_bid              ), //o

    .tx_awvalid           ( split_awvalid        ), //o
    .tx_awready           ( split_awready        ), //i
    .tx_awid              ( split_awid           ), //o
    .tx_awaddr            ( split_awaddr         ), //o
    .tx_awlen             ( split_awlen          ), //o
    .tx_awuser            ( split_awuser         ), //o

    .tx_wvalid_i          ( dp_tx_wvalid         ), //i
    .tx_wready_i          ( dp_tx_wready         ), //o
    .tx_wvalid            ( split_wvalid         ), //o
    .tx_wready            ( split_wready         ), //i
    .tx_wlast             ( split_wlast          ), //o

    .tx_bvalid            ( split_bvalid         ), //i
    .tx_bready            ( split_bready         ), //o
    .tx_bid               ( split_bid            )//, //i
);

//clr---
reg  clear_d;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        clear_d <= 1'b0;
    else
        clear_d <= clear;
end
wire ps_emi_terminate = clear==1'b1 && clear_d==1'b0;//pulse signal,  posedge pulse;

wire clr_awvalid ;
wire clr_awready ;
wire clr_wvalid  ;
wire clr_wready  ;
wire clr_wlast   ;
wire clr_bvalid  ;
wire clr_bready  ;
com_emi_wch_clr #(
    .MAX_OSD    ( MAX_OSD    )  //16
)u_com_emi_wch_clr
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .ps_emi_terminate     ( ps_emi_terminate     ), //i
    //cfg&status---
    .clr_ongoing          ( clr_ongoing          ), //o
    //dp---
    .rx_awvalid           ( split_awvalid        ), //i
    .rx_awready           ( split_awready        ), //o
    .rx_awlen             ( split_awlen          ), //i
    .rx_wvalid            ( split_wvalid         ), //i
    .rx_wready            ( split_wready         ), //o
    .rx_wlast             ( split_wlast          ), //i
    .rx_bvalid            ( split_bvalid         ), //o
    .rx_bready            ( split_bready         ), //i

    .tx_awvalid           ( clr_awvalid          ), //o
    .tx_awready           ( clr_awready          ), //i
    .tx_wvalid            ( clr_wvalid           ), //o
    .tx_wready            ( clr_wready           ), //i
    .tx_wlast             ( clr_wlast            ), //o
    .tx_bvalid            ( clr_bvalid           ), //i
    .tx_bready            ( clr_bready           )  //o
);

//ext---
com_emi_wch_ext #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .MAX_WCH    ( MAX_WCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      )  //0
)u_com_emi_wch_ext
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( 1'b0                 ), //i, externel path can't be reset by clear;
    //dp---
    .rx_awvalid           ( clr_awvalid          ), //i
    .rx_awready           ( clr_awready          ), //o
    .rx_awid              ( split_awid           ), //i
    .rx_awaddr            ( split_awaddr         ), //i
    .rx_awlen             ( split_awlen          ), //i
    .rx_awuser            ( split_awuser         ), //i

    .rx_wvalid            ( clr_wvalid           ), //i
    .rx_wready            ( clr_wready           ), //o
    .rx_wid               ( dp_tx_wid            ), //i
    .rx_wdata             ( dp_tx_wdata          ), //i
    .rx_wstrb             ( dp_tx_wstrb          ), //i
    .rx_wlast             ( clr_wlast            ), //i
    .rx_wuser             ( dp_tx_wuser          ), //i

    .rx_bvalid            ( clr_bvalid           ), //o
    .rx_bready            ( clr_bready           ), //i
    .rx_bid               ( split_bid            ), //o
    .rx_buser             ( arb_buser            ), //o

    .ext_emi_ifm          ( ext_emi_ifm          )  //if
);

//dbg---
com_emi_wch_dbg #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .MAX_WCH    ( MAX_WCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      ), //0
    .STR_LOG_PREFIX ( STR_LOG_PREFIX )//, //""
)u_com_emi_wch_dbg
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( 1'b0                 ), //i

    .awvalid              ( ext_emi_ifm.emi_awvalid ), //i
    .awready              ( ext_emi_ifm.emi_awready ), //i
    .awid                 ( ext_emi_ifm.emi_awid    ), //i
    .awaddr               ( ext_emi_ifm.emi_awaddr  ), //i
    .awlen                ( ext_emi_ifm.emi_awlen   ), //i

    .wvalid               ( ext_emi_ifm.emi_wvalid  ), //i
    .wready               ( ext_emi_ifm.emi_wready  ), //i
    .wdata                ( ext_emi_ifm.emi_wdata   ), //i
    .wlast                ( ext_emi_ifm.emi_wlast   ), //i

    .bvalid               ( ext_emi_ifm.emi_bvalid  ), //i
    .bready               ( ext_emi_ifm.emi_bready  ), //i
    .bid                  ( ext_emi_ifm.emi_bid     )  //i
);

//perf---
com_emi_wch_perf #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .MAX_WCH    ( MAX_WCH    ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .USR_W      ( USR_W      ), //0
    .STR_LOG_PREFIX ( STR_LOG_PREFIX )//, //""
)u_com_emi_wch_perf
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    //cfg&status---
    .sw_stat_enable       ( 1'b0                 ), //i
    .sw_stat_start        ( 1'b0                 ), //i
    .sw_stat_done         ( 1'b0                 ), //i
    .sw_stat_clear        ( 1'b0                 ), //i
    .sw_stat_bw_period    ( 32'b0                ), //i
    //dp---
    .awvalid              ( ext_emi_ifm.emi_awvalid ), //i
    .awready              ( ext_emi_ifm.emi_awready ), //i
    .awlen                ( ext_emi_ifm.emi_awlen   ), //i

    .wvalid               ( ext_emi_ifm.emi_wvalid  ), //i
    .wready               ( ext_emi_ifm.emi_wready  ), //i
    .wlast                ( ext_emi_ifm.emi_wlast   )  //i
);

endmodule //end of com_emi_wch
`endif //end of com_emi_wch_v

