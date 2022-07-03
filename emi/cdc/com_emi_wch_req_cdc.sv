/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/06/22-09:56:37
*
*  Description:
*  -emi to axi request cdc;
*  -data path: arb->cdc->split->clr->ext
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_wch_req_cdc_v
`define com_emi_wch_req_cdc_v
module com_emi_wch_req_cdc #( parameter
    AW      = 32        ,
    DW      = 128       ,
    MAX_WCH = 16        ,
    USR_W   = 0         ,

    UW =(USR_W>0?USR_W:1),
    IW = $clog2(MAX_WCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
input  wire                     axi_clk             ,
input  wire                     axi_rst_n           ,
input  wire                     axi_clear           ,
//dp---
input  wire [IW-1:0]            rx_awid             , //emi clk domain
input  wire [AW-1:0]            rx_awaddr           ,
input  wire [7:0]               rx_awlen            ,
input  wire [UW-1:0]            rx_awuser           ,
input  wire                     rx_awvalid          ,
output wire                     rx_awready          ,
output wire [IW-1:0]            rx_bid              ,
output wire [UW-1:0]            rx_buser            ,
output wire                     rx_bvalid           ,
input  wire                     rx_bready           ,

output wire [IW-1:0]            tx_awid             , //axi clk domain
output wire [AW-1:0]            tx_awaddr           ,
output wire [7:0]               tx_awlen            ,
output wire [UW-1:0]            tx_awuser           ,
output wire                     tx_awvalid          ,
input  wire                     tx_awready          ,
input  wire [IW-1:0]            tx_bid              ,
input  wire [UW-1:0]            tx_buser            ,
input  wire                     tx_bvalid           ,
output wire                     tx_bready           //,
);
//localparam-----------------------------------------------------------------
localparam FIFO_DEPTH = 6; //[2::2]
localparam FIFO_AW = $clog2(FIFO_DEPTH+1);
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

localparam REQ_DW  = AW+8+IW+USR_W;
wire [FIFO_AW-1:0] req_water_level;
wire               req_wr_en      = rx_awvalid && rx_awready;
wire [REQ_DW-1:0]  req_wr_data    = {rx_awid,rx_awlen,rx_awaddr};
wire               req_wr_full    ;
wire               req_rd_en      = tx_awvalid && tx_awready;
wire [REQ_DW-1:0]  req_rd_data    ;
wire               req_rd_empty   ;
com_async_fifo_reg #(
    .DW         ( REQ_DW    ), //8
    .DEPTH      ( FIFO_DEPTH )  //4
)u_com_async_fifo_reg_req
(
    .wr_clk               ( clk                  ), //i
    .wr_rst_n             ( rst_n                ), //i
    .wr_clear             ( clear                ), //i
    .rd_clk               ( axi_clk              ), //i
    .rd_rst_n             ( axi_rst_n            ), //i
    .rd_clear             ( axi_clear            ), //i

    .wr_en                ( req_wr_en            ), //i
    .wr_data              ( req_wr_data          ), //i
    .wr_full              ( req_wr_full          ), //o
    .rd_en                ( req_rd_en            ), //i
    .rd_data              ( req_rd_data          ), //o
    .rd_empty             ( req_rd_empty         ), //o
    .water_level          ( req_water_level      )  //o
);
assign {tx_awid,tx_awlen,tx_awaddr} = req_rd_data[ 0 +:AW+8+IW ];
assign tx_awvalid = !req_rd_empty;
assign rx_awready = !req_wr_full;

localparam RSP_DW  = IW + USR_W;
wire [FIFO_AW-1:0] rsp_water_level;
wire               rsp_wr_en      = tx_bvalid && tx_bready;
wire [REQ_DW-1:0]  rsp_wr_data    = {tx_bid};
wire               rsp_wr_full    ;
wire               rsp_rd_en      = rx_bvalid && rx_bready;
wire [REQ_DW-1:0]  rsp_rd_data    ;
wire               rsp_rd_empty   ;
com_async_fifo_reg #(
    .DW         ( REQ_DW    ), //8
    .DEPTH      ( FIFO_DEPTH )  //4
)u_com_async_fifo_reg_rsp
(
    .wr_clk               ( axi_clk              ), //i
    .wr_rst_n             ( axi_rst_n            ), //i
    .wr_clear             ( axi_clear            ), //i
    .rd_clk               ( clk                  ), //i
    .rd_rst_n             ( rst_n                ), //i
    .rd_clear             ( clear                ), //i

    .wr_en                ( rsp_wr_en            ), //i
    .wr_data              ( rsp_wr_data          ), //i
    .wr_full              ( rsp_wr_full          ), //o
    .rd_en                ( rsp_rd_en            ), //i
    .rd_data              ( rsp_rd_data          ), //o
    .rd_empty             ( rsp_rd_empty         ), //o
    .water_level          ( rsp_water_level      )  //o
);
assign {rx_bid} = rsp_rd_data[ 0 +:IW ];
assign rx_bvalid = !rsp_rd_empty;
assign tx_bready = !rsp_wr_full;

generate
if( USR_W>0 )begin
    assign req_wr_data[ AW+8+IW +:USR_W ] = rx_awuser;
    assign tx_awuser = req_rd_data[ AW+8+IW +:USR_W ];
    assign rsp_wr_data[ IW +:USR_W ] = tx_buser;
    assign rx_buser = rsp_rd_data[ IW +:USR_W ];
end
else begin
    assign tx_awuser = 'b0;
    assign rx_buser = 'b0;
end
endgenerate

endmodule //end of com_emi_wch_req_cdc
`endif //end of com_emi_wch_req_cdc_v

