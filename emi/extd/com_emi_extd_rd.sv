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

`ifndef com_emi_extd_rd_v
`define com_emi_extd_rd_v
module com_emi_extd_rd #( parameter
    AW = 32  ,
    DW = 128 ,
    LW = 32  ,
    RAM_DEPTH = 256//,  //max_burst_len * max_outstanding_num;
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
`COM_SYS_IF                     sys_cfg             ,
//cfg&status---
input  wire [7:0]               max_burst_len       ,
input  wire                     rd_buf_bypass       ,
//dp---
input  wire [AW-1:0]            bus_ra_addr         ,
input  wire [LW-1:0]            bus_ra_bytelen      ,
input  wire                     bus_ra_valid        ,
output wire                     bus_ra_ready        ,
output wire [DW-1:0]            bus_rd_data         ,
output wire                     bus_rd_valid        ,
input  wire                     bus_rd_ready        ,
output wire                     bus_rd_done         ,
com_emi_if.usr_rch_tx           emi_usr_rdif        //,
);
//localparam-----------------------------------------------------------------
localparam SW = DW/8;
localparam SW_L2 = $clog2(SW);
localparam MAX_OSD = 16;

localparam RAM_DW    = DW;
localparam RAM_ONE_DEPTH = RAM_DEPTH/2;
localparam RAM_ONE_AW= $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2);
localparam TOL_AW =$clog2( RAM_DEPTH+3 +1 ); //total_depth = ram_depth+out_depth;
//reg  declare---------------------------------------------------------------
reg  rc_busy;
reg  [15:0] rc_ra_cnt; //emi ra cnt
reg  [15:0] rc_rd_cnt; //bus rd cnt
reg  [15:0] rc_rd_rx_cnt; //emi rd cnt, debug only
//wire declare---------------------------------------------------------------
wire [15:0] max_burst_bytelen = (max_burst_len+1) * SW; //spyglass disable W164b

wire [AW-1:0] emi_araddr  ;
wire [7:0]    emi_arlen   ;
wire          emi_arvalid ;
wire          emi_arready ;
wire [DW-1:0] emi_rdata   ;
wire          emi_rlast   ;
wire          emi_rvalid  ;
wire          emi_rready  = 1'b1;
assign emi_usr_rdif.emi_araddr  = emi_araddr ;
assign emi_usr_rdif.emi_arlen   = emi_arlen  ;
assign emi_usr_rdif.emi_arvalid = emi_arvalid;
assign emi_arready = emi_usr_rdif.emi_arready;
assign emi_rdata   = emi_usr_rdif.emi_rdata  ;
assign emi_rlast   = emi_usr_rdif.emi_rlast  ;
assign emi_rvalid  = emi_usr_rdif.emi_rvalid ;
// assign emi_usr_rdif.emi_rready  = emi_rready ;
// wire [UW-1:0] emi_aruser  ;//= emi_usr_rdif.emi_aruser ;
// wire [UW-1:0] emi_ruser   ;//= emi_usr_rdif.emi_ruser  ;
assign emi_usr_rdif.emi_aruser = 'b0;
//statement------------------------------------------------------------------

//split+addr---
wire bus_ra_hs = bus_ra_valid && bus_ra_ready;
wire emi_ra_hs = emi_arvalid && emi_arready;
reg  rc_first_split_flag;
reg  [AW-1:0] rc_addr;
reg  [LW-1:0] rc_req_bytelen;
wire [LW-0:0] req_bytelen_true = rc_first_split_flag ? (rc_req_bytelen + rc_addr[SW_L2-1:0]) : {1'b0,rc_req_bytelen}; //spyglass disable W164b
wire [LW-0:0] req_bytelen_nxt_t = req_bytelen_true - max_burst_bytelen;
wire [LW-1:0] req_bytelen_nxt = req_bytelen_nxt_t[LW] ? rc_req_bytelen : req_bytelen_nxt_t;
wire b_last_split_flag = req_bytelen_nxt_t[LW] || req_bytelen_nxt_t[LW-1:0]==LW'(0);
wire [8:0] req_wordlen = req_bytelen_true[LW-1:SW_L2] + |req_bytelen_true[SW_L2-1:0];
wire [7:0] req_once_wordlen_m1 = b_last_split_flag ? req_wordlen-1 : max_burst_len;
wire [8:0] req_once_wordlen = req_once_wordlen_m1+1'b1;  //spyglass disable W164b
wire ps_ra_last_split = b_last_split_flag && emi_ra_hs;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_busy <= 1'b0;
    else if( clear || ps_ra_last_split )
        rc_busy <= 1'b0;
    else if( bus_ra_hs )
        rc_busy <= 1'b1;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_req_bytelen <= 'b0;
    else if( bus_ra_hs )
        rc_req_bytelen <= bus_ra_bytelen;
    else if( emi_ra_hs )
        rc_req_bytelen <= req_bytelen_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_first_split_flag <= 1'b0;
    else if( clear || emi_ra_hs )
        rc_first_split_flag <= 1'b0;
    else if( bus_ra_hs )
        rc_first_split_flag <= 1'b1;
end

//rd fifo & emi_cmd---
wire [TOL_AW-1:0] rd_water_level;
wire              rd_wr_en    = rd_buf_bypass ? 1'b0 : (emi_rvalid && emi_rready);
wire [RAM_DW-1:0] rd_wr_data  = emi_rdata;
wire              rd_wr_full  ;
wire              rd_rd_en    = rd_buf_bypass ? 1'b0 : (bus_rd_valid && bus_rd_ready);
wire [RAM_DW-1:0] rd_rd_data  ;
wire              rd_rd_empty ;

wire [1:0]                 ram_cen  ;
wire [1:0]                 ram_we   ;
wire [1:0][RAM_ONE_AW-1:0] ram_addr ;
wire [1:0][RAM_DW-1:0]     ram_din  ;
wire [1:0][RAM_DW-1:0]     ram_qout ;
com_sync_fifo_ram_1p2bank #(
    .DW         ( RAM_DW     ), //8
    .RAM_DEPTH  ( RAM_DEPTH  )//, //4
)zr_com_sync_fifo_ram_1p2bank_rd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( rd_wr_en             ), //i
    .wr_data              ( rd_wr_data           ), //i
    .wr_full              ( rd_wr_full           ), //o
    .rd_en                ( rd_rd_en             ), //i
    .rd_data              ( rd_rd_data           ), //o
    .rd_empty             ( rd_rd_empty          ), //o
    .water_level          ( rd_water_level       ), //o

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
    .mem_cfg              ( sys_cfg              ), //i

    .cen                  ( ram_cen              ), //i
    .we                   ( ram_we               ), //i
    .addr                 ( ram_addr             ), //i
    .din                  ( ram_din              ), //i
    .qout                 ( ram_qout             )  //o
);

wire bus_rd_hs = bus_rd_valid && bus_rd_ready;
wire emi_rd_hs = emi_rvalid && emi_rready;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_ra_cnt <= 'b0;
        rc_rd_cnt <= 'b0;
        rc_rd_rx_cnt <= 'b0;
    end
    else if( clear )begin
        rc_ra_cnt <= 'b0;
        rc_rd_cnt <= 'b0;
        rc_rd_rx_cnt <= 'b0;
    end
    else begin
        if( emi_ra_hs ) rc_ra_cnt <= rc_ra_cnt+req_once_wordlen;
        if( bus_rd_hs ) rc_rd_cnt <= rc_rd_cnt+1'b1;
        if( emi_rd_hs ) rc_rd_rx_cnt <= rc_rd_rx_cnt+1'b1;
    end
end
wire [16:0] ra_minus_rd_t1 = rc_ra_cnt - rc_rd_cnt; //spyglass disable W164b
wire [16:0] ra_minus_rd_t2 = (17'h10000+rc_ra_cnt) - rc_rd_cnt;
wire [15:0] ra_minus_rd = ra_minus_rd_t1[16] ? ra_minus_rd_t2 : ra_minus_rd_t1;
wire [15:0] rdbuf_rem_num = rd_water_level + 0; //spyglass disable W164b
wire [15:0] otf_cnt = ra_minus_rd; //on the fly counter
wire [16:0] rdbuf_avl_num = rdbuf_rem_num - otf_cnt; //spyglass disable W164b
wire b_emi_ra_cmd_avl_t = rd_buf_bypass ? 1'b1 : rdbuf_avl_num[15:0]>=16'(req_once_wordlen) && !rdbuf_avl_num[16];
wire b_emi_ra_cmd_avl;

reg  [31:0] rc_len_cnt; //debug only
wire [AW-1:0] addr_nxt = rc_addr + max_burst_bytelen;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_addr <= 'b0;
    else if( bus_ra_hs )
        rc_addr <= bus_ra_addr;
    else if( emi_ra_hs && !b_last_split_flag )
        rc_addr <= addr_nxt;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_len_cnt <= 'b0;
    else if( bus_ra_hs )
        rc_len_cnt <= 'b0;
    else if( emi_ra_hs )
        rc_len_cnt <= rc_len_cnt+1;
end
assign emi_arlen = req_once_wordlen_m1;
assign emi_araddr = rc_addr;
assign emi_arvalid = rc_busy && b_emi_ra_cmd_avl;

//rd last
wire [$clog2(MAX_OSD+1)-1:0] ra_water_level ;
wire         ra_wr_en    = emi_ra_hs;
wire [8-0:0] ra_wr_data  = {emi_arlen,b_last_split_flag};
wire         ra_wr_full  ;
wire         ra_rd_en    = emi_rd_hs && emi_rlast;
wire [8-0:0] ra_rd_data  ;
wire         ra_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 8+1      ), //8
    .DEPTH      ( MAX_OSD  )  //4
)zr_com_sync_fifo_reg_ra
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( ra_wr_en             ), //i
    .wr_data              ( ra_wr_data           ), //i
    .wr_full              ( ra_wr_full           ), //o
    .rd_en                ( ra_rd_en             ), //i
    .rd_data              ( ra_rd_data           ), //o
    .rd_empty             ( ra_rd_empty          ), //o
    .water_level          ( ra_water_level       )  //o
);
wire b_rd_last_split_flag = !ra_rd_empty ? ra_rd_data[0] : 1'b0;
wire [7:0] rd_split_wordlen = ra_rd_data[1+:8];
assign b_emi_ra_cmd_avl = b_emi_ra_cmd_avl_t && !ra_wr_full;

reg  [7:0] rc_rd_wordlen_cnt;
wire bus_rlast;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_rd_wordlen_cnt <= 'b0;
    else if( clear || (bus_rd_hs && bus_rlast) )
        rc_rd_wordlen_cnt <= 'b0;
    else if( bus_rd_hs )
        rc_rd_wordlen_cnt <= rc_rd_wordlen_cnt+1'b1;
end
assign bus_rlast = bus_rd_valid && rc_rd_wordlen_cnt==rd_split_wordlen;
assign bus_rd_valid = rd_buf_bypass ? emi_rvalid : !rd_rd_empty;
assign bus_rd_data = rd_buf_bypass ? emi_rdata : rd_rd_data;
assign bus_ra_ready = !rc_busy;
assign bus_rd_done  = b_rd_last_split_flag && bus_rd_hs && rc_rd_wordlen_cnt==rd_split_wordlen;;

//debug-----------------------------
reg  [31:0] dbg_bus_ra_req_cnt;
reg  [31:0] dbg_bus_rd_done_cnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        dbg_bus_ra_req_cnt <= 'b0;
        dbg_bus_rd_done_cnt<= 'b0;
    end
    else if( clear )begin
        dbg_bus_ra_req_cnt <= 'b0;
        dbg_bus_rd_done_cnt<= 'b0;
    end
    else begin
        if( bus_ra_hs   ) dbg_bus_ra_req_cnt  <= dbg_bus_ra_req_cnt+1;
        if( bus_rd_done ) dbg_bus_rd_done_cnt <= dbg_bus_rd_done_cnt+1;
    end
end

endmodule //end of com_emi_extd_rd
`endif //end of com_emi_extd_rd_v

