/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/04/01-22:24:32
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_img_cut_wr_v
`define com_img_cut_wr_v
module com_img_cut_wr #( parameter
    XW     = 12 ,
    PW     = 16 , //[1:31:1]
    PXL_N  = 1  , //[1:8:1] //PXL_N*PW<BUS_DW
    BUS_AW = 32 ,  //[8:64:1]
    BUS_DW = 128,  //[32:1024:2^n]
    BUS_LW = 32 //,//[8:64:1]
)
(
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
input  wire                         cut_wr_vld        ,
output wire                         cut_wr_rdy        ,
output wire                         cut_wb_resp       ,

input  wire                         pixel_sob         ,//start of cut block, pulse; early than the first pixel_valid at least 1cycle;
input  wire                         pixel_last        ,
input  wire [PXL_N-1:0][PW-1:0]     pixel_data        ,
input  wire                         pixel_valid       ,
output wire                         pixel_ready       ,

output wire [BUS_AW-1:0]            bus_wa_addr       ,
output wire [BUS_LW-1:0]            bus_wa_bytelen    ,
output wire                         bus_wa_valid      ,
input  wire                         bus_wa_ready      ,
output wire [BUS_DW-1:0]            bus_wd_data       ,
output wire                         bus_wd_valid      ,
input  wire                         bus_wd_ready      ,
input  wire                         bus_wb_resp       //,
);
//localparam-----------------------------------------------------------------
localparam BUS_BYTES = $clog2(BUS_DW/8);
localparam AW = BUS_AW;
localparam LW = BUS_LW;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire pixel_eob;
//statement------------------------------------------------------------------
wire [XW-0:0] cut_xpos_e = cut_xpos + cut_width_m1;
wire [XW-1:0] cut_width_m1_use = cut_xpos_e>pic_width_m1 ? pic_width_m1-cut_xpos : cut_width_m1;
wire [XW-0:0] cut_ypos_e = cut_ypos + cut_heigh_m1;
wire [XW-1:0] cut_heigh_m1_use = cut_ypos_e>pic_heigh_m1 ? pic_heigh_m1-cut_ypos : cut_heigh_m1;

wire cut_wr_hs = cut_wr_vld && cut_wr_rdy;
wire cut_wr_eob;
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
    else if( cut_wr_hs )begin
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
    else if( cut_wr_hs )
        rc_cut_busy <= 1'b1;
    else if( cut_wr_eob )
        rc_cut_busy <= 1'b0;
end

//cut_req buffered for wb_resp
wire              cut_req_ivld  = cut_wr_vld;
wire              cut_req_irdy  ;
wire [XW*1-1:0]   cut_req_idata = {cut_heigh_m1_use};
wire              cut_req_ovld  ;
wire              cut_req_ordy  ;
wire [XW*1-1:0]   cut_req_odata ;
com_dp_buffer #(
    .DW         ( XW*1   ), //8
    .DEPTH      ( 2      )  //4
)zr_com_dp_buffer_cut_req
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( cut_req_ivld         ), //i
    .irdy                 ( cut_req_irdy         ), //o
    .idata                ( cut_req_idata        ), //i
    .ovld                 ( cut_req_ovld         ), //o
    .ordy                 ( cut_req_ordy         ), //i
    .odata                ( cut_req_odata        )  //o
);
assign cut_wr_rdy = !rc_cut_busy && cut_req_irdy;
wire [XW-1:0] buf_cut_heigh_m1 ;
assign {buf_cut_heigh_m1} = cut_req_odata;

//bus req--
wire [XW-0:0] cut_width = rc_cut_width_m1+1'b1;
wire [XW+PW-1:0] line_bit_s = rc_cut_xpos*pixel_bitlen;
wire [XW+PW-1:0] line_bit_e = line_bit_s + cut_width*pixel_bitlen - 1'b1;
wire [LW-1:0] line_byte_s = (line_bit_s>>3) + LW'(0);
wire [LW-1:0] line_word_s = (line_byte_s>>BUS_BYTES) + LW'(0);
wire [LW-1:0] line_byte_e = (line_bit_e>>3) + (|line_bit_e[2:0]) + LW'(0);
wire [LW-1:0] line_word_e = (line_byte_e>>BUS_BYTES) + (|line_byte_e[BUS_BYTES-1:0]) + LW'(0);
wire [LW-1:0] line_word_len = line_word_e-line_word_s;
wire [AW-1:0] start_line_addr = pic_base_addr + line_stride*rc_cut_ypos + AW'(0);
wire [AW-1:0] start_cut_addr = start_line_addr + {line_word_s,BUS_BYTES'(0)};

wire bus_req_hs;
reg  [XW-1:0] rc_ycnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_ycnt <= 'b0;
    else if( clear || cut_wr_hs )
        rc_ycnt <= 'b0;
    else if( bus_req_hs )
        rc_ycnt <= rc_ycnt+1'b1;
end
wire [AW-1:0] out_addr = start_cut_addr + rc_ycnt*line_stride;
wire b_bus_req_yend = rc_ycnt==rc_cut_heigh_m1;
wire ps_bus_req_done= b_bus_req_yend && bus_req_hs;
assign cut_wr_eob = ps_bus_req_done;

reg  rc_bus_req_busy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_bus_req_busy <= 1'b0;
    else if( clear )
        rc_bus_req_busy <= 1'b0;
    else if( cut_wr_hs )
        rc_bus_req_busy <= 1'b1;
    else if( ps_bus_req_done )
        rc_bus_req_busy <= 1'b0;
end

wire       bus_req_ivld     = rc_bus_req_busy;
wire       bus_req_irdy     ;
wire       bus_req_ovld     ;
wire       bus_req_ordy     = bus_wa_ready;
wire [0:0] bus_req_in_upen  ;
com_pipe_ctrl #( .NUM_PIPE(1) ) zr_com_pipe_ctrl_x( clk, rst_n, clear, bus_req_ivld, bus_req_irdy, bus_req_ovld, bus_req_ordy, bus_req_in_upen );
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
assign bus_wa_addr = rc_out_addr;
assign bus_wa_bytelen = rc_out_bytelen;
assign bus_wa_valid = bus_req_ovld;


//bus dat---
com_img_bus_pack #(
    .XW         ( XW         ), //12
    .PW         ( PW         ), //8
    .PXL_N      ( PXL_N      ), //1
    .BUS_DW     ( BUS_DW     )  //128
)u_com_img_bus_pack
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg&status---
    .pixel_bitlen         ( pixel_bitlen         ), //i
    //dp---
    .pixel_start          ( pixel_sob            ), //i
    .pixel_last           ( pixel_last           ), //i
    .pixel_data           ( pixel_data           ), //i
    .pixel_valid          ( pixel_valid          ), //i
    .pixel_ready          ( pixel_ready          ), //o

    .bus_wd_data          ( bus_wd_data          ), //o
    .bus_wd_valid         ( bus_wd_valid         ), //o
    .bus_wd_ready         ( bus_wd_ready         )  //i
);

//wb_resp and pixel_eob---
reg  [XW-1:0] rc_resp_ycnt;
wire resp_ycnt_done = bus_wb_resp && rc_resp_ycnt==buf_cut_heigh_m1;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_resp_ycnt <= 'b0;
    else if( clear || resp_ycnt_done )
        rc_resp_ycnt <= 'b0;
    else if( bus_wb_resp )
        rc_resp_ycnt <= rc_resp_ycnt+1'b1;
end

wire pixel_eob_pre = resp_ycnt_done;
reg  pixel_eob_d;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        pixel_eob_d <= 1'b0;
    else
        pixel_eob_d <= pixel_eob_pre;
end
assign pixel_eob = pixel_eob_d;
assign cut_req_ordy = pixel_eob_d;
assign cut_wb_resp = pixel_eob;

endmodule //end of com_img_cut_wr
`endif //end of com_img_cut_wr_v

