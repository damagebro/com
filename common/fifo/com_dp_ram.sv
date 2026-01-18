/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/06-13:57:57
*
*  Description:
*   common data path ram buffer;
*   -assume the data have already writed to dp_sram,
*   -this module function is: send rd_addr to dp_sram, and deal the rd_data with sync_fifo_reg,
     make ovld and odata output synchronously
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_dp_ram_v
`define com_dp_ram_v
module com_dp_ram #( parameter
    AW   = 8,
    DW   = 8,
    DEPTH= 2,
    RX_RDY_REG_OUT = 0//,  if RX_RDY_REG_OUT=1, o_rx_rdy is reg_out, and DEPTH need more 1;
)(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [AW-1:0]            i_rx_addr           ,
input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,  //if RX_RDY_REG_OUT=0, timing effecy by i_tx_rdy;
output wire [DW-1:0]            o_tx_data           ,
output wire                     o_tx_vld            ,
input  wire                     i_tx_rdy            ,

output wire                     ram_rd_vld          ,
input  wire                     ram_rd_rdy          ,
output wire [AW-1:0]            ram_rd_addr         ,
input  wire                     ram_rd_ack          ,
input  wire [DW-1:0]            ram_rd_data         //,
);
//localparam-----------------------------------------------------------------
localparam CW = $clog2(DEPTH+1);
//signal declare-------------------------------------------------------------
wire b_tie_rx_rdy_reg_out = RX_RDY_REG_OUT[0];
//statement------------------------------------------------------------------

wire          wr_en    = ram_rd_ack;
wire [DW-1:0] wr_data  = ram_rd_data;
wire          wr_full  ;
wire          rd_en    ;
wire [DW-1:0] rd_data  ;
wire          rd_empty ;
wire [CW-1:0] wl       ;
com_sync_fifo_reg #(
    .DW         ( DW          ), //8
    .DEPTH      ( DEPTH       )  //4
)r_com_sync_fifo_reg
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wr_en                ), //i
    .wr_data              ( wr_data              ), //i
    .wr_full              ( wr_full              ), //o
    .rd_en                ( rd_en                ), //i
    .rd_data              ( rd_data              ), //o
    .rd_empty             ( rd_empty             ), //o
    .water_level          ( wl                   )  //spyglass disable PartConnPort-ML,W287b //o,
);

reg  [CW-1:0] rc_otf_cnt;
wire ram_rd_hs = ram_rd_vld&&ram_rd_rdy;
wire [CW-1:0] otf_cnt_nxt = rc_otf_cnt + ram_rd_hs - ram_rd_ack;
wire upen = ram_rd_hs || ram_rd_ack;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_otf_cnt <= 'b0;
    else if( clear )
        rc_otf_cnt <= 'b0;
    else if( upen )
        rc_otf_cnt <= otf_cnt_nxt;
end

wire [CW-0:0] wl_t = wl+rd_en;
wire b_rd_avl_flag = b_tie_rx_rdy_reg_out ? wl<rc_otf_cnt : {1'b0,rc_otf_cnt}<wl_t;

//out--
assign ram_rd_vld = i_rx_vld && b_rd_avl_flag;
assign ram_rd_addr= i_rx_addr;
assign o_rx_rdy = ram_rd_rdy && b_rd_avl_flag;

assign o_tx_vld = !rd_empty;
assign o_tx_data= rd_data;
assign rd_en= o_tx_vld&&i_tx_rdy;

endmodule //end of com_dp_ram
`endif //end of com_dp_ram_v

