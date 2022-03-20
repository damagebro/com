/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/04/16-10:27:03
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_cut_rd_req_v
`define com_img_cut_rd_req_v
module com_img_cut_rd_req #( parameter
    IMGW_W    = 10 ,
    IMGH_W    = 10 ,
    PIX_W     = 16 ,
    BUS_W     = 128,
    ADDR_W    = 32 ,
    LEN_W     = 32 //,
)(
input  wire                         clk               ,
input  wire                         rst_n             ,
input  wire                         clear             ,

input  wire [IMGW_W-1:0]            pic_width         ,
input  wire [IMGH_W-1:0]            pic_heigh         ,
input  wire [ADDR_W-1:0]            pic_start_addr    ,
input  wire [$clog2(PIX_W+1)-1:0]   pixel_bitdepth    ,
input  wire [15    -1:0]            line_stride       ,

input  wire [IMGW_W-1:0]            cut_xpos          ,
input  wire [IMGH_W-1:0]            cut_ypos          ,
input  wire [IMGW_W-1:0]            cut_width         ,
input  wire [IMGH_W-1:0]            cut_heigh         ,
input  wire                         cut_rd_vld        ,
output wire                         cut_rd_rdy        ,

output wire                         dat_dec_vld       ,
input  wire                         dat_dec_rdy       ,
output wire [IMGW_W-1:0]            dat_dec_xpos      ,
output wire [IMGW_W-1:0]            dat_dec_width     ,
output wire [IMGH_W-1:0]            dat_dec_heigh     ,
output wire [LEN_W -1:0]            dat_dec_line_wordlen, //cut_line wordlen

output wire                         bus_ra_vld        ,
input  wire                         bus_ra_rdy        ,
output wire [ADDR_W-1:0]            bus_ra_addr       ,
output wire [LEN_W-1:0]             bus_ra_bytelen    //,
);
//localparam-----------------------------------------------------------------
localparam BUS_BW = $clog2(BUS_W/8);
localparam AW = ADDR_W;
localparam LW = LEN_W ;
localparam PW = PIX_W ;
localparam XW = IMGW_W;
localparam YW = IMGH_W;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------
wire                 cut_ivld  = cut_rd_vld;
wire                 cut_irdy  ;
wire [XW*2+YW*2-1:0] cut_idata = {cut_xpos,cut_ypos,cut_width,cut_heigh};
wire                 cut_ovld  ;
wire                 cut_ordy  ;
wire [XW*2+YW*2-1:0] cut_odata ;
stl_dp_buffer #(
    .DATA_W     ( XW*2+YW*2     ), //8
    .DEPTH      ( 2             )  //4
)r_stl_dp_buffer_cut
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( cut_ivld             ), //i
    .irdy                 ( cut_irdy             ), //o
    .idata                ( cut_idata            ), //i
    .ovld                 ( cut_ovld             ), //o
    .ordy                 ( cut_ordy             ), //i
    .odata                ( cut_odata            )  //o
);
assign cut_rd_rdy = cut_irdy;

//deal one cut rd---
wire cut_rd_start = cut_ovld&&cut_ordy;
wire cut_rd_done;
reg  cut_calc_busy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        cut_calc_busy <= 1'b0;
    else if( clear || (cut_rd_done&&!cut_rd_start) )
        cut_calc_busy <= 1'b0;
    else if( cut_rd_start )
        cut_calc_busy <= 1'b1;
end

reg  [XW-1:0]  rc_req_xpos  ;
reg  [YW-1:0]  rc_req_ypos  ;
reg  [XW-1:0]  rc_req_width ;
reg  [YW-1:0]  rc_req_heigh ;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        {rc_req_xpos,rc_req_ypos,rc_req_width,rc_req_heigh} <= 'b0;
    else if( cut_rd_start )
        {rc_req_xpos,rc_req_ypos,rc_req_width,rc_req_heigh} <= cut_odata;
end

wire [XW+PW-1:0] line_bit_s = rc_req_xpos*pixel_bitdepth;
wire [XW+PW-1:0] line_bit_e = line_bit_s + rc_req_width*pixel_bitdepth - 1'b1;
wire [LW-1:0] line_byte_s = (line_bit_s>>3) + LW'(0);
wire [LW-1:0] line_word_s = (line_byte_s>>BUS_BW) + LW'(0);
wire [LW-1:0] line_byte_e = (line_bit_e>>3) + (|line_bit_e[2:0]) + LW'(0);
wire [LW-1:0] line_word_e = (line_byte_e>>BUS_BW) + (|line_byte_e[BUS_BW-1:0]) + LW'(0);
wire [LW-1:0] line_word_len = line_word_e-line_word_s;

wire [AW-1:0] start_line_addr = pic_start_addr + line_stride*rc_req_ypos + AW'(0);
wire [AW-1:0] start_cut_addr = start_line_addr + {line_word_s,BUS_BW'(0)};

//out bus_ra---
wire [0:0] mimo_arr_ivld = cut_calc_busy;
wire [0:0] mimo_arr_irdy ;
wire [1:0] mimo_arr_ovld ;
wire [1:0] mimo_arr_ordy ;
com_mimo #(
    .ICH        ( 1        ), //1
    .OCH        ( 2        )  //2
)u_com_mimo_out
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .arr_ivld             ( mimo_arr_ivld        ), //i
    .arr_irdy             ( mimo_arr_irdy        ), //o
    .arr_ovld             ( mimo_arr_ovld        ), //o
    .arr_ordy             ( mimo_arr_ordy        )  //i
);
wire mimo_ihs = mimo_arr_ivld&&mimo_arr_irdy;

reg  [YW-1:0] rc_ycnt;
wire [YW-1:0] ycnt_p1 = rc_ycnt+1'b1;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_ycnt <= 'b0;
    else if( clear || cut_rd_start )
        rc_ycnt <= 'b0;
    else if( mimo_ihs )
        rc_ycnt <= ycnt_p1;
end
wire [AW-1:0] out_addr = start_cut_addr + rc_ycnt*line_stride;

reg  rc_dat_dec_fst_line_flag ;
reg  [AW-1:0] rc_out_addr   ;
reg  [LW-1:0] rc_out_bytelen;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_dat_dec_fst_line_flag <= 1'b0;
        rc_out_addr    <= 'b0;
        rc_out_bytelen <= 'b0;
    end
    else if( mimo_ihs )begin
        rc_dat_dec_fst_line_flag <= rc_ycnt==YW'(0);
        rc_out_addr    <= out_addr;
        rc_out_bytelen <= {line_word_len,BUS_BW'(0)};
    end
end

assign cut_ordy = !cut_calc_busy || cut_rd_done;

assign cut_rd_done = cut_calc_busy && mimo_ihs && ycnt_p1==rc_req_heigh;
assign bus_ra_vld = mimo_arr_ovld[0];
assign bus_ra_addr= rc_out_addr;
assign bus_ra_bytelen = rc_out_bytelen;
assign mimo_arr_ordy[0] = bus_ra_rdy;

assign dat_dec_vld = mimo_arr_ovld[1] && rc_dat_dec_fst_line_flag;
assign dat_dec_xpos  = rc_req_xpos ;
assign dat_dec_width = rc_req_width;
assign dat_dec_heigh = rc_req_heigh;
assign dat_dec_line_wordlen = rc_out_bytelen>>BUS_BW;
assign mimo_arr_ordy[1] = (dat_dec_rdy&&rc_dat_dec_fst_line_flag) || !rc_dat_dec_fst_line_flag;

endmodule //end of com_img_cut_rd_req
`endif //end of com_img_cut_rd_req_v

