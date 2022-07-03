/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/06/22-09:56:27
*
*  Description:
*  -emi to axi request cdc;
*  -data path: arb->cdc->split->clr->ext
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_rch_req_cdc_v
`define com_emi_rch_req_cdc_v
module com_emi_rch_req_cdc #( parameter
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
input  wire [IW-1:0]            rx_arid             ,
input  wire [AW-1:0]            rx_araddr           ,
input  wire [7:0]               rx_arlen            ,
input  wire [UW-1:0]            rx_aruser           ,
input  wire                     rx_arvalid          ,
output wire                     rx_arready          ,

output wire [IW-1:0]            tx_arid             ,
output wire [AW-1:0]            tx_araddr           ,
output wire [7:0]               tx_arlen            ,
output wire [UW-1:0]            tx_aruser           ,
output wire                     tx_arvalid          ,
input  wire                     tx_arready          //,
);
//localparam-----------------------------------------------------------------
localparam FIFO_DEPTH = 6; //[2::2]
localparam FIFO_AW = $clog2(FIFO_DEPTH+1);
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

localparam REQ_DW  = AW+8+IW+USR_W;
wire [FIFO_AW-1:0] req_water_level;
wire               req_wr_en      = rx_arvalid && rx_arready;
wire [REQ_DW-1:0]  req_wr_data    = {rx_arid,rx_arlen,rx_araddr};
wire               req_wr_full    ;
wire               req_rd_en      = tx_arvalid && tx_arready;
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
assign {tx_arid,tx_arlen,tx_araddr} = req_rd_data[ 0 +:AW+8+IW ];
assign tx_arvalid = !req_rd_empty;
assign rx_arready = !req_wr_full;

generate
if( USR_W>0 )begin
    assign req_wr_data[ AW+8+IW +:USR_W ] = rx_aruser;
    assign tx_aruser = req_rd_data[ AW+8+IW +:USR_W ];
end
else begin
    assign tx_aruser = 'b0;
end
endgenerate

endmodule //end of com_emi_rch_req_cdc
`endif //end of com_emi_rch_req_cdc_v

