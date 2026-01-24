/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/03/14-22:41:32
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_extd_rd #( parameter
    AW          = 32  , //range=[8:64]
    DW          = 128 , //range=[8::2^n]
    EBUS_LW     = 32  , //range=[8:AW] ebus max_burst_bytelen.bit_width;
    LW          = 8   , //range=[1:8], axi  max_burst_wordlen.bit_width;
    UW          = 1   , //range=[1:],  ebus_axusr and axi_axusr, axuser go-though this module;
    BOUND_BYTES = 4096, //range=[DW/8:4096:2^n], addr boundary split bytesize;
    MAX_OSD     = 128 , //range=[1:1024], max axi_cmd outstanding num
    BUF_DEPTH   = 0   , //range=[0::2],  fifo_ram //if BUF_DEPTH=0, axi_osd=MAX_OSD; if BUF_DEPTH>0, "to confirm rd_bus perfomance, only rd_buffer remain space then send rd_cmd to axi_bus", axi_osd=min(MAX_OSD, BUF_DEPTH/max_burst_len), and assert(BUF_DEPTH>max_burst_len)
    MAX_REG_FIFO_DEPTH = 16,  //fifo_data_storage can use dff+sram, here specify max_dff_depth=16, largher than max_dff_depth(exceed part=BUF_DEPTH-max_dff_depth) use sram as storage;
    localparam RAM_FIFO_DEPTH = BUF_DEPTH>MAX_REG_FIFO_DEPTH ? BUF_DEPTH-MAX_REG_FIFO_DEPTH  : 0,
    localparam RAM_ONE_DEPTH  = RAM_FIFO_DEPTH/2,
    localparam RAM_ONE_AW     = $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2),
    localparam RAM_DW         = DW + 1 //, //{rlast,rdata}
)
(
input  wire                     clk                  ,
input  wire                     rst_n                ,
input  wire                     clear                ,
//cfg&status---
input  wire [7:0]               i_cfg_max_blen_m1    , //max burst_len
input  wire [15:0]              i_cfg_max_rdcmd_osd  , //if(i_cfg_max_rdcmd_osd==0), axi_osd=MAX_OSD; else if(i_cfg_max_rdcmd_osd>0), axi_osd=min(MAX_OSD,i_cfg_max_rdcmd_osd,func(BUF_DEPTH,i_cfg_max_blen_m1))
output wire [15:0]              o_sta_rdbuf_wl       , //the status of rdbuf water_level signal, wl is remain space of rd_buf;
//sram--
output wire [1:0]                 o_rdfifo_ram_ce_n    ,
output wire [1:0]                 o_rdfifo_ram_we      ,
output wire [1:0][RAM_ONE_AW-1:0] o_rdfifo_ram_addr    ,
output wire [1:0][RAM_DW-1:0]     o_rdfifo_ram_wr_data ,
input  wire [1:0][RAM_DW-1:0]     i_rdfifo_ram_rd_data ,
//dp---
input  wire [UW-1:0]            ebus_ra_user         ,
input  wire [AW-1:0]            ebus_ra_addr         ,
input  wire [EBUS_LW-1:0]       ebus_ra_bytelen      ,
input  wire                     ebus_ra_valid        ,
output wire                     ebus_ra_ready        ,
output wire [DW-1:0]            ebus_rd_data         ,
output wire                     ebus_rd_last         ,
output wire                     ebus_rd_valid        ,
input  wire                     ebus_rd_ready        ,

output wire [AW-1:0]            axi_araddr           ,
output wire [LW-1:0]            axi_arlen            ,
output wire [UW-1:0]            axi_aruser           ,
output wire                     axi_arvalid          ,
input  wire                     axi_arready          ,
input  wire [DW-1:0]            axi_rdata            ,
input  wire                     axi_rlast            ,
input  wire                     axi_rvalid           ,
output wire                     axi_rready           //,
);
//localparam-----------------------------------------------------------------
localparam AXI_LW = LW;
localparam SW = DW/8;
localparam SW_L2 = $clog2(SW);
localparam BOUND_L2 = $clog2(BOUND_BYTES);
localparam BUF_CW = $clog2((BUF_DEPTH+1)>2?(BUF_DEPTH+1):2);
localparam RA_INFO_DEPTH = MAX_OSD;
localparam RA_INFO_CW    = $clog2(RA_INFO_DEPTH+1);
localparam REG_FIFO_DEPTH = BUF_DEPTH>MAX_REG_FIFO_DEPTH ? MAX_REG_FIFO_DEPTH : BUF_DEPTH;
`COM_PARAM_ASSERT( BOUND_BYTES<=4096 || (1<<BOUND_L2)==BOUND_BYTES, "BOUND_BYTES range illegal" );
`COM_PARAM_ASSERT( BUF_DEPTH%2==0, "BUF_DEPTH must be even number" );
//signal declare-------------------------------------------------------------
wire tie_rdbuf_bypass_flag;
wire ebus_cmd_hs; // = ebus_ra_valid && ebus_ra_ready;
wire axi_cmd_hs ; // = axi_arvalid && axi_arready;
wire axi_rd_hs  ; // = axi_rvalid && axi_rready;
wire ebus_rd_hs ; // = ebus_rd_valid && ebus_rd_ready;
wire [EBUS_LW-0:0] ebus_bytelen_modify;

reg                r_split_busy;
reg  [EBUS_LW-1:0] r_rem_bytelen;
reg  [AW-1:0]      r_addr;
reg  [UW-1:0]      r_user;
reg                r_fst_split_flag;
wire               b_lst_split_flag;
wire [SW_L2-1:0]   fst_split_addr_lsb;
wire [SW_L2-1:0]   lst_split_addr_lsb;
wire [AXI_LW-1:0]  fnl_wordlen_m1;

reg  [BUF_CW-1:0] r_otf_cnt;
wire b_rdbuf_avl;  //if(BUF_DEPTH>0), only when rdbuf remain one_burst_space, then arcmd send out to fabric;
wire b_rdosd_avl;  //axi_cmd osd_num limit by (MAX_OSD + i_cfg_max_rdcmd_osd),

wire [BUF_CW-1:0]          u_rdfifo_water_level; //meaning fifo remain space;
wire                       u_rdfifo_wr_en    ;
wire [RAM_DW-1:0]          u_rdfifo_wr_data  ;
wire                       u_rdfifo_wr_full  ;
wire                       u_rdfifo_rd_en    ;
wire [RAM_DW-1:0]          u_rdfifo_rd_data  ;
wire                       u_rdfifo_rd_empty ;
wire                       u_rainfo_wr_en    ;
wire [1-1:0]               u_rainfo_wr_data  ; //each bytelen is_split_last;
wire                       u_rainfo_wr_full  ;
wire                       u_rainfo_rd_en    ;
wire [1-1:0]               u_rainfo_rd_data  ;
wire                       u_rainfo_rd_empty ;
wire [RA_INFO_CW-1:0]      u_rainfo_water_level;
//statement------------------------------------------------------------------
assign tie_rdbuf_bypass_flag = BUF_DEPTH==0;
assign ebus_cmd_hs = ebus_ra_valid && ebus_ra_ready;
assign axi_cmd_hs  = axi_arvalid && axi_arready;
assign axi_rd_hs   = axi_rvalid && axi_rready;
assign ebus_rd_hs  = ebus_rd_valid && ebus_rd_ready;
assign ebus_bytelen_modify = ebus_ra_bytelen + ebus_ra_addr[SW_L2-1:0]; //assert( ebus_bytelen_modify[EBUS_LW]==1'b0 )

assign axi_araddr  = r_addr;
assign axi_arlen   = fnl_wordlen_m1;
assign axi_aruser  = r_user;
assign axi_arvalid = r_split_busy && b_rdbuf_avl && b_rdosd_avl;
assign axi_rready = tie_rdbuf_bypass_flag ? ebus_rd_ready : !u_rdfifo_wr_full; //assert(!tie_rdbuf_bypass_flag && !u_rdfifo_wr_full); when BUF_DEPTH>0, axi_rready===1;
assign ebus_ra_ready = !r_split_busy || (r_split_busy&&b_lst_split_flag&&axi_cmd_hs);
assign ebus_rd_data  = tie_rdbuf_bypass_flag ? axi_rdata : u_rdfifo_rd_data[0 +:DW];
assign ebus_rd_last  =(tie_rdbuf_bypass_flag ?(axi_rlast && u_rainfo_rd_data==1'b1) : u_rdfifo_rd_data[DW +:1]) && ebus_rd_valid;
assign ebus_rd_valid = tie_rdbuf_bypass_flag ? axi_rvalid : !u_rdfifo_rd_empty;
assign o_sta_rdbuf_wl = 16'(u_rdfifo_water_level);

//1. split
wire [8:0]         tie_axi_wordlen = 9'b1<<AXI_LW;
wire [12:0]        tie_bound_bytelen = BOUND_BYTES[12:0];
wire [8:0]         tie_bound_wordlen = 9'(tie_bound_bytelen[12:SW_L2]);
wire [8:0]         cfg_max_blen      = i_cfg_max_blen_m1+1'b1;  //assert(cfg_max_blen<=tie_axi_wordlen || tie_bound_bytelen<=tie_axi_wordlen)
wire [9+SW_L2-1:0] cfg_burst_bytelen = {cfg_max_blen,{SW_L2{1'b0}}};
wire b_bound_only = cfg_burst_bytelen>(9+SW_L2)'(tie_bound_bytelen);
wire [12:0] sel_bytelen = b_bound_only ?  tie_bound_bytelen : 13'(cfg_burst_bytelen);

wire [AW-1:0] addr_alg = {r_addr[AW-1:SW_L2], {SW_L2{1'b0}}};
wire b_burst_split = r_rem_bytelen>EBUS_LW'(sel_bytelen);
wire [12:0]   tmp_bytelen  = b_burst_split ? sel_bytelen : 13'(r_rem_bytelen);
wire [AW-1:0] tmp_addr_nxt = addr_alg + tmp_bytelen;
wire b_bound_split = tmp_addr_nxt[BOUND_L2]!=addr_alg[BOUND_L2] && |tmp_addr_nxt[BOUND_L2-1:0]; //tmp_addr_nxt[BOUND_L2:0]>tie_bound_bytelen
wire [12:0]   ovf_bytelen  = tie_bound_bytelen - addr_alg[BOUND_L2-1:0];
wire [AW-1:0] ovf_addr_nxt = addr_alg + ovf_bytelen; //word_alg
wire [12:0]   fnl_bytelen  = b_bound_split ? ovf_bytelen : tmp_bytelen ;
wire [AW-1:0] fnl_addr_nxt = b_bound_split ? ovf_addr_nxt: tmp_addr_nxt;
wire [11:0]   fnl_wordlen  = 12'(fnl_bytelen[12:SW_L2]) + |fnl_bytelen[SW_L2-1:0];
wire [EBUS_LW-1:0] nxt_bytelen = r_rem_bytelen - fnl_bytelen;
assign fnl_wordlen_m1 = AXI_LW'(fnl_wordlen - 1'b1);
assign b_lst_split_flag = !b_burst_split && !b_bound_split;
assign fst_split_addr_lsb = r_fst_split_flag ? r_addr[SW_L2-1:0] : '0;
assign lst_split_addr_lsb = b_lst_split_flag ? r_rem_bytelen[SW_L2-1:0] : '0;
always @(posedge clk or negedge rst_n)begin
    if( !rst_n )
        r_split_busy <= 1'b0;
    else if( clear )
        r_split_busy <= 1'b0;
    else if( ebus_cmd_hs )
        r_split_busy <= 1'b1;
    else if( axi_cmd_hs && b_lst_split_flag )
        r_split_busy <= 1'b0;
end
always @(posedge clk or negedge rst_n)begin
    if( !rst_n )
        r_fst_split_flag <= 1'b0;
    else if( clear )
        r_fst_split_flag <= 1'b0;
    else if( ebus_cmd_hs )
        r_fst_split_flag <= 1'b1;
    else if( axi_cmd_hs )
        r_fst_split_flag <= 1'b0;
end
always @(posedge clk or negedge rst_n)begin
    if( !rst_n )
        r_rem_bytelen <= '0;
    else if( ebus_cmd_hs )
        r_rem_bytelen <= ebus_bytelen_modify[EBUS_LW-1:0];
    else if( axi_cmd_hs )
        r_rem_bytelen <= nxt_bytelen;
end
always @(posedge clk or negedge rst_n)begin
    if( !rst_n )
        r_addr <= '0;
    else if( ebus_cmd_hs )
        r_addr <= ebus_ra_addr;
    else if( axi_cmd_hs && !b_lst_split_flag )
        r_addr <= fnl_addr_nxt;
end
always @(posedge clk)begin
    if( ebus_cmd_hs )
        r_user <= ebus_ra_user;
end

//2. rdbuf osd ctrl--
wire [AXI_LW-0:0] tmp_axi_arlen = axi_cmd_hs ? (AXI_LW+1)'(fnl_wordlen) : '0;
wire [BUF_CW-1:0] otf_cnt_nxt   = r_otf_cnt + tmp_axi_arlen - axi_rd_hs;
wire [BUF_CW-1:0] rdbuf_avl_num = u_rdfifo_water_level - r_otf_cnt;
assign b_rdbuf_avl = tie_rdbuf_bypass_flag ? 1'b1 : (rdbuf_avl_num>BUF_CW'(axi_arlen));
always @(posedge clk or negedge rst_n)begin
    if( !rst_n )
        r_otf_cnt <= '0;
    else if( clear )
        r_otf_cnt <= '0;
    else if( axi_cmd_hs || axi_rd_hs )
        r_otf_cnt <= otf_cnt_nxt;
end
generate
if( BUF_DEPTH>0 )begin:gen_rdbuf
    assign u_rdfifo_wr_en    = axi_rd_hs;
    assign u_rdfifo_wr_data  = {(axi_rlast && u_rainfo_rd_data==1'b1), axi_rdata};
    assign u_rdfifo_rd_en    = ebus_rd_hs;
    com_sync_fifo_ram_1p2bank #(
        .RAM_RD_DELAY ( 1              ), //ram read cmd req->read data ack delay cycles, range=[1:8];  normally=1, if ecc_sram=2 maybe;
        .DW           ( RAM_DW         ), //8
        .OUT_DEPTH    ( REG_FIFO_DEPTH ),
        .RAM_DEPTH    ( RAM_FIFO_DEPTH )//, //4
    )zr_com_sync_fifo_ram_1p2bank_rdfifo
    (
        .clk                  ( clk                        ), //i
        .rst_n                ( rst_n                      ), //i
        .clear                ( clear                      ), //i

        .wr_en                ( u_rdfifo_wr_en             ), //i
        .wr_data              ( u_rdfifo_wr_data           ), //i
        .wr_full              ( u_rdfifo_wr_full           ), //o
        .rd_en                ( u_rdfifo_rd_en             ), //i
        .rd_data              ( u_rdfifo_rd_data           ), //o
        .rd_empty             ( u_rdfifo_rd_empty          ), //o
        .water_level          ( u_rdfifo_water_level       ), //o
        .ram_cen              ( o_rdfifo_ram_ce_n          ), //o
        .ram_we               ( o_rdfifo_ram_we            ), //o
        .ram_addr             ( o_rdfifo_ram_addr          ), //o
        .ram_din              ( o_rdfifo_ram_wr_data       ), //o
        .ram_qout             ( i_rdfifo_ram_rd_data       )  //i
    );
end:gen_rdbuf
else begin:gen_no_rdbuf
    assign u_rdfifo_water_level = '0;
    assign u_rdfifo_wr_en    = '0;
    assign u_rdfifo_wr_data  = '0;
    assign u_rdfifo_wr_full  = '0;
    assign u_rdfifo_rd_en    = '0;
    assign u_rdfifo_rd_data  = '0;
    assign u_rdfifo_rd_empty = '0;
    assign o_rdfifo_ram_ce_n    = '0;
    assign o_rdfifo_ram_we      = '0;
    assign o_rdfifo_ram_addr    = '0;
    assign o_rdfifo_ram_wr_data = '0;
end:gen_no_rdbuf
endgenerate

//3. rdata resp(axi_rlast->ebus_rlast)--
wire [RA_INFO_CW-1:0] rdcmd_otf_cnt = RA_INFO_DEPTH[RA_INFO_CW-1:0] - u_rainfo_water_level;
assign b_rdosd_avl = !u_rainfo_wr_full && ((16'(rdcmd_otf_cnt)<i_cfg_max_rdcmd_osd) || (i_cfg_max_rdcmd_osd=='0));
assign u_rainfo_wr_en   = axi_cmd_hs;
assign u_rainfo_wr_data = b_lst_split_flag;
assign u_rainfo_rd_en   = axi_rd_hs && axi_rlast;
com_sync_fifo_reg #(
    .DW         ( 1             ), //8
    .DEPTH      ( RA_INFO_DEPTH )  //4
)zr_com_sync_fifo_reg_rainfo
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( u_rainfo_wr_en       ), //i
    .wr_data              ( u_rainfo_wr_data     ), //i
    .wr_full              ( u_rainfo_wr_full     ), //o
    .rd_en                ( u_rainfo_rd_en       ), //i
    .rd_data              ( u_rainfo_rd_data     ), //o
    .rd_empty             ( u_rainfo_rd_empty    ), //o
    .water_level          ( u_rainfo_water_level )  //o
);

//assert----------------------------------
`COM_SIGNAL_ASSERT( a0, clk,rst_n,ebus_cmd_hs,(cfg_max_blen<=tie_axi_wordlen || tie_bound_wordlen<=tie_axi_wordlen) , "AXI_LW range can't split to (i_cfg_max_blen_m1, BOUND_BYTES)"  );
`COM_SIGNAL_ASSERT( a1, clk,rst_n,ebus_cmd_hs,(ebus_bytelen_modify[EBUS_LW]==1'b0) , "EBUS_LW range not enough, change to original_value+1" );
`COM_SIGNAL_ASSERT( a2, clk,rst_n,axi_rvalid,(tie_rdbuf_bypass_flag || axi_rready==1'b1) , "when BUF_DEPTH>0, axi_rready===1" );

//debug----------------------------------
`ifdef COM_AXI_DEBUG
reg  [31:0] r_cmd_burst_cnt;
reg  [31:0] r_dat_burst_cnt;
reg  [31:0] r_cmd_beat_cnt ;
reg  [31:0] r_dat_beat_cnt ;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )begin
        r_cmd_burst_cnt <= '0;
        r_dat_burst_cnt <= '0;
        r_cmd_beat_cnt  <= '0;
        r_dat_beat_cnt  <= '0;
    end
    else begin
        if( axi_cmd_hs             ) r_cmd_burst_cnt <= r_cmd_burst_cnt + 1'b1;
        if( axi_rd_hs&&axi_rlast   ) r_dat_burst_cnt <= r_dat_burst_cnt + 1'b1;
        if( axi_cmd_hs             ) r_cmd_beat_cnt  <= r_cmd_beat_cnt  + axi_arlen+1'b1;
        if( axi_rd_hs              ) r_dat_beat_cnt  <= r_dat_beat_cnt  + 1'b1;
    end
end
`endif

endmodule //end of com_axi_extd_rd

//test point---------------------------------------------------
/*
1. b_bound_only=1, so (i_cfg_max_blen_m1*DW/8)>BOUND_BYTES;
2. u_rainfo_wr_full;
3. i_cfg_max_rdcmd_osd>0, or i_cfg_max_rdcmd_osd=0;
*/