/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/04/01-22:24:26
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_cut_rd_v
`define com_img_cut_rd_v
module com_img_cut_rd #( parameter
    XW     = 12 ,
    PW     = 16 , //[1:31:1]
    PXL_N  = 1  , //[1:8:1] //PXL_N*PW<BUS_DW
    BUS_AW = 32 ,  //[8:64:1]
    BUS_DW = 128,  //[32:1024:2^n]
    BUS_LW = 32 //,//[8:64:1]
)(
input  wire                         clk               ,
input  wire                         rst_n             ,
input  wire                         clear             ,
//cfg&status--
input  wire [XW-1:0]                pic_width_m1      ,
input  wire [XW-1:0]                pic_heigh_m1      ,
input  wire [4:0]                   pixel_bitlen      ,
input  wire [BUS_AW-1:0]            pic_base_addr     ,
input  wire [15:0]                  line_stride       ,
//dp---
input  wire [XW-1:0]                cut_xpos          ,
input  wire [XW-1:0]                cut_ypos          ,
input  wire [XW-1:0]                cut_width_m1      ,
input  wire [XW-1:0]                cut_heigh_m1      ,
input  wire                         cut_rd_vld        ,
output wire                         cut_rd_rdy        ,

output wire                         pixel_sob         ,//start of cut block, pulse; early than the first pixel_valid at least 1cycle;
output wire                         pixel_eob         ,
output wire                         pixel_last        ,
output wire [PXL_N-1:0][PW-1:0]     pixel_data        ,
output wire                         pixel_valid       ,
input  wire                         pixel_ready       ,

output wire [BUS_AW-1:0]            bus_ra_addr       ,
output wire [BUS_LW-1:0]            bus_ra_bytelen    ,
output wire                         bus_ra_valid      ,
input  wire                         bus_ra_ready      ,
input  wire [BUS_DW-1:0]            bus_rd_data       ,
input  wire                         bus_rd_valid      ,
output wire                         bus_rd_ready      //,
);
//localparam-----------------------------------------------------------------
localparam BUS_BYTES = $clog2(BUS_DW/8);
localparam AW = BUS_AW;
localparam LW = BUS_LW;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
// wire pixel_eob;
//statement------------------------------------------------------------------

//deal cut req---
wire [XW-0:0] cut_xpos_e = cut_xpos + cut_width_m1; //spyglass disable W164b
wire [XW-1:0] cut_width_m1_use = cut_xpos_e>{1'b0,pic_width_m1} ? pic_width_m1-cut_xpos : cut_width_m1;
wire [XW-0:0] cut_ypos_e = cut_ypos + cut_heigh_m1; //spyglass disable W164b
wire [XW-1:0] cut_heigh_m1_use = cut_ypos_e>{1'b0,pic_heigh_m1} ? pic_heigh_m1-cut_ypos : cut_heigh_m1;

wire cut_rd_hs = cut_rd_vld && cut_rd_rdy;
wire cut_rd_eob;
reg  rc_cut_busy;
reg  [XW-1:0] rc_cut_xpos     ;
reg  [XW-1:0] rc_cut_ypos     ;
reg  [XW-1:0] rc_cut_width_m1 ;
reg  [XW-1:0] rc_cut_heigh_m1 ;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_cut_xpos     <= 'b0;
        rc_cut_ypos     <= 'b0;
        rc_cut_width_m1 <= 'b0;
        rc_cut_heigh_m1 <= 'b0;
    end
    else if( cut_rd_hs )begin
        rc_cut_xpos     <= cut_xpos    ;
        rc_cut_ypos     <= cut_ypos    ;
        rc_cut_width_m1 <= cut_width_m1_use;
        rc_cut_heigh_m1 <= cut_heigh_m1_use;
    end
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_cut_busy <= 1'b0;
    else if( clear )
        rc_cut_busy <= 1'b0;
    else if( cut_rd_hs )
        rc_cut_busy <= 1'b1;
    else if( cut_rd_eob )
        rc_cut_busy <= 1'b0;
end

//cut_req buffered for bus_unpack
wire [LW-1:0] line_word_len_t;
wire                 cut_req_ivld  = cut_rd_vld && !rc_cut_busy;
wire                 cut_req_irdy  ;
wire [XW*4+LW-1:0]   cut_req_idata = {line_word_len_t,cut_heigh_m1_use,cut_width_m1_use,cut_ypos,cut_xpos};
wire                 cut_req_ovld  ;
wire                 cut_req_ordy  ;
wire [XW*4+LW-1:0]   cut_req_odata ;
com_dp_buffer #(
    .DW         ( XW*4 +LW   ), //8
    .DEPTH      ( 2      )  //4
)zr_com_dp_buffer_cut_req
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( cut_req_ivld         ), //i
    .irdy                 ( cut_req_irdy         ), //o
    .idata                ( cut_req_idata        ), //i
    .ovld                 ( cut_req_ovld         ), //spyglass disable W528 //o
    .ordy                 ( cut_req_ordy         ), //i
    .odata                ( cut_req_odata        )  //o
);
assign cut_rd_rdy = !rc_cut_busy && cut_req_irdy;
wire [XW-1:0] buf_cut_xpos     ;
wire [XW-1:0] buf_cut_ypos     ;
wire [XW-1:0] buf_cut_width_m1 ;
wire [XW-1:0] buf_cut_heigh_m1 ;
wire [LW-1:0] buf_line_word_len;
assign {buf_line_word_len,buf_cut_heigh_m1,buf_cut_width_m1,buf_cut_ypos,buf_cut_xpos} = cut_req_odata;

//bus req--
wire [XW-1:0] cut_width_m1_s = cut_rd_hs ? cut_width_m1_use : rc_cut_width_m1;
wire [XW-1:0] cut_xpos_s = cut_rd_hs ? cut_xpos : rc_cut_xpos;
wire [XW-0:0] cut_width = cut_width_m1_s+1'b1; //spyglass disable W164b
wire [XW+PW-1:0] line_bit_s = cut_xpos_s*pixel_bitlen; //spyglass disable W164b
wire [XW+PW-1:0] line_bit_e = line_bit_s + cut_width*pixel_bitlen - 1'b1;
wire [LW-1:0] line_byte_s = (line_bit_s>>3) + LW'(0);
wire [LW-1:0] line_word_s = (line_byte_s>>BUS_BYTES) + LW'(0);
wire [LW-1:0] line_byte_e = (line_bit_e>>3) + (|line_bit_e[2:0]) + LW'(0);
wire [LW-1:0] line_word_e = (line_byte_e>>BUS_BYTES) + (|line_byte_e[BUS_BYTES-1:0]) + LW'(0);
wire [LW-1:0] line_word_len = line_word_e-line_word_s;
wire [AW-1:0] start_line_addr = pic_base_addr + line_stride*rc_cut_ypos + AW'(0);
wire [AW-1:0] start_cut_addr = start_line_addr + {line_word_s,BUS_BYTES'(0)};
assign line_word_len_t = line_word_len;

wire bus_req_hs;
reg  [XW-1:0] rc_ycnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_ycnt <= 'b0;
    else if( clear || cut_rd_hs )
        rc_ycnt <= 'b0;
    else if( bus_req_hs )
        rc_ycnt <= rc_ycnt+1'b1;
end
wire [AW-1:0] out_addr = start_cut_addr + rc_ycnt*line_stride;
wire b_bus_req_yend = rc_ycnt==rc_cut_heigh_m1;
wire ps_bus_req_done= b_bus_req_yend && bus_req_hs;
assign cut_rd_eob = ps_bus_req_done;

reg  rc_bus_req_busy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_req_busy <= 1'b0;
    else if( clear )
        rc_bus_req_busy <= 1'b0;
    else if( cut_rd_hs )
        rc_bus_req_busy <= 1'b1;
    else if( ps_bus_req_done )
        rc_bus_req_busy <= 1'b0;
end

wire       bus_req_ivld     = rc_bus_req_busy;
wire       bus_req_irdy     ;
wire       bus_req_ovld     ;
wire       bus_req_ordy     = bus_ra_ready;
wire [0:0] bus_req_in_upen  ;
com_pipe_ctrl #( .NUM_PIPE(1) ) zr_com_pipe_ctrl_x( clk, rst_n, clear, bus_req_ivld, bus_req_irdy, bus_req_ovld, bus_req_ordy, bus_req_in_upen ); //spyglass disable W528
assign bus_req_hs = bus_req_ivld && bus_req_irdy;

reg  [AW-1:0] rc_out_addr   ;
reg  [LW-1:0] rc_out_bytelen;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_out_addr    <= 'b0;
        rc_out_bytelen <= 'b0;
    end
    else if( bus_req_hs )begin
        rc_out_addr    <= out_addr;
        rc_out_bytelen <= {line_word_len,BUS_BYTES'(0)};
    end
end
assign bus_ra_addr = rc_out_addr;
assign bus_ra_bytelen = rc_out_bytelen;
assign bus_ra_valid = bus_req_ovld;

//bus dat---
wire              bus_dat_ivld  = bus_rd_valid;
wire              bus_dat_irdy  ;
wire [BUS_DW-1:0] bus_dat_idata = bus_rd_data;
wire              bus_dat_ovld_t;
wire              bus_dat_ordy_t;
wire [BUS_DW-1:0] bus_dat_odata ;
com_dp_buffer #(
    .DW         ( BUS_DW ), //8
    .DEPTH      ( 2      )  //4
)zr_com_dp_buffer_bus_dat
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( bus_dat_ivld         ), //i
    .irdy                 ( bus_dat_irdy         ), //o
    .idata                ( bus_dat_idata        ), //i
    .ovld                 ( bus_dat_ovld_t       ), //o
    .ordy                 ( bus_dat_ordy_t       ), //i
    .odata                ( bus_dat_odata        )  //o
);
assign bus_rd_ready = bus_dat_irdy;

//dat decode---
wire [XW-0:0] buf_cut_heigh = buf_cut_heigh_m1 +1'b1; //spyglass disable W164b
wire [XW*2-1:0] tol_line_word_len = buf_cut_heigh * buf_line_word_len + (XW*2)'(0);
reg  [XW*2-1:0] rc_bus_dat_cnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_dat_cnt <= 'b0;
    else if( clear || pixel_eob )
        rc_bus_dat_cnt <= 'b0;
    else if( bus_dat_ovld_t&&bus_dat_ordy_t )
        rc_bus_dat_cnt <= rc_bus_dat_cnt + 1'b1;
end
wire b_bus_dat_cnt_end = rc_bus_dat_cnt>=tol_line_word_len;

reg  rc_dat_decode_busy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_dat_decode_busy <= 1'b0;
    else if( clear )
        rc_dat_decode_busy <= 1'b0;
    else if( pixel_sob )
        rc_dat_decode_busy <= 1'b1;
    else if( pixel_eob )
        rc_dat_decode_busy <= 1'b0;
end

wire cut_idle;
wire bus_dat_ovld = rc_dat_decode_busy&&!b_bus_dat_cnt_end ? bus_dat_ovld_t : 1'b0;
wire bus_dat_ordy;
assign bus_dat_ordy_t = rc_dat_decode_busy&&!b_bus_dat_cnt_end ? bus_dat_ordy : 1'b0;
com_img_bus_unpack #(
    .XW         ( XW         ), //12
    .PW         ( PW         ), //8
    .PXL_N      ( PXL_N      ), //1
    .BUS_DW     ( BUS_DW     )  //128
)u_com_img_bus_unpack
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg&status---
    .pixel_bitlen         ( pixel_bitlen         ), //i
    .pic_width_m1         ( pic_width_m1         ), //i
    .cut_width_m1         ( buf_cut_width_m1     ), //i
    .cut_xpos_s           ( buf_cut_xpos         ), //i
    .cut_cfg_en           ( pixel_sob            ), //i
    .cut_idle             ( cut_idle             ), //o
    //dp---
    .bus_rd_data          ( bus_dat_odata        ), //i
    .bus_rd_valid         ( bus_dat_ovld         ), //i
    .bus_rd_ready         ( bus_dat_ordy         ), //o

    .pixel_last           ( pixel_last           ), //o
    .pixel_data           ( pixel_data           ), //o
    .pixel_valid          ( pixel_valid          ), //o
    .pixel_ready          ( pixel_ready          )  //i
);
wire pxl_hs = pixel_valid&&pixel_ready;
reg  [XW-1:0] rc_pxl_ycnt;
wire pxl_xcnt_done = pxl_hs && pixel_last;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_pxl_ycnt <= 'b0;
    else if( clear || pixel_sob )
        rc_pxl_ycnt <= 'b0;
    else if( pxl_xcnt_done )
        rc_pxl_ycnt <= rc_pxl_ycnt+1'b1;
end
assign pixel_sob = !rc_dat_decode_busy && bus_dat_ovld_t && cut_idle;
wire pixel_eob_tmp = pxl_xcnt_done && rc_pxl_ycnt==buf_cut_heigh_m1;
// reg  pixel_eob_d;
// always @(posedge clk or negedge rst_n)
// begin
//     if( !rst_n )
//         pixel_eob_d <= 1'b0;
//     else
//         pixel_eob_d <= pixel_eob_tmp;
// end
assign pixel_eob = pixel_eob_tmp;
assign cut_req_ordy = pixel_eob;

endmodule //end of com_img_cut_rd
`endif //end of com_img_cut_rd_v

