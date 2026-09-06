/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/17-17:53:13
*
*  Description:
*  - if WA_BEFORE_WD_EN=1, i_rx_axi_wlast unused, recover o_tx_axi_wlast;
*
*  Modify:
*  -
*
******************************************************************************/


module com_axi_wch_regslice #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         , //range=[1:8]
    UW      = 1         ,
    parameter WA_BEFORE_WD_EN = 0,  //if WA_BEFORE_WD_EN=1, i_rx_axi_wlast unused, recover o_tx_axi_wlast;
    localparam SW = DW/8//,
)
(
input  wire clk   ,
input  wire rst_n ,
input  wire clear ,
//dp---
input  wire [IW-1:0]   i_rx_axi_awid    ,
input  wire [AW-1:0]   i_rx_axi_awaddr  ,
input  wire [LW-1:0]   i_rx_axi_awlen   ,
input  wire [UW-1:0]   i_rx_axi_awuser  ,
input  wire            i_rx_axi_awvalid ,
output wire            o_rx_axi_awready ,
input  wire [DW-1:0]   i_rx_axi_wdata   ,
input  wire [DW/8-1:0] i_rx_axi_wstrb   ,
input  wire            i_rx_axi_wlast   ,
input  wire            i_rx_axi_wvalid  ,
output wire            o_rx_axi_wready  ,
output wire [1:0]      o_rx_axi_bresp   ,
output wire [IW-1:0]   o_rx_axi_bid     ,
output wire            o_rx_axi_bvalid  ,
input  wire            i_rx_axi_bready  ,

output wire [IW-1:0]   o_tx_axi_awid    ,
output wire [AW-1:0]   o_tx_axi_awaddr  ,
output wire [LW-1:0]   o_tx_axi_awlen   ,
output wire [UW-1:0]   o_tx_axi_awuser  ,
output wire            o_tx_axi_awvalid ,
input  wire            i_tx_axi_awready ,
output wire [DW-1:0]   o_tx_axi_wdata   ,
output wire [DW/8-1:0] o_tx_axi_wstrb   ,
output wire            o_tx_axi_wlast   ,
output wire            o_tx_axi_wvalid  ,
input  wire            i_tx_axi_wready  ,
input  wire [1:0]      i_tx_axi_bresp   ,
input  wire [IW-1:0]   i_tx_axi_bid     ,
input  wire            i_tx_axi_bvalid  ,
output wire            o_tx_axi_bready   //,
);
//localparam-----------------------------------------------------------------
localparam WA_FIFO_DW = UW + LW + IW + AW   ; //{awuser,alen,awid,addr}
localparam WD_FIFO_DW = 1 + SW+DW; //{wlast,strb+data}
localparam WB_FIFO_DW = 2 + IW; //{bresp, bid}

localparam WA_BEFORE_WD_DEPTH = 4;
//signal declare-------------------------------------------------------------
wire  u_wd_tx_wlast           ;
wire  b_wa_before_wd_tx_wlast ;
wire  b_wa_before_wd_fifo_empty ;
wire  b_wa_before_wd_fifo_full  ;
wire  tie_wa_before_wd_enable = WA_BEFORE_WD_EN>0;

wire                   u_wa_i_wr_en    ;
wire  [WA_FIFO_DW-1:0] u_wa_i_wr_data  ;
wire                   u_wa_o_wr_full  ;
wire                   u_wa_i_rd_en    ;
wire  [WA_FIFO_DW-1:0] u_wa_o_rd_data  ;
wire                   u_wa_o_rd_empty ;

wire                   u_wd_i_wr_en    ;
wire  [WD_FIFO_DW-1:0] u_wd_i_wr_data  ;
wire                   u_wd_o_wr_full  ;
wire                   u_wd_i_rd_en    ;
wire  [WD_FIFO_DW-1:0] u_wd_o_rd_data  ;
wire                   u_wd_o_rd_empty ;

wire                   u_wb_i_wr_en    ;
wire  [WB_FIFO_DW-1:0] u_wb_i_wr_data  ;
wire                   u_wb_o_wr_full  ;
wire                   u_wb_i_rd_en    ;
wire  [WB_FIFO_DW-1:0] u_wb_o_rd_data  ;
wire                   u_wb_o_rd_empty ;
//statement------------------------------------------------------------------
//out---
assign {o_tx_axi_awuser,o_tx_axi_awlen,o_tx_axi_awid,o_tx_axi_awaddr} = u_wa_o_rd_data;
assign o_tx_axi_awvalid = !u_wa_o_rd_empty;
assign o_rx_axi_awready = !b_wa_before_wd_fifo_full && !u_wa_o_wr_full;

assign {u_wd_tx_wlast,o_tx_axi_wstrb,o_tx_axi_wdata} = u_wd_o_rd_data;
assign o_tx_axi_wlast  = tie_wa_before_wd_enable ? b_wa_before_wd_tx_wlast : u_wd_tx_wlast;
assign o_tx_axi_wvalid = !b_wa_before_wd_fifo_empty && !u_wd_o_rd_empty;
assign o_rx_axi_wready = !u_wd_o_wr_full;

assign {o_rx_axi_bresp,o_rx_axi_bid} = u_wb_o_rd_data;
assign o_rx_axi_bvalid = !u_wb_o_rd_empty;
assign o_tx_axi_bready = !u_wb_o_wr_full;


//instance--
assign u_wa_i_wr_en   = i_rx_axi_awvalid && o_rx_axi_awready;
assign u_wa_i_wr_data = {i_rx_axi_awuser,i_rx_axi_awlen,i_rx_axi_awid,i_rx_axi_awaddr};
assign u_wa_i_rd_en   = o_tx_axi_awvalid && i_tx_axi_awready;
com_sync_fifo_reg #(
    .DW    ( WA_FIFO_DW ), //8
    .DEPTH ( 2          )  //2
)u_com_sync_fifo_reg_wa
(
    .clk           ( clk                 ), //i
    .rst_n         ( rst_n               ), //i
    .clear         ( clear               ), //i
    .i_wr_en       ( u_wa_i_wr_en        ), //i
    .i_wr_data     ( u_wa_i_wr_data      ), //i
    .o_wr_full     ( u_wa_o_wr_full      ), //o
    .i_rd_en       ( u_wa_i_rd_en        ), //i
    .o_rd_data     ( u_wa_o_rd_data      ), //o
    .o_rd_empty    ( u_wa_o_rd_empty     ), //o
    .o_water_level (                     )  //o
);
assign u_wd_i_wr_en   = i_rx_axi_wvalid && o_rx_axi_wready;
assign u_wd_i_wr_data = {i_rx_axi_wlast,i_rx_axi_wstrb,i_rx_axi_wdata};
assign u_wd_i_rd_en   = o_tx_axi_wvalid && i_tx_axi_wready;
com_sync_fifo_reg #(
    .DW    ( WD_FIFO_DW ), //8
    .DEPTH ( 2          )  //2
)u_com_sync_fifo_reg_wd
(
    .clk           ( clk                 ), //i
    .rst_n         ( rst_n               ), //i
    .clear         ( clear               ), //i
    .i_wr_en       ( u_wd_i_wr_en        ), //i
    .i_wr_data     ( u_wd_i_wr_data      ), //i
    .o_wr_full     ( u_wd_o_wr_full      ), //o
    .i_rd_en       ( u_wd_i_rd_en        ), //i
    .o_rd_data     ( u_wd_o_rd_data      ), //o
    .o_rd_empty    ( u_wd_o_rd_empty     ), //o
    .o_water_level (                     )  //o
);
assign u_wb_i_wr_en   = i_tx_axi_bvalid && o_tx_axi_bready;
assign u_wb_i_wr_data = {i_tx_axi_bresp,i_tx_axi_bid};
assign u_wb_i_rd_en   = o_rx_axi_bvalid && i_rx_axi_bready;
com_sync_fifo_reg #(
    .DW    ( WB_FIFO_DW ), //8
    .DEPTH ( 2          )  //2
)u_com_sync_fifo_reg_wb
(
    .clk           ( clk                 ), //i
    .rst_n         ( rst_n               ), //i
    .clear         ( clear               ), //i
    .i_wr_en       ( u_wb_i_wr_en        ), //i
    .i_wr_data     ( u_wb_i_wr_data      ), //i
    .o_wr_full     ( u_wb_o_wr_full      ), //o
    .i_rd_en       ( u_wb_i_rd_en        ), //i
    .o_rd_data     ( u_wb_o_rd_data      ), //o
    .o_rd_empty    ( u_wb_o_rd_empty     ), //o
    .o_water_level (                     )  //o
);
//
generate
if( WA_BEFORE_WD_EN>0 )begin:gen_wa_before_wd
    wire           u_wa_before_wd_i_wr_en    ;
    wire  [LW-1:0] u_wa_before_wd_i_wr_data  ;
    wire           u_wa_before_wd_o_wr_full  ;
    wire           u_wa_before_wd_i_rd_en    ;
    wire  [LW-1:0] u_wa_before_wd_o_rd_data  ;
    wire           u_wa_before_wd_o_rd_empty ;
    assign b_wa_before_wd_fifo_empty = u_wa_before_wd_o_rd_empty;
    assign b_wa_before_wd_fifo_full  = u_wa_before_wd_o_wr_full;

    reg            r_wa_before_wd_tx_wlast ;
    reg   [LW-1:0] r_wcnt                  ;
    wire [LW-0:0] wcnt_p1 = r_wcnt+1'b1;
    wire b_wcnt_end = wcnt_p1>={1'b0, u_wa_before_wd_o_rd_data};
    wire tx_whs = o_tx_axi_wvalid && i_tx_axi_wready;
    always @(posedge clk or negedge rst_n) begin
        if( !rst_n )
            r_wcnt <= '0;
        else if( tx_whs && o_tx_axi_wlast )
            r_wcnt <= '0;
        else if( tx_whs )
            r_wcnt <= wcnt_p1[LW-1:0];
    end
    always @(posedge clk or negedge rst_n) begin
        if( !rst_n )
            r_wa_before_wd_tx_wlast <= 1'b0;
        else if( tx_whs && o_tx_axi_wlast )
            r_wa_before_wd_tx_wlast <= 1'b0;
        else if( tx_whs && b_wcnt_end )
            r_wa_before_wd_tx_wlast <= 1'b1;
    end
    // This comparison is a timing path; a prefetch FIFO can remove it if needed.
    assign b_wa_before_wd_tx_wlast = u_wa_before_wd_o_rd_data=='0 ? 1'b1 : r_wa_before_wd_tx_wlast;
    assign u_wa_before_wd_i_wr_en   = i_rx_axi_awvalid && o_rx_axi_awready;
    assign u_wa_before_wd_i_wr_data = i_rx_axi_awlen;
    assign u_wa_before_wd_i_rd_en   = tx_whs&&o_tx_axi_wlast;
    com_sync_fifo_reg #(
        .DW    ( LW                 ),   //8
        .DEPTH ( WA_BEFORE_WD_DEPTH )  //4
    )zr_com_sync_fifo_reg_wa_before_wd
    (
        .clk           ( clk                       ),   //i
        .rst_n         ( rst_n                     ),   //i
        .clear         ( clear                     ),   //i
        .i_wr_en       ( u_wa_before_wd_i_wr_en    ),   //i
        .i_wr_data     ( u_wa_before_wd_i_wr_data  ),   //i
        .o_wr_full     ( u_wa_before_wd_o_wr_full  ),   //o
        .i_rd_en       ( u_wa_before_wd_i_rd_en    ),   //i
        .o_rd_data     ( u_wa_before_wd_o_rd_data  ),   //o
        .o_rd_empty    ( u_wa_before_wd_o_rd_empty ),   //o
        .o_water_level (                           )  //o
    );
end:gen_wa_before_wd
else begin
    assign b_wa_before_wd_tx_wlast  = 1'b0;
    assign b_wa_before_wd_fifo_empty = 1'b0;
    assign b_wa_before_wd_fifo_full  = 1'b0;
end
endgenerate

endmodule //end of com_axi_wch_regslice
