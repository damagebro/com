/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/03/14-22:41:25
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_extd_wr #( parameter
    AW          = 32  , //range=[8:64]
    DW          = 128 , //range=[8::2^n]
    EBUS_LW     = 32  , //range=[8:AW] ebus max_burst_bytelen.bit_width;
    LW          = 8   , //range=[1:8], axi  max_burst_wordlen.bit_width;
    UW          = 1   , //range=[1:],  ebus_axusr and axi_axusr, axuser go-though this module;
    BOUND_BYTES = 4096, //range=[DW/8:4096:2^n], addr boundary split bytesize;
    MAX_OSD     = 128 , //range=[1:1024], max axi_cmd outstanding num
    BUF_DEPTH   = 8   //, //range=[1:],  fifo_reg //"to confirm wr_bus perfomance, only 'wd_buffer.water_level>max_burst_len' then send wr_cmd+wr_data to axi_bus", wa_wb_axi_osd=MAX_OSD, and assert(BUF_DEPTH>max_burst_len+2)
)
(
input  wire                     clk                  ,
input  wire                     rst_n                ,
input  wire                     clear                ,
//cfg&status---
input  wire [7:0]               i_cfg_max_blen_m1    ,
//dp---
input  wire [UW-1:0]            ebus_wa_user         ,
input  wire [AW-1:0]            ebus_wa_addr         ,
input  wire [EBUS_LW-1:0]       ebus_wa_bytelen      ,
input  wire                     ebus_wa_valid        , //ebus data_after_addr+data_with_addr+data_before_addr all ok;
output wire                     ebus_wa_ready        ,
input  wire [DW-1:0]            ebus_wd_data         ,
input  wire                     ebus_wd_valid        ,
output wire                     ebus_wd_ready        ,
output wire                     ebus_wb_valid        ,

output wire [AW-1:0]            axi_awaddr           ,
output wire [LW-1:0]            axi_awlen            , //not reg_out, take little timing;
output wire [UW-1:0]            axi_awuser           ,
output wire                     axi_awvalid          , //axi have data_after_addr+data_with_addr;   axi not have data_before_addr;
input  wire                     axi_awready          ,
output wire [DW-1:0]            axi_wdata            ,
output wire [DW/8-1:0]          axi_wstrb            , //not reg_out, take some timing;
output wire                     axi_wlast            , //not reg_out, take some timing;
output wire                     axi_wvalid           ,
input  wire                     axi_wready           ,
input  wire                     axi_bvalid           ,
output wire                     axi_bready           //,  //tie 1
);

//localparam-----------------------------------------------------------------
localparam AXI_LW = LW;
localparam SW = DW/8;
localparam SW_L2 = $clog2(SW);
localparam BOUND_L2 = $clog2(BOUND_BYTES);
localparam BUF_CW = $clog2(BUF_DEPTH+1);
`COM_PARAM_ASSERT( BOUND_BYTES<=4096 || (1<<BOUND_L2)==BOUND_BYTES, "BOUND_BYTES range illegal" );
//signal declare-------------------------------------------------------------
wire ebus_cmd_hs; // = ebus_wa_valid && ebus_wa_ready;
wire axi_cmd_hs ; // = axi_awvalid && axi_awready;
wire ebus_wd_hs ; // = ebus_wd_valid && ebus_wd_ready;
wire axi_wd_hs  ; // = axi_wvalid && axi_wready;
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

reg  [BUF_CW-1:0] r_ebus2axi_wd_cnt;
reg  [BUF_CW-0:0] r_axi_wa2wd_cnt;  //$signed(value), value range = [-1:BUF_DEPTH]
reg  [AXI_LW-1:0] r_axi_len_cnt;
wire              b_axi_wa_cmd_avl;  //ebus_wd over once_burst_len, then axi_wa become avl;
wire              b_axi_wd_send_avl; //axi_wa_cnt>axi_wd_cnt,  to prevent data_before_addr;
wire [SW-1:0]     w_axi_wstrb;
wire              w_axi_wlast;
wire                        u_wafifo_wr_en    ;  //wa2wd fifo
wire [2+SW_L2*2+AXI_LW-1:0] u_wafifo_wr_data  ; //= {r_fst_split_flag,b_lst_split_flag,fst_split_addr_lsb,lst_split_addr_lsb,axi_awlen};
wire                        u_wafifo_wr_full  ;
wire                        u_wafifo_rd_en    ;
wire [2+SW_L2*2+AXI_LW-1:0] u_wafifo_rd_data  ;
wire                        u_wafifo_rd_empty ;
wire                        u_wdfifo_wr_en    ;
wire [DW-1:0]               u_wdfifo_wr_data  ;
wire                        u_wdfifo_wr_full  ;
wire                        u_wdfifo_rd_en    ;
wire [DW-1:0]               u_wdfifo_rd_data  ;
wire                        u_wdfifo_rd_empty ;
wire                        u_wa2wb_fifo_wr_en    ;
wire [1-1:0]                u_wa2wb_fifo_wr_data  ; //each bytelen is_split_last;
wire                        u_wa2wb_fifo_wr_full  ;
wire                        u_wa2wb_fifo_rd_en    ;
wire [1-1:0]                u_wa2wb_fifo_rd_data  ;
wire                        u_wa2wb_fifo_rd_empty ;
//statement------------------------------------------------------------------
assign ebus_cmd_hs = ebus_wa_valid && ebus_wa_ready;
assign axi_cmd_hs  = axi_awvalid && axi_awready;
assign ebus_wd_hs  = ebus_wd_valid && ebus_wd_ready;
assign axi_wd_hs   = axi_wvalid && axi_wready;
assign ebus_bytelen_modify = ebus_wa_bytelen + ebus_wa_addr[SW_L2-1:0]; //assert( ebus_bytelen_modify[EBUS_LW]==1'b0 )

assign axi_awaddr = r_addr; //only first split maybe not align to word(DW/8), the next addr all align to word;
assign axi_awlen  = fnl_wordlen_m1;
assign axi_awuser = r_user;
assign axi_awvalid= r_split_busy && b_axi_wa_cmd_avl && !u_wafifo_wr_full && !u_wa2wb_fifo_wr_full;
assign axi_wdata = u_wdfifo_rd_data;
assign axi_wstrb = w_axi_wstrb;
assign axi_wlast = w_axi_wlast;
assign axi_wvalid= !u_wdfifo_rd_empty && b_axi_wd_send_avl && (!u_wafifo_rd_empty || b_axi_wa_cmd_avl);
assign axi_bready= 1'b1;
assign ebus_wa_ready = !r_split_busy || (r_split_busy&&b_lst_split_flag&&axi_cmd_hs);
assign ebus_wd_ready = !u_wdfifo_wr_full;
assign ebus_wb_valid = axi_bvalid && !u_wa2wb_fifo_rd_empty && u_wa2wb_fifo_rd_data==1'b1;
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
        r_addr <= ebus_wa_addr;
    else if( axi_cmd_hs && !b_lst_split_flag )
        r_addr <= fnl_addr_nxt;
end
always @(posedge clk)begin
    if( ebus_cmd_hs )
        r_user <= ebus_wa_user;
end

//2. wa_fifo, wd_fifo, wa_cnt+wd_cnt, wd_strb+wd_last------
wire [AXI_LW-0:0] tmp_axi_len_p1 = axi_cmd_hs ? (axi_awlen+1'b1) : '0;
wire [BUF_CW-0:0] tmp_axi_wa2wd_cnt = $signed(r_axi_wa2wd_cnt) + $signed({1'b0,tmp_axi_len_p1}) - $signed({1'b0, axi_wd_hs});
assign b_axi_wa_cmd_avl = r_ebus2axi_wd_cnt>=BUF_CW'(fnl_wordlen);   //longest timing path;
assign b_axi_wd_send_avl= r_axi_wa2wd_cnt[BUF_CW]==1'b0; //r_axi_wa2wd_cnt>0
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )begin
        r_ebus2axi_wd_cnt <= '0;
        r_axi_wa2wd_cnt   <= '0;
    end
    else if( clear )begin
        r_ebus2axi_wd_cnt <= '0;
        r_axi_wa2wd_cnt   <= '0;
    end
    else begin
        if( ebus_wd_hs||axi_cmd_hs ) r_ebus2axi_wd_cnt <= r_ebus2axi_wd_cnt+ebus_wd_hs-tmp_axi_len_p1;
        if( axi_cmd_hs||axi_wd_hs  ) r_axi_wa2wd_cnt   <= tmp_axi_wa2wd_cnt;
    end
end

//wd_last + wd_strb;
wire              wa2wd_fst_split_flag;
wire              wa2wd_lst_split_flag;
wire [SW_L2-1:0]  wa2wd_fst_split_addr_lsb;
wire [SW_L2-1:0]  wa2wd_lst_split_addr_lsb;
wire [AXI_LW-1:0] wa2wd_axi_awlen;
assign {wa2wd_fst_split_flag,wa2wd_lst_split_flag,wa2wd_fst_split_addr_lsb,wa2wd_lst_split_addr_lsb,wa2wd_axi_awlen} = u_wafifo_rd_data;

wire              strb_fst_split_flag = u_wafifo_rd_empty&&b_axi_wa_cmd_avl ? r_fst_split_flag : wa2wd_fst_split_flag;
wire              strb_lst_split_flag = u_wafifo_rd_empty&&b_axi_wa_cmd_avl ? b_lst_split_flag : wa2wd_lst_split_flag;
wire              strb_fst_data_flag  = strb_fst_split_flag && r_axi_len_cnt=='0;
wire              strb_lst_data_flag  = strb_lst_split_flag && axi_wlast;
wire [SW_L2-1:0]  strb_fst_addr_lsb   = u_wafifo_rd_empty&&b_axi_wa_cmd_avl ? fst_split_addr_lsb : wa2wd_fst_split_addr_lsb;
wire [SW_L2-1:0]  strb_lst_addr_lsb   = u_wafifo_rd_empty&&b_axi_wa_cmd_avl ? lst_split_addr_lsb : wa2wd_lst_split_addr_lsb;
wire [AXI_LW-1:0] strb_axi_awlen      = u_wafifo_rd_empty&&b_axi_wa_cmd_avl ? axi_awlen : wa2wd_axi_awlen;
wire [SW-1:0] strb_nrm   = {SW{1'b1}};
wire [SW-1:0] strb_fst_t = ( SW'('b1)<<strb_fst_addr_lsb )-1'b1;
wire [SW-1:0] strb_lst_t = ( SW'('b1)<<strb_lst_addr_lsb )-1'b1;
wire [SW-1:0] strb_fst   = !(|strb_fst_addr_lsb) ? strb_nrm : ~strb_fst_t;
wire [SW-1:0] strb_lst   = !(|strb_lst_addr_lsb) ? strb_nrm :  strb_lst_t;
assign w_axi_wstrb = strb_fst_data_flag&&strb_lst_data_flag ? strb_fst&strb_lst : strb_fst_data_flag ? strb_fst : strb_lst_data_flag ? strb_lst : strb_nrm;
assign w_axi_wlast = axi_wvalid && r_axi_len_cnt>=strb_axi_awlen;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_axi_len_cnt  <= '0;
    else if( clear || axi_wd_hs&&axi_wlast )
        r_axi_len_cnt  <= '0;
    else if( axi_wd_hs )
        r_axi_len_cnt  <= r_axi_len_cnt+1'b1;
end

assign u_wafifo_wr_en   = axi_cmd_hs && !((r_axi_wa2wd_cnt[BUF_CW]&&axi_awlen=='0) || (r_axi_wa2wd_cnt[BUF_CW-1:0]=='0 && axi_wd_hs&&axi_wlast));  //r_axi_wa2wd_cnt[BUF_CW] mean r_axi_wa2wd_cnt<0,
assign u_wafifo_wr_data = {r_fst_split_flag,b_lst_split_flag,fst_split_addr_lsb,lst_split_addr_lsb,axi_awlen};
assign u_wafifo_rd_en   = axi_wd_hs&&axi_wlast && !u_wafifo_rd_empty;
assign u_wdfifo_wr_en   = ebus_wd_hs;
assign u_wdfifo_wr_data = ebus_wd_data;
assign u_wdfifo_rd_en   = axi_wd_hs;
com_sync_fifo_reg #(
    .DW         ( 2+SW_L2*2+AXI_LW ), //8
    .DEPTH      ( 4                )  //4
)zr_com_sync_fifo_reg_wafifo
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( u_wafifo_wr_en       ), //i
    .wr_data              ( u_wafifo_wr_data     ), //i
    .wr_full              ( u_wafifo_wr_full     ), //o
    .rd_en                ( u_wafifo_rd_en       ), //i
    .rd_data              ( u_wafifo_rd_data     ), //o
    .rd_empty             ( u_wafifo_rd_empty    ), //o
    .water_level          (                      )  //o
);
com_sync_fifo_reg #(
    .DW         ( DW          ), //8
    .DEPTH      ( BUF_DEPTH   )  //4
)zr_com_sync_fifo_reg_wdfifo
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( u_wdfifo_wr_en       ), //i
    .wr_data              ( u_wdfifo_wr_data     ), //i
    .wr_full              ( u_wdfifo_wr_full     ), //o
    .rd_en                ( u_wdfifo_rd_en       ), //i
    .rd_data              ( u_wdfifo_rd_data     ), //o
    .rd_empty             ( u_wdfifo_rd_empty    ), //o
    .water_level          (                      )  //o
);

//3. wb_resp, outstanding----
assign u_wa2wb_fifo_wr_en   = axi_cmd_hs;
assign u_wa2wb_fifo_wr_data = b_lst_split_flag;
assign u_wa2wb_fifo_rd_en   = axi_bvalid && axi_bready;
com_sync_fifo_reg #(
    .DW         ( 1        ), //8
    .DEPTH      ( MAX_OSD+0)  //4
)zr_com_sync_fifo_reg_wa2wb_fifo
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( u_wa2wb_fifo_wr_en   ), //i
    .wr_data              ( u_wa2wb_fifo_wr_data ), //i
    .wr_full              ( u_wa2wb_fifo_wr_full ), //o
    .rd_en                ( u_wa2wb_fifo_rd_en   ), //i
    .rd_data              ( u_wa2wb_fifo_rd_data ), //o
    .rd_empty             ( u_wa2wb_fifo_rd_empty), //o
    .water_level          (                      )  //o
);

//assert----------------------------------
`COM_SIGNAL_ASSERT( a0, clk,rst_n,ebus_cmd_hs,(cfg_max_blen<=tie_axi_wordlen || tie_bound_wordlen<=tie_axi_wordlen) , "AXI_LW range can't split to (i_cfg_max_blen_m1, BOUND_BYTES)"  );
`COM_SIGNAL_ASSERT( a1, clk,rst_n,ebus_cmd_hs,(ebus_bytelen_modify[EBUS_LW]==1'b0) , "EBUS_LW range not enough, change to original_value+1" );

//debug----------------------------------
`ifdef COM_AXI_DEBUG
reg  [31:0] r_cmd_burst_cnt;
reg  [31:0] r_dat_burst_cnt;
reg  [31:0] r_rsp_burst_cnt;
reg  [31:0] r_cmd_beat_cnt ;
reg  [31:0] r_dat_beat_cnt ;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )begin
        r_cmd_burst_cnt <= '0;
        r_dat_burst_cnt <= '0;
        r_rsp_burst_cnt <= '0;
        r_cmd_beat_cnt  <= '0;
        r_dat_beat_cnt  <= '0;
    end
    else begin
        if( axi_cmd_hs             ) r_cmd_burst_cnt <= r_cmd_burst_cnt + 1'b1;
        if( axi_wd_hs&&axi_wlast   ) r_dat_burst_cnt <= r_dat_burst_cnt + 1'b1;
        if( axi_bvalid&&axi_bready ) r_rsp_burst_cnt <= r_rsp_burst_cnt + 1'b1;
        if( axi_cmd_hs             ) r_cmd_beat_cnt  <= r_cmd_beat_cnt  + axi_awlen+1'b1;
        if( axi_wd_hs              ) r_dat_beat_cnt  <= r_dat_beat_cnt  + 1'b1;
    end
end
`endif

endmodule

//test point---------------------------------------------------
/*
1. DW=8, DW=1024;
2. b_bound_only=1, so (i_cfg_max_blen_m1*DW/8)>BOUND_BYTES;
3. corner:
(1) DW=8, BOUND_BYTES=1;
(2) DW=1024, BOUND_BYTES=128;
(3) DW=1024, BOUND_BYTES=512; i_cfg_max_blen_m1=[0:4];
4. assert check
(1) AXI_LW=2, when DW=1024, i_cfg_max_blen_m1=4, BOUND_BYTES=1024;
5. u_wafifo_wr_full;
6. u_wa2wb_fifo_wr_full,  wa->wb osd<=MAX_OSD;
*/