/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/03/29-22:17:07
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_bus_unpack_v
`define com_img_bus_unpack_v
module com_img_bus_unpack #( parameter
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
input  wire [XW-1:0]            pic_width_m1        ,
input  wire [XW-1:0]            cut_width_m1        ,
input  wire [XW-1:0]            cut_xpos_s          ,
input  wire                     cut_cfg_en          ,
output wire                     cut_idle            ,
//dp---
input  wire [BUS_DW-1:0]        bus_rd_data         ,
input  wire                     bus_rd_valid        ,
output wire                     bus_rd_ready        ,

output wire                     pixel_last          , //cut line last pixel
output wire [PXL_N-1:0][PW-1:0] pixel_data          ,
output wire                     pixel_valid         ,
input  wire                     pixel_ready         //,
);
//localparam-----------------------------------------------------------------
localparam BUS_DW_L2 = $clog2(BUS_DW);

`COM_PARAM_ASSERT( ($clog2(BUS_DW)!=$clog2(BUS_DW+1)) && BUS_DW>=32, "BUS_DW must be 2^n && BUS_DW>=32" );
`COM_PARAM_ASSERT( PW*PXL_N<BUS_DW, "PW*PXL_N must less than BUS_DW" );
//reg  declare---------------------------------------------------------------
reg  rc_idle;
reg  [XW-1:0] rc_cut_xcnt;
reg  [BUS_DW-1:0] rc_bus_data;
reg  [BUS_DW_L2-1:0] rc_bit_pos;

reg  [PXL_N-1:0][PW-1:0] arc_out_buf;
reg  rc_out_flag;
//wire declare---------------------------------------------------------------
wire [BUS_DW_L2-1:0] once_bitlen = pixel_bitlen*PXL_N;
wire b_bus_rcv_avl_flag;
//statement------------------------------------------------------------------

wire bus_hs = bus_rd_valid && bus_rd_ready;
wire pixel_hs = pixel_valid && pixel_ready;

reg  [XW-1:0] rc_cut_width_m1;
reg  [XW-1:0] rc_cut_xpos_s;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_cut_width_m1 <= 'b0;
        rc_cut_xpos_s   <= 'b0;
    end
    else if( cut_cfg_en )begin
        rc_cut_width_m1 <= cut_width_m1;
        rc_cut_xpos_s   <= cut_xpos_s  ;
    end
end

//bus unpacked---
wire out_buf_ihs;
wire out_buf_last;
reg  rc_bus_vld_flag;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_vld_flag <= 1'b0;
    else if( clear || cut_cfg_en || out_buf_ihs&&out_buf_last )
        rc_bus_vld_flag <= 1'b0;
    else if( bus_hs )
        rc_bus_vld_flag <= 1'b1;
end
wire bus_dec_vld = b_bus_rcv_avl_flag&&!out_buf_last ? bus_rd_valid : rc_bus_vld_flag;
assign bus_rd_ready = b_bus_rcv_avl_flag&&!out_buf_last ? pixel_ready : !rc_bus_vld_flag;
assign out_buf_ihs = bus_dec_vld && pixel_ready;

wire [XW-1:0] cut_xpos_s_use = cut_cfg_en ? cut_xpos_s : rc_cut_xpos_s;
wire [BUS_DW_L2-1:0] cut_xpos_s_use_lo = cut_xpos_s_use + BUS_DW_L2'(0);
wire [BUS_DW_L2-1:0] bit_pos_start = cut_xpos_s_use_lo*pixel_bitlen;
wire [BUS_DW_L2-0:0] bit_pos_nxt_t = rc_bit_pos+once_bitlen;
wire [BUS_DW_L2-0:0] bit_pos_nxt = b_bus_rcv_avl_flag ? bit_pos_nxt_t-BUS_DW : bit_pos_nxt_t;
assign b_bus_rcv_avl_flag = bit_pos_nxt_t>=BUS_DW;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bit_pos <= 'b0;
    else if( clear )
        rc_bit_pos <= 'b0;
    else if( cut_cfg_en || out_buf_ihs&&out_buf_last )
        rc_bit_pos <= bit_pos_start;
    else if( out_buf_ihs )
        rc_bit_pos <= bit_pos_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_data <= 'b0;
    else if( bus_hs )
        rc_bus_data <= bus_rd_data;
end
wire [BUS_DW+PW*PXL_N-1:0] bus_data_extend = {bus_rd_data[0+:PW*PXL_N],rc_bus_data};
wire [PXL_N*PW-1:0] pxl_unpack_data = bus_data_extend[ rc_bit_pos +:PXL_N*PW ];  //maybe the true bitlen=pixel_bitlen*PXL_N;
wire [PW-1:0] one_pxl_mask = (1<<pixel_bitlen) - 1;
reg  [PXL_N-1:0][PW-1:0] arb_pxl_unpack_data;
reg  [BUS_DW-1:0] rb_shift_bitlen;
reg  [PW-1:0] rb_shift_pxl;
always @*
begin
    for( int i=0; i<PXL_N; i++ )begin
        rb_shift_bitlen = pixel_bitlen*i + BUS_DW'(0);
        rb_shift_pxl = pxl_unpack_data>>(pixel_bitlen*i);
        arb_pxl_unpack_data[i] = rb_shift_pxl & one_pxl_mask;
    end
end

//out buf---
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_out_flag <= 1'b0;
    else if( clear || cut_cfg_en || pixel_hs&&pixel_last )
        rc_out_flag <= 1'b0;
    else if( out_buf_ihs )
        rc_out_flag <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_out_buf <= 'b0;
    else if( out_buf_ihs )
        arc_out_buf <= arb_pxl_unpack_data;
end
wire cut_xcnt_done = out_buf_ihs && out_buf_last;
wire [XW-0:0] cut_xcnt_nxt = rc_cut_xcnt+PXL_N;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_cut_xcnt <= 'b0;
    else if( clear || cut_cfg_en || cut_xcnt_done )
        rc_cut_xcnt <= 'b0;
    else if( out_buf_ihs )
        rc_cut_xcnt <= cut_xcnt_nxt;
end
assign out_buf_last = cut_xcnt_nxt>{1'b0,rc_cut_width_m1};

reg  rc_out_buf_last;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_out_buf_last <= 'b0;
    else if( out_buf_ihs )
        rc_out_buf_last <= out_buf_last;
end

//idle---
wire ps_bus_fst = bus_hs&&rc_cut_xcnt==XW'(0);
wire ps_pxl_lst = pixel_hs&&pixel_last;
reg  [3:0] rc_bus_cnt_rnd;
reg  [3:0] rc_pxl_cnt_rnd;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_bus_cnt_rnd <= 'b0;
        rc_pxl_cnt_rnd <= 'b0;
    end
    else if( clear || cut_cfg_en )begin
        rc_bus_cnt_rnd <= 'b0;
        rc_pxl_cnt_rnd <= 'b0;
    end
    else begin
        if( ps_bus_fst ) rc_bus_cnt_rnd <= rc_bus_cnt_rnd+1'b1;
        if( ps_pxl_lst ) rc_pxl_cnt_rnd <= rc_pxl_cnt_rnd+1'b1;
    end
end
wire [3:0] bus_cnt_rnd_tmp = rc_bus_cnt_rnd+ps_bus_fst;
wire [3:0] pxl_cnt_rnd_nxt = rc_pxl_cnt_rnd+1'b1;
wire ps_dec_done = ps_pxl_lst && pxl_cnt_rnd_nxt==bus_cnt_rnd_tmp && !rc_idle;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_idle <= 1'b1;
    else if( clear )
        rc_idle <= 1'b1;
    else if( cut_cfg_en )
        rc_idle <= 1'b0;
    else if( ps_dec_done )
        rc_idle <= 1'b1;
end
assign cut_idle = rc_idle;

//out--
assign pixel_last = rc_out_buf_last && pixel_valid;
assign pixel_data = arc_out_buf;
assign pixel_valid = rc_out_flag;

endmodule //end of com_img_bus_unpack
`endif //end of com_img_bus_unpack_v

