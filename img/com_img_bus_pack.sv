/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/03/29-22:16:57
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_bus_pack_v
`define com_img_bus_pack_v
module com_img_bus_pack #( parameter
    XW = 12      ,
    PW = 8       , //[1:16]
    PXL_N = 1    , //[1:4]  //PW*PXL_N<BUS_DW
    BUS_DW = 128 //, //[32:1024:2^n]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg&status---
input  wire [4:0]               pixel_bitlen        ,
//dp---
input  wire                     pixel_start         ,
input  wire                     pixel_last          ,
input  wire [PXL_N-1:0][PW-1:0] pixel_data          ,
input  wire                     pixel_valid         ,
output wire                     pixel_ready         ,

output wire [BUS_DW-1:0]        bus_wd_data         ,
output wire                     bus_wd_valid        ,
input  wire                     bus_wd_ready        //,
);
//localparam-----------------------------------------------------------------
localparam BUS_DW_L2 = $clog2(BUS_DW);

`COM_PARAM_ASSERT( ($clog2(BUS_DW)!=$clog2(BUS_DW+1)) && BUS_DW>=32, "BUS_DW must be 2^n && BUS_DW>=32" );
`COM_PARAM_ASSERT( PW*PXL_N<BUS_DW, "PW*PXL_N must less than BUS_DW" );
//reg  declare---------------------------------------------------------------
reg  [BUS_DW-1:0] rc_bus_data;
reg  [BUS_DW_L2-1:0] rc_bit_pos;
//wire declare---------------------------------------------------------------
wire [BUS_DW_L2-1:0] once_bitlen = pixel_bitlen*PXL_N;
wire b_out_avl_flag;
//statement------------------------------------------------------------------

wire pixel_hs = pixel_valid && pixel_ready;
wire bus_hs = bus_wd_valid && bus_wd_ready;

wire [BUS_DW_L2-0:0] bit_pos_nxt_t = rc_bit_pos+once_bitlen;
wire [BUS_DW_L2-0:0] bit_pos_nxt = b_out_avl_flag ? bit_pos_nxt_t-BUS_DW : bit_pos_nxt_t;
assign b_out_avl_flag = bit_pos_nxt_t>=BUS_DW;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bit_pos <= 'b0;
    else if( clear || pixel_start || pixel_hs&&pixel_last )
        rc_bit_pos <= 'b0;
    else if( pixel_hs )
        rc_bit_pos <= bit_pos_nxt;
end

wire [BUS_DW-1:0] bus_data_mask = (1<<rc_bit_pos)-1;
wire [BUS_DW-1:0] bus_data_avl = rc_bus_data & bus_data_mask;
wire [BUS_DW+PW*PXL_N-1:0] bus_data_avl_t = {(PW*PXL_N)'(0),bus_data_avl};
wire [BUS_DW+PW*PXL_N-1:0] bus_data_append = pixel_data<<rc_bit_pos;
wire [BUS_DW+PW*PXL_N-1:0] bus_data_extend = bus_data_avl_t | bus_data_append;
wire [BUS_DW-1:0] bus_data_ovf = bus_data_extend[BUS_DW +:PW*PXL_N] + BUS_DW'(0);
wire [BUS_DW-1:0] bus_data_nxt = b_out_avl_flag ? bus_data_ovf : bus_data_extend[BUS_DW-1:0];
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_data <= 'b0;
    else if( clear || pixel_start || pixel_hs&&pixel_last )
        rc_bus_data <= 'b0;
    else if( pixel_hs )
        rc_bus_data <= bus_data_nxt;
end

//out---
assign bus_wd_valid = b_out_avl_flag || pixel_valid&&pixel_last;
assign bus_wd_data  = bus_data_extend[BUS_DW-1:0];
assign pixel_ready  = bus_wd_valid ? bus_wd_ready : 1'b1;

endmodule //end of com_img_bus_pack
`endif //end of com_img_bus_pack_v

