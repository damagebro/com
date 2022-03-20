/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/04/22-09:56:10
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

`ifndef com_img_lb_rd_v
`define com_img_lb_rd_v
module com_img_lb_rd #( parameter
    XW       = 12  ,
    PW       = 8   ,
    RD_PXL_N = 1   ,
    LB_PXL_N = 8   ,
    LB_DEPTH       ,

    LB_AW = $clog2(LB_DEPTH),
    LB_DW = LB_PXL_N*PW     //,
)
(
input  wire                         clk                 ,
input  wire                         rst_n               ,
input  wire                         clear               ,

input  wire                         lb_flush_p          ,
input  wire [XW-1:0]                pic_width_m1        , //spyglass disable W240

input  wire                         rd_vld              ,
output wire                         rd_rdy              ,
input  wire [XW-1:0]                rd_xpos_s           ,
output wire                         rd_ack              ,
output wire [RD_PXL_N-1:0][PW-1:0]  rd_data             ,

output wire                         lb_rd_vld           ,
input  wire                         lb_rd_rdy           ,
output wire [LB_AW-1:0]             lb_rd_addr          ,
input  wire                         lb_rd_ack           ,
input  wire [LB_DW-1:0]             lb_rd_data          //,
);
//localparam-----------------------------------------------------------------
`STL_PARAM_ASSERT( LB_PXL_N>=1, "LB_PXL_N>=1" ); //spyglass disable W193
`STL_PARAM_ASSERT( LB_PXL_N==1<<$clog2(LB_PXL_N), "LB_PXL_N==2^n" ); //spyglass disable W193
`STL_PARAM_ASSERT( RD_PXL_N<=LB_PXL_N, "RD_PXL_N<=LB_PXL_N" ); //spyglass disable W193
localparam LB_PXL_N_L2 = $clog2(LB_PXL_N);

localparam ST_IDLE = 3'b001;
localparam ST_RDS  = 3'b010;
localparam ST_RDE  = 3'b100;

localparam IDX_IDLE = 0;
localparam IDX_RDS  = 1;
localparam IDX_RDE  = 2;
//reg  declare---------------------------------------------------------------
reg  rc_buf_vld;
reg  [LB_PXL_N-1:0][PW-1:0] arc_buf;
reg  [XW-1:0] rc_prev_xpos;

reg  [2:0] rc_rd_sta;
reg  [2:0] rb_rd_sta_nxt;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

generate
if( LB_PXL_N>1 )begin:gen_nrm
wire lb_rd_hs = lb_rd_vld&&lb_rd_rdy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_buf_vld <= 1'b0;
    else if( clear || lb_flush_p )
        rc_buf_vld <= 1'b0;
    else if( !rc_buf_vld && lb_rd_ack )
        rc_buf_vld <= 1'b1;
end
wire b_buf_vld = rc_buf_vld || lb_rd_ack&&!rc_buf_vld;

wire rd_hs = rd_vld&&rd_rdy;
reg  rc_lb_rd_vld_flag;
reg  [XW-1:0] rc_rd_xpos_s;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_lb_rd_vld_flag <= 1'b0;
    else if( clear || lb_flush_p || (lb_rd_hs&&!rc_rd_sta[IDX_RDS]) )
        rc_lb_rd_vld_flag <= 1'b0;
    else if( !rc_lb_rd_vld_flag && lb_rd_vld )
        rc_lb_rd_vld_flag <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_xpos_s <= 'b0;
    else if( rd_hs )
        rc_rd_xpos_s <= rd_xpos_s;
end
wire [XW-1:0] rd_xpos_s_sel = rc_lb_rd_vld_flag ? rc_rd_xpos_s : rd_xpos_s;

wire [XW-1:0] rd_xpos_e = rd_xpos_s_sel+RD_PXL_N-1;
wire [XW-1:0] rd_xpos_s_alg = rd_xpos_s_sel>>LB_PXL_N_L2;
wire [XW-1:0] rd_xpos_e_alg = rd_xpos_e>>LB_PXL_N_L2;
wire [LB_PXL_N_L2-1:0] rd_xpos_s_lsb = rd_xpos_s_sel[LB_PXL_N_L2-1:0];
wire [LB_PXL_N_L2-1:0] rd_xpos_e_lsb = rd_xpos_e[LB_PXL_N_L2-1:0]; //spyglass disable W528
wire b_rd_xpos_s_equ =(b_buf_vld && rd_xpos_s_alg==rc_prev_xpos) || (rd_xpos_s_alg==rd_xpos_e_alg);
wire b_rd_xpos_e_equ = b_buf_vld && rd_xpos_e_alg==rc_prev_xpos;
wire b_rd_xpos_equ = b_rd_xpos_s_equ && b_rd_xpos_e_equ;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_prev_xpos <= 'b0;
    else if( lb_rd_hs )
        rc_prev_xpos <= rd_xpos_e_alg;
end

reg  [LB_PXL_N_L2-1:0] rd_xpos_s_lsb_d;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rd_xpos_s_lsb_d <= 'b0;
    else if( rd_vld && rd_rdy )
        rd_xpos_s_lsb_d <= rd_xpos_s_lsb;
end

//status machine--
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_sta <= ST_IDLE;
    else if( clear )
        rc_rd_sta <= ST_IDLE;
    else
        rc_rd_sta <= rb_rd_sta_nxt;
end
always @*
begin
    case( rc_rd_sta )
    ST_IDLE : begin rb_rd_sta_nxt = rd_vld&&!b_rd_xpos_s_equ ? ST_RDS : rd_vld&&!b_rd_xpos_e_equ ? ST_RDE : ST_IDLE; end
    ST_RDS  : begin rb_rd_sta_nxt = lb_rd_ack ? ST_RDE  : ST_RDS; end
    ST_RDE  : begin rb_rd_sta_nxt = lb_rd_ack ? ST_IDLE : ST_RDE; end
    default : begin rb_rd_sta_nxt = ST_IDLE; end
    endcase
end

//buf data--
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_buf <= 'b0;
    else if( lb_rd_ack )
        arc_buf <= lb_rd_data;
end

wire rd_s_req = rb_rd_sta_nxt[1];
wire rd_e_req = rb_rd_sta_nxt[2];
reg  rc_rd_s_reqed;
reg  rc_rd_e_reqed;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_s_reqed <= 1'b0;
    else if( clear || (rd_s_req&&lb_rd_ack) )
        rc_rd_s_reqed <= 1'b0;
    else if( rd_s_req && lb_rd_hs )
        rc_rd_s_reqed <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_e_reqed <= 1'b0;
    else if( clear || (rc_rd_e_reqed&&lb_rd_ack) )
        rc_rd_e_reqed <= 1'b0;
    else if( rd_e_req && lb_rd_hs )
        rc_rd_e_reqed <= 1'b1;
end

//rd_data--
wire b_hit_flag = rd_vld && b_rd_xpos_s_equ && b_rd_xpos_e_equ;

reg  rc_mis_equ_flag; //miss && rd_xpos_s_alg==rd_xpos_e_alg
reg  rc_hit_ack;
reg  rc_rd_busy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_mis_equ_flag <= 1'b0;
    else if( clear )
        rc_mis_equ_flag <= 1'b0;
    else if( rd_xpos_s_alg==rd_xpos_e_alg && (lb_rd_vld&&lb_rd_rdy) )
        rc_mis_equ_flag <= 1'b1;
    else if( rc_mis_equ_flag && lb_rd_ack )
        rc_mis_equ_flag <= 1'b0;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_hit_ack <= 1'b0;
    else if( clear || rc_hit_ack&&!b_hit_flag )
        rc_hit_ack <= 1'b0;
    else if( b_hit_flag )
        rc_hit_ack <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_busy <= 1'b0;
    else if( clear || (rc_rd_busy&&rd_ack) )
        rc_rd_busy <= 1'b0;
    else if( !b_hit_flag && (rd_vld&&rd_rdy) )
        rc_rd_busy <= 1'b1;
end

wire [LB_PXL_N+RD_PXL_N-1:0][PW-1:0] lb_dat_extd = {lb_rd_data[0+:RD_PXL_N*PW], lb_rd_data};
wire [LB_PXL_N+RD_PXL_N-1:0][PW-1:0] buf_dat_extd = {lb_rd_data[0+:RD_PXL_N*PW],arc_buf};
assign rd_rdy = !rc_rd_busy || (lb_rd_ack&&b_rd_xpos_equ);
assign rd_ack = rc_hit_ack || (rc_rd_sta[2]&&lb_rd_ack);
assign rd_data = (rc_mis_equ_flag && lb_rd_ack) ? lb_dat_extd[rd_xpos_s_lsb_d +:RD_PXL_N] : buf_dat_extd[rd_xpos_s_lsb_d +:RD_PXL_N];

assign lb_rd_vld = (rd_s_req&&!rc_rd_s_reqed) || (rd_e_req&&!rc_rd_e_reqed);
assign lb_rd_addr = rd_s_req ? rd_xpos_s_alg[LB_AW-1:0] : rd_xpos_e_alg[LB_AW-1:0];
end:gen_nrm
else begin:gen_abnrm
    assign lb_rd_vld  = rd_vld    ;
    assign lb_rd_addr = rd_xpos_s ;
    assign rd_rdy  = lb_rd_rdy   ;
    assign rd_ack  = lb_rd_ack   ;
    assign rd_data = lb_rd_data  ;
end:gen_abnrm
endgenerate

endmodule //end of com_img_lb_rd
`endif //end of com_img_lb_rd_v

