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

`ifndef com_emi_extd_wr_v
`define com_emi_extd_wr_v
module com_emi_extd_wr #( parameter
    AW = 32  ,
    DW = 128 ,
    LW = 32  ,
    RAM_DEPTH = 256//,  //max_burst_len * max_outstanding_num;
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
`COM_DFT_IF                     dft_cfg             ,
//cfg&status---
input  wire [7:0]               max_burst_len       ,
//dp---
input  wire [AW-1:0]            bus_wa_addr         ,
input  wire [LW-1:0]            bus_wa_bytelen      ,
input  wire                     bus_wa_valid        ,
output wire                     bus_wa_ready        ,
input  wire [DW-1:0]            bus_wd_data         ,
input  wire                     bus_wd_valid        ,
output wire                     bus_wd_ready        ,
output wire                     bus_wb_resp         ,
com_emi_if.usr_wch_tx           emi_usr_wrif        //,
);
//localparam-----------------------------------------------------------------
localparam SW = DW/8;
localparam SW_L2 = $clog2(SW);
localparam MAX_OSD = 16;

localparam RAM_DW    = DW;
localparam RAM_ONE_DEPTH = RAM_DEPTH/2;
localparam RAM_ONE_AW= $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2);
localparam TOL_AW =$clog2( RAM_DEPTH+3+3 ); //ram_depth+in_depth>=3+out_depth>=3;
//reg  declare---------------------------------------------------------------
reg  rc_busy;
reg  [15:0] rc_wa_cnt;
reg  [15:0] rc_wd_cnt; //wd_rx_cnt
reg  [15:0] rc_wd_tx_cnt; //wd_tx_cnt
//wire declare---------------------------------------------------------------
wire [15:0] max_burst_bytelen = (max_burst_len+1) * SW;

wire [AW-1:0] emi_awaddr  ;
wire [7:0]    emi_awlen   ;
wire          emi_awvalid ;
wire          emi_awready ;
wire [DW-1:0] emi_wdata   ;
wire [SW-1:0] emi_wstrb   ;
wire          emi_wlast   ;
wire          emi_wvalid  ;
wire          emi_wready  ;
wire          emi_bvalid  ;
assign emi_usr_wrif.emi_awaddr  = emi_awaddr ;
assign emi_usr_wrif.emi_awlen   = emi_awlen  ;
assign emi_usr_wrif.emi_awvalid = emi_awvalid;
assign emi_awready = emi_usr_wrif.emi_awready;
assign emi_usr_wrif.emi_wdata  = emi_wdata ;
assign emi_usr_wrif.emi_wstrb  = emi_wstrb ;
assign emi_usr_wrif.emi_wlast  = emi_wlast ;
assign emi_usr_wrif.emi_wvalid = emi_wvalid;
assign emi_wready = emi_usr_wrif.emi_wready;
assign emi_bvalid = emi_usr_wrif.emi_bvalid;

// wire [UW-1:0] emi_awuser  ;//= emi_usr_wrif.emi_awuser ;
// wire [UW-1:0] emi_wuser   ;//= emi_usr_wrif.emi_wuser  ;
// wire [UW-1:0] emi_buser   ;//= emi_usr_wrif.emi_buser  ;
//statement------------------------------------------------------------------

//split+addr---
wire bus_wa_hs = bus_wa_valid && bus_wa_ready;
wire emi_wa_hs = emi_awvalid && emi_awready;
reg  rc_first_split_flag;
reg  [AW-1:0] rc_addr;
reg  [LW-1:0] rc_req_bytelen;
wire [LW-0:0] req_bytelen_true = rc_first_split_flag ? (rc_req_bytelen + rc_addr[SW_L2-1:0]) : rc_req_bytelen;
wire [LW-0:0] req_bytelen_nxt_t = req_bytelen_true - max_burst_bytelen;
wire [LW-1:0] req_bytelen_nxt = req_bytelen_nxt_t[LW] ? rc_req_bytelen : req_bytelen_nxt_t;
wire b_last_split_flag = req_bytelen_nxt_t[LW] || req_bytelen_nxt_t[LW-1:0]==LW'(0);
wire [8:0] req_wordlen = req_bytelen_true[LW-1:SW_L2] + |req_bytelen_true[SW_L2-1:0];
wire [7:0] req_once_wordlen_m1 = b_last_split_flag ? req_wordlen-1 : max_burst_len;
wire [8:0] req_once_wordlen = req_once_wordlen_m1+1'b1;
wire ps_wa_last_split = b_last_split_flag && emi_wa_hs;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_busy <= 1'b0;
    else if( clear || ps_wa_last_split )
        rc_busy <= 1'b0;
    else if( bus_wa_hs )
        rc_busy <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_req_bytelen <= 'b0;
    else if( bus_wa_hs )
        rc_req_bytelen <= bus_wa_bytelen;
    else if( emi_wa_hs )
        rc_req_bytelen <= req_bytelen_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_first_split_flag <= 1'b0;
    else if( clear || emi_wa_hs )
        rc_first_split_flag <= 1'b0;
    else if( bus_wa_hs )
        rc_first_split_flag <= 1'b1;
end

//wd fifo & emi_cmd---
wire [TOL_AW-1:0] wd_water_level;
wire              wd_wr_en    = bus_wd_valid && bus_wd_ready;
wire [RAM_DW-1:0] wd_wr_data  = bus_wd_data;
wire              wd_wr_full  ;
wire              wd_rd_en    = emi_wvalid && emi_wready;
wire [RAM_DW-1:0] wd_rd_data  ;
wire              wd_rd_empty ;

wire [1:0]                 ram_cen  ;
wire [1:0]                 ram_we   ;
wire [1:0][RAM_ONE_AW-1:0] ram_addr ;
wire [1:0][RAM_DW-1:0]     ram_din  ;
wire [1:0][RAM_DW-1:0]     ram_qout ;
com_sync_fifo_ram_1p2bank #(
    .DW         ( RAM_DW     ), //8
    .RAM_DEPTH  ( RAM_DEPTH  )//, //4
)zr_com_sync_fifo_ram_1p2bank_wd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wd_wr_en             ), //i
    .wr_data              ( wd_wr_data           ), //i
    .wr_full              ( wd_wr_full           ), //o
    .rd_en                ( wd_rd_en             ), //i
    .rd_data              ( wd_rd_data           ), //o
    .rd_empty             ( wd_rd_empty          ), //o
    .water_level          ( wd_water_level       ), //o

    .ram_cen              ( ram_cen              ), //o
    .ram_we               ( ram_we               ), //o
    .ram_addr             ( ram_addr             ), //o
    .ram_din              ( ram_din              ), //o
    .ram_qout             ( ram_qout             )  //i
);
com_spram_cell #(
    .DATA_W     ( RAM_DW        ), //32
    .DEPTH      ( RAM_ONE_DEPTH )//, //512
)zt_com_spram_cell[1:0]
(
    .clk                  ( clk                  ), //i
    .mem_cfg              ( dft_cfg              ), //i

    .cen                  ( ram_cen              ), //i
    .we                   ( ram_we               ), //i
    .addr                 ( ram_addr             ), //i
    .din                  ( ram_din              ), //i
    .qout                 ( ram_qout             )  //o
);
assign emi_wdata = wd_rd_data;

wire bus_wd_hs = bus_wd_valid && bus_wd_ready;
wire emi_wd_hs = emi_wvalid && emi_wready;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_wa_cnt    <= 'b0;
        rc_wd_cnt    <= 'b0;
        rc_wd_tx_cnt <= 'b0;
    end
    else if( clear )begin
        rc_wa_cnt    <= 'b0;
        rc_wd_cnt    <= 'b0;
        rc_wd_tx_cnt <= 'b0;
    end
    else begin
        if( emi_wa_hs ) rc_wa_cnt <= rc_wa_cnt+req_once_wordlen;
        if( bus_wd_hs ) rc_wd_cnt <= rc_wd_cnt+1'b1;
        if( emi_wd_hs ) rc_wd_tx_cnt <= rc_wd_tx_cnt+1'b1;
    end
end
wire [16:0] wd_minus_wa_t1 = rc_wd_cnt - rc_wa_cnt;
wire [16:0] wd_minus_wa_t2 = (17'h10000+rc_wd_cnt) - rc_wa_cnt;
wire [15:0] wd_minus_wa = wd_minus_wa_t1[16] ? wd_minus_wa_t2 : wd_minus_wa_t1;
wire b_emi_wa_cmd_avl = wd_minus_wa>=16'(req_once_wordlen);

reg  [31:0] rc_len_cnt; //debug only
wire [AW-1:0] addr_nxt = rc_addr + max_burst_bytelen;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_addr <= 'b0;
    else if( bus_wa_hs )
        rc_addr <= bus_wa_addr;
    else if( emi_wa_hs && !b_last_split_flag )
        rc_addr <= addr_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_len_cnt <= 'b0;
    else if( bus_wa_hs )
        rc_len_cnt <= 'b0;
    else if( emi_wa_hs )
        rc_len_cnt <= rc_len_cnt+1;
end
assign emi_awlen = req_once_wordlen_m1;
assign emi_awaddr = rc_addr;
assign emi_awvalid = rc_busy && b_emi_wa_cmd_avl;

//wd last + strb
wire [$clog2(MAX_OSD+1)-1:0] wa_water_level ;
wire                   wa_wr_en    = emi_wa_hs;
wire [2+SW_L2*2+8-1:0] wa_wr_data  = {rc_first_split_flag,b_last_split_flag,req_bytelen_true[SW_L2-1:0],rc_addr[SW_L2-1:0],emi_awlen};
wire                   wa_wr_full  ;
wire                   wa_rd_en    = emi_wd_hs && emi_wlast;
wire [2+SW_L2*2+8-1:0] wa_rd_data  ;
wire                   wa_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 2+SW_L2*2+8 ), //8
    .DEPTH      ( MAX_OSD     )  //4
)zr_com_sync_fifo_reg_wa
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wa_wr_en             ), //i
    .wr_data              ( wa_wr_data           ), //i
    .wr_full              ( wa_wr_full           ), //o
    .rd_en                ( wa_rd_en             ), //i
    .rd_data              ( wa_rd_data           ), //o
    .rd_empty             ( wa_rd_empty          ), //o
    .water_level          ( wa_water_level       )  //o
);
// wire [7:0] wd_split_wordlen = wa_rd_data[0+:8];
wire wd_b_fst_split_flag;
wire wd_b_lst_split_flag;
wire [SW_L2-1:0] wd_bytelen_lo ;
wire [SW_L2-1:0] wd_addr_lo    ;
wire [7:0] wd_split_wordlen;
assign {wd_b_fst_split_flag,wd_b_lst_split_flag,wd_bytelen_lo,wd_addr_lo,wd_split_wordlen} = wa_rd_data;

reg  [7:0] rc_wd_wordlen_cnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_wd_wordlen_cnt <= 'b0;
    else if( clear || (emi_wd_hs && emi_wlast) )
        rc_wd_wordlen_cnt <= 'b0;
    else if( emi_wd_hs )
        rc_wd_wordlen_cnt <= rc_wd_wordlen_cnt+1'b1;
end
assign emi_wlast =emi_wvalid && rc_wd_wordlen_cnt==wd_split_wordlen;
assign emi_wvalid = !wd_rd_empty && !wa_rd_empty;
assign bus_wa_ready = !rc_busy;

wire b_first_strb_flag = wd_b_fst_split_flag && rc_wd_wordlen_cnt==8'b0;
wire b_last_strb_flag = wd_b_lst_split_flag && emi_wlast;
wire [SW_L2-1:0] addr_lo = wd_addr_lo;
wire [SW_L2-1:0] lst_addr_lo = wd_bytelen_lo;
wire [SW-1:0] strb_nrm = {SW{1'b1}};
wire [SW-1:0] strb_fst_t = (1<<addr_lo)-1;
wire [SW-1:0] strb_lst_t = (1<<lst_addr_lo)-1;
wire [SW-1:0] strb_fst = !(|addr_lo) ? strb_nrm : ~strb_fst_t;
wire [SW-1:0] strb_lst = !(|lst_addr_lo) ? strb_nrm : strb_lst_t;
assign emi_wstrb = b_first_strb_flag&&b_last_strb_flag ? strb_fst&strb_lst : b_first_strb_flag ? strb_fst : b_last_strb_flag ? strb_lst : strb_nrm;

//resp---
wire [$clog2(MAX_OSD+4+1)-1:0] wb_water_level ;
wire         wb_wr_en    = emi_wa_hs;
wire [1-1:0] wb_wr_data  = b_last_split_flag;
wire         wb_wr_full  ;
wire         wb_rd_en    = emi_bvalid;
wire [1-1:0] wb_rd_data  ;
wire         wb_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 1        ), //8
    .DEPTH      ( MAX_OSD+4)  //4
)zr_com_sync_fifo_reg_wb
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wb_wr_en             ), //i
    .wr_data              ( wb_wr_data           ), //i
    .wr_full              ( wb_wr_full           ), //o
    .rd_en                ( wb_rd_en             ), //i
    .rd_data              ( wb_rd_data           ), //o
    .rd_empty             ( wb_rd_empty          ), //o
    .water_level          ( wb_water_level       )  //o
);
assign bus_wb_resp = emi_bvalid && !wb_rd_empty && wb_rd_data;
assign bus_wd_ready = !wd_wr_full && !wa_wr_full && !wb_wr_full;

//debug-----------------------------
reg  [31:0] dbg_bus_wa_req_cnt;
reg  [31:0] dbg_bus_wb_resp_cnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        dbg_bus_wa_req_cnt <= 'b0;
        dbg_bus_wb_resp_cnt<= 'b0;
    end
    else if( clear )begin
        dbg_bus_wa_req_cnt <= 'b0;
        dbg_bus_wb_resp_cnt<= 'b0;
    end
    else begin
        if( bus_wa_hs   ) dbg_bus_wa_req_cnt  <= dbg_bus_wa_req_cnt+1;
        if( bus_wb_resp ) dbg_bus_wb_resp_cnt <= dbg_bus_wb_resp_cnt+1;
    end
end

endmodule //end of com_emi_extd_wr
`endif //end of com_emi_extd_wr_v

//wa_fifo, depth=4;
//wa_fifo->wa_split -> wait wd_fifo_cnt>=burst_len -> wa_req+wd_req -> wb;