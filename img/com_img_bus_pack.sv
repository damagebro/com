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
input  wire [XW-1:0]            cut_width_m1        ,
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
`COM_PARAM_ASSERT( PXL_N<=16, "pxl_num only 4bit, so PXL_N<=16" );
`COM_SIGNAL_ASSERT_LITE( a0, pixel_start,pixel_bitlen<=PW, "pixel_bitlen must be less than PW"  );
//reg  declare---------------------------------------------------------------
reg  [BUS_DW-1:0] rc_bus_data;
reg  [BUS_DW_L2-1:0] rc_bit_pos;
reg  [XW-1:0] rc_xcnt;
//wire declare---------------------------------------------------------------
wire [XW-0:0] cut_width = cut_width_m1+1'b1;
wire [3:0] pxl_num;
wire [BUS_DW_L2-1:0] once_bitlen = pxl_num*pixel_bitlen + BUS_DW_L2'(0);
wire b_out_avl_flag;
//statement------------------------------------------------------------------

wire pixel_hs = pixel_valid && pixel_ready;
wire bus_hs = bus_wd_valid && bus_wd_ready;

wire [XW-0:0] xcnt_nxt = rc_xcnt+PXL_N;
assign pxl_num = pixel_last ? (cut_width-rc_xcnt) : PXL_N;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_xcnt <= 'b0;
    else if( clear || pixel_start || pixel_hs&&pixel_last )
        rc_xcnt <= 'b0;
    else if( pixel_hs )
        rc_xcnt <= xcnt_nxt;
end

wire [BUS_DW_L2-0:0] bit_pos_nxt_t = rc_bit_pos+once_bitlen;
wire [BUS_DW_L2-0:0] bit_pos_nxt = b_out_avl_flag ? bit_pos_nxt_t-BUS_DW : bit_pos_nxt_t;
wire b_out_avl_flag_extend = bit_pos_nxt_t>BUS_DW;
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

wire [PW-1:0] one_pxl_mask = (1<<pixel_bitlen) - 1;
reg  [PXL_N*PW-1:0] rb_pxl_pack_data; //maybe the true bitlen=pixel_bitlen*PXL_N;
always @*
begin
    rb_pxl_pack_data = (PXL_N*PW)'(0);
    for( int i=0; i<PXL_N; i++ )begin
        rb_pxl_pack_data[ i*pixel_bitlen +:PW ] = pixel_data[i] & one_pxl_mask;
    end
end

reg  rc_bus_last_extend_flag;
wire [BUS_DW-1:0] bus_data_mask = (1<<rc_bit_pos)-1;
wire [BUS_DW-1:0] bus_data_avl = rc_bus_data & bus_data_mask;
wire [BUS_DW+PW*PXL_N-1:0] bus_data_avl_t = {(PW*PXL_N)'(0),bus_data_avl};
wire [BUS_DW+PW*PXL_N-1:0] bus_data_append = rb_pxl_pack_data<<rc_bit_pos;
wire [BUS_DW+PW*PXL_N-1:0] bus_data_extend = bus_data_avl_t | bus_data_append;
wire [BUS_DW-1:0] bus_data_ovf = bus_data_extend[BUS_DW +:PW*PXL_N] + BUS_DW'(0);
wire [BUS_DW-1:0] bus_data_nxt = b_out_avl_flag ? bus_data_ovf : bus_data_extend[BUS_DW-1:0];
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_data <= 'b0;
    // else if( clear || pixel_start || pixel_hs&&pixel_last&&!b_out_avl_flag_extend || rc_bus_last_extend_flag&&bus_hs  )
    else if( clear || pixel_start )
        rc_bus_data <= 'b0;
    else if( pixel_hs )
        rc_bus_data <= bus_data_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_last_extend_flag <= 1'b0;
    else if( clear || pixel_start )
        rc_bus_last_extend_flag <= 1'b0;
    else if( b_out_avl_flag_extend && pixel_hs&&pixel_last )
        rc_bus_last_extend_flag <= 1'b1;
    else if( rc_bus_last_extend_flag&&bus_hs )
        rc_bus_last_extend_flag <= 1'b0;
end

//out---
assign bus_wd_valid = rc_bus_last_extend_flag || b_out_avl_flag || pixel_valid&&pixel_last;
assign bus_wd_data  = rc_bus_last_extend_flag ? rc_bus_data : bus_data_extend[BUS_DW-1:0];
assign pixel_ready  = rc_bus_last_extend_flag ? 1'b0 : bus_wd_valid ? bus_wd_ready : 1'b1;

endmodule //end of com_img_bus_pack
`endif //end of com_img_bus_pack_v

