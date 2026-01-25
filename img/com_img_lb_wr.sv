/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/04/22-09:56:02
*
*  Description:
*   constraint bellow:
*   1.only access 1 line_buffer
*   2.wr_lb and rd_lb don't access the same line at the same time
*
*  Modify:
*  -
*
******************************************************************************/

module com_img_lb_wr #( parameter
    XW       = 12  ,
    PW       = 8   ,
    WR_PXL_N = 1   ,
    LB_PXL_N = 8   ,
    LB_DEPTH       ,

    LB_AW = $clog2(LB_DEPTH),
    LB_DW = LB_PXL_N*PW     //,
)
(
input  wire                        clk                 ,
input  wire                        rst_n               ,
input  wire                        clear               ,

input  wire [XW-1:0]               pic_width_m1        ,

input  wire                        in_sof              ,
input  wire                        in_valid            ,
output wire                        in_ready            ,
input  wire [WR_PXL_N-1:0][PW-1:0] in_data             ,
input  wire                        in_last             ,

output wire                        lb_wr_vld           ,
input  wire                        lb_wr_rdy           ,
output wire [LB_AW-1:0]            lb_wr_addr          ,
output wire [LB_DW-1:0]            lb_wr_data          //,
);
//localparam-----------------------------------------------------------------
`COM_PARAM_ASSERT( LB_PXL_N>=1, "LB_PXL_N>=1" ); //spyglass disable W193
`COM_PARAM_ASSERT( WR_PXL_N<=LB_PXL_N, "WR_PXL_N<=LB_PXL_N" ); //spyglass disable W193
localparam LB_PXL_N_L2 = $clog2(LB_PXL_N);
//reg  declare---------------------------------------------------------------
reg  [LB_PXL_N-1:0][PW-1:0] arc_buf;
reg  [LB_AW-1:0] rc_lb_addr;
reg  rc_lb_hold_flag; //line last and (rc_buf_cnt+WR_PXL_N)>LB_PXL_N;
//wire declare---------------------------------------------------------------
wire [XW-0:0] pic_width = pic_width_m1+1'b1; //spyglass disable W164b
//statement------------------------------------------------------------------

wire in_hs = in_valid && in_ready;
wire lb_hs = lb_wr_vld && lb_wr_rdy;
generate
if( LB_PXL_N>WR_PXL_N )begin:gen_nrm

reg  [LB_PXL_N_L2-1:0] rc_buf_cnt;
wire [LB_PXL_N_L2-0:0] buf_tol = LB_PXL_N; //spyglass disable W528
wire [LB_PXL_N_L2-0:0] buf_cnt_nxt_t = rc_buf_cnt + WR_PXL_N[LB_PXL_N_L2-0:0];
wire [LB_PXL_N_L2-0:0] buf_cnt_rnd   = buf_cnt_nxt_t - LB_PXL_N[LB_PXL_N_L2-0:0];
wire [LB_PXL_N_L2-0:0] buf_cnt_nxt   = buf_cnt_nxt_t>=LB_PXL_N[LB_PXL_N_L2-0:0] ? buf_cnt_rnd : buf_cnt_nxt_t;
wire [LB_PXL_N_L2-0:0] buf_cnt_end   = LB_PXL_N[LB_PXL_N_L2-0:0] - rc_buf_cnt; //spyglass disable W528
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_buf_cnt <= 'b0;
    else if( clear || in_sof || (in_hs&&in_last) )
        rc_buf_cnt <= 'b0;
    else if( in_hs )
        rc_buf_cnt <= buf_cnt_nxt;
end

wire b_picw_need_hold = |pic_width[LB_PXL_N_L2-1:0];
wire b_buf_ovf_flag = buf_cnt_nxt_t>=LB_PXL_N[LB_PXL_N_L2-0:0];
wire lb_hold_start = in_hs && in_last && buf_cnt_nxt_t>LB_PXL_N[LB_PXL_N_L2-0:0] && b_picw_need_hold;
wire lb_hold_done  = rc_lb_hold_flag && lb_hs;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_lb_hold_flag <= 1'b0;
    else if( clear || in_sof || lb_hold_done )
        rc_lb_hold_flag <= 1'b0;
    else if( lb_hold_start )
        rc_lb_hold_flag <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_lb_addr <= 'b0;
    else if( clear || in_sof || (in_hs&&in_last&&!lb_hold_start) || lb_hold_done )
        rc_lb_addr <= 'b0;
    else if( lb_hs )
        rc_lb_addr <= rc_lb_addr+1'b1;
end

reg  [LB_PXL_N+WR_PXL_N -1:0][PW-1:0] arb_buf_dat; //arb_buf_dat[LB_PXL_N+WR_PXL_N-1] never use;
always @*
begin
    arb_buf_dat = ((LB_PXL_N+WR_PXL_N)*PW)'(0);
    for( int i=0; i<LB_PXL_N+WR_PXL_N; i++ )begin
        if( in_hs && i<rc_buf_cnt )
            arb_buf_dat[i] = arc_buf[i];
        else if( in_hs && i<buf_cnt_nxt_t )
            arb_buf_dat[i] = in_data[i-rc_buf_cnt];
    end
end

wire  [LB_PXL_N-1:0][PW-1:0] buf_dat_nxt = b_buf_ovf_flag ?
                             arb_buf_dat[LB_PXL_N +:WR_PXL_N] + (LB_PXL_N*PW)'(0) : arb_buf_dat[LB_PXL_N-1:0];
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_buf <= 'b0;
    else if( in_hs )
        arc_buf <= buf_dat_nxt;
end

wire  [LB_PXL_N-1:0][PW-1:0] buf_dat_out = rc_lb_hold_flag ? arc_buf : arb_buf_dat[LB_PXL_N-1:0];
assign lb_wr_vld = rc_lb_hold_flag ? 1'b1 : in_valid&&(b_buf_ovf_flag||in_last);
assign lb_wr_addr= rc_lb_addr;
assign lb_wr_data= buf_dat_out;
assign in_ready  = rc_lb_hold_flag ? 1'b0 : (b_buf_ovf_flag||in_last) ? lb_wr_rdy : 1'b1;


//debug-----
reg  [XW-1:0] rc_xcnt; //only for debug
// wire [XW-1:0] pic_width_m1 = pic_width-1'b1;
// wire b_xcnt_end = rc_xcnt==pic_width_m1;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_xcnt <= 'b0;
    else if( clear || in_last&&in_hs )
        rc_xcnt <= 'b0;
    else if( in_hs )
        rc_xcnt <= rc_xcnt+WR_PXL_N;
end
end:gen_nrm
else begin:gen_abnrm

    reg  [XW-1:0] rc_xcnt;
    wire b_xcnt_end = rc_xcnt==pic_width_m1;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            rc_xcnt <= 'b0;
        else if( clear || in_sof || in_valid&&in_ready&&b_xcnt_end )
            rc_xcnt <= 'b0;
        else if( in_valid&&in_ready )
            rc_xcnt <= rc_xcnt+WR_PXL_N;
    end

    assign lb_wr_vld  = in_valid;
    assign lb_wr_addr = rc_xcnt ;
    assign lb_wr_data = in_data ;
    assign in_ready = lb_wr_rdy;
end:gen_abnrm
endgenerate

endmodule //end of com_img_lb_wr

