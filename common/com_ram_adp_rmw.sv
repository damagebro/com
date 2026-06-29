/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/29
*
*  Description:
*  - Convert partial writes to full writes with read-modify-write.
*  - Keep full writes and normal reads as zero-latency handshake paths.
*  - Allow accesses to different addresses while RMW reads are in flight.
*  - Never forward RX reads from internal context or writeback buffers.
*
******************************************************************************/

module com_ram_adp_rmw #( parameter
    AW           = 8,
    DW           = 8,
    STRB_W       = 1,
    RAM_RD_DELAY = 1, //range=[1:16:], fixed TX read response latency
    WR_PRIORITY  = 1  //1: partial write priority, 0: normal read priority
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [AW-1:0]            i_rx_wr_addr        ,
input  wire [DW-1:0]            i_rx_wr_data        ,
input  wire [STRB_W-1:0]        i_rx_wr_vld         ,
output wire                     o_rx_wr_rdy         ,
input  wire [AW-1:0]            i_rx_rd_addr        ,
input  wire                     i_rx_rd_vld         ,
output wire                     o_rx_rd_rdy         ,
output wire                     o_rx_rd_ack         ,
output wire [DW-1:0]            o_rx_rd_data        ,

output wire [AW-1:0]            o_tx_wr_addr        ,
output wire [DW-1:0]            o_tx_wr_data        ,
output wire                     o_tx_wr_vld         ,
input  wire                     i_tx_wr_rdy         ,
output wire [AW-1:0]            o_tx_rd_addr        ,
output wire                     o_tx_rd_vld         ,
input  wire                     i_tx_rd_rdy         ,
input  wire                     i_tx_rd_ack         ,
input  wire [DW-1:0]            i_tx_rd_data        //,
);
//localparam-----------------------------------------------------------------
localparam SUB_DW      = DW/STRB_W;
localparam RMW_DEPTH   = RAM_RD_DELAY+1;
localparam RMW_CW      = $clog2(RMW_DEPTH+1);
localparam RMW_AW      = $clog2(RMW_DEPTH>2 ? RMW_DEPTH : 2);
localparam RMW_INFO_DW = AW+STRB_W+DW;
localparam RMW_WB_DW   = AW+DW;
//signal declare-------------------------------------------------------------
reg  [RMW_DEPTH-1:0]            r_rmw_addr_vld;
reg  [RMW_DEPTH-1:0][AW-1:0]    r_rmw_addr_mem;
reg  [RMW_AW-1:0]               r_rmw_addr_wr_ptr;
reg  [RMW_AW-1:0]               r_rmw_addr_rd_ptr;
reg  [RMW_CW-1:0]               r_rmw_pend_cnt;

reg                             w_wr_addr_busy;
reg                             w_rd_addr_busy;

wire                            tie_wr_priority;
wire [RMW_CW-1:0]               tie_rmw_depth;
wire [RMW_AW-1:0]               tie_rmw_depth_m1;
wire                            wr_req;
wire                            wr_full_req;
wire                            wr_partial_req;
wire                            rmw_slot_avl;
wire                            rmw_rd_req;
wire                            rx_rd_req;
wire                            select_rmw_rd;
wire                            select_rx_rd;
wire                            tx_rd_hs;
wire                            rmw_rd_hs;
wire                            direct_wr_vld;
wire                            rmw_wb_vld;
wire                            rmw_wb_hs;
wire                            rd_rsp_vld;
wire                            rd_rsp_rmw_flag;
wire [AW-1:0]                   rd_rsp_rmw_addr;
wire [STRB_W-1:0]               rd_rsp_rmw_strb;
wire [DW-1:0]                   rd_rsp_rmw_data;
wire [DW-1:0]                   rmw_merge_data;
wire [RMW_AW-1:0]               rmw_addr_wr_ptr_nxt;
wire [RMW_AW-1:0]               rmw_addr_rd_ptr_nxt;
wire [RMW_CW-1:0]               rmw_pend_cnt_nxt;
wire                            rmw_addr_ptr_same;

//instance signal--
wire                            u_rdflag_i_wr_en;
wire                            u_rdflag_i_wr_data;
wire                            u_rdflag_o_wr_full;
wire                            u_rdflag_i_rd_en;
wire                            u_rdflag_o_rd_data;
wire                            u_rdflag_o_rd_empty;
wire [RMW_CW-1:0]               u_rdflag_o_water_level;

wire                            u_rmw_info_i_wr_en;
wire [RMW_INFO_DW-1:0]          u_rmw_info_i_wr_data;
wire                            u_rmw_info_o_wr_full;
wire                            u_rmw_info_i_rd_en;
wire [RMW_INFO_DW-1:0]          u_rmw_info_o_rd_data;
wire                            u_rmw_info_o_rd_empty;
wire [RMW_CW-1:0]               u_rmw_info_o_water_level;

wire                            u_rmw_wb_i_wr_en;
wire [RMW_WB_DW-1:0]            u_rmw_wb_i_wr_data;
wire                            u_rmw_wb_o_wr_full;
wire                            u_rmw_wb_i_rd_en;
wire [RMW_WB_DW-1:0]            u_rmw_wb_o_rd_data;
wire                            u_rmw_wb_o_rd_empty;
wire [RMW_CW-1:0]               u_rmw_wb_o_water_level;
//statement------------------------------------------------------------------
//output assign---
assign o_rx_wr_rdy = wr_full_req ? (direct_wr_vld && i_tx_wr_rdy) :
                     (wr_partial_req ? (select_rmw_rd && i_tx_rd_rdy) : 1'b0);
assign o_rx_rd_rdy = select_rx_rd && i_tx_rd_rdy;
assign o_rx_rd_ack = rd_rsp_vld && !rd_rsp_rmw_flag;
assign o_rx_rd_data = i_tx_rd_data;

assign o_tx_wr_addr = rmw_wb_vld ? u_rmw_wb_o_rd_data[RMW_WB_DW-1-:AW] :
                                   i_rx_wr_addr;
assign o_tx_wr_data = rmw_wb_vld ? u_rmw_wb_o_rd_data[DW-1:0] :
                                   i_rx_wr_data;
assign o_tx_wr_vld = rmw_wb_vld || direct_wr_vld;

assign o_tx_rd_addr = select_rmw_rd ? i_rx_wr_addr : i_rx_rd_addr;
assign o_tx_rd_vld = select_rmw_rd || select_rx_rd;

//body---
assign tie_wr_priority = WR_PRIORITY>0;
assign tie_rmw_depth = RMW_CW'(RMW_DEPTH);
assign tie_rmw_depth_m1 = RMW_AW'(RMW_DEPTH-1);
assign wr_req = |i_rx_wr_vld;
assign wr_full_req = &i_rx_wr_vld;
assign wr_partial_req = wr_req && !wr_full_req;
assign rmw_slot_avl = r_rmw_pend_cnt<tie_rmw_depth || rmw_wb_hs;

assign rmw_rd_req = wr_partial_req && !w_wr_addr_busy &&
                    rmw_slot_avl && !u_rdflag_o_wr_full &&
                    !u_rmw_info_o_wr_full;
assign rx_rd_req = i_rx_rd_vld && !w_rd_addr_busy &&
                   !u_rdflag_o_wr_full;
assign select_rmw_rd = rmw_rd_req && (tie_wr_priority || !rx_rd_req);
assign select_rx_rd = rx_rd_req && (!tie_wr_priority || !rmw_rd_req);
//Every accepted normal read must issue one TX read request.
assign tx_rd_hs = o_tx_rd_vld && i_tx_rd_rdy;
assign rmw_rd_hs = select_rmw_rd && i_tx_rd_rdy;
assign direct_wr_vld = wr_full_req && !w_wr_addr_busy && !rmw_wb_vld;
assign rmw_wb_vld = !u_rmw_wb_o_rd_empty;
assign rmw_wb_hs = rmw_wb_vld && i_tx_wr_rdy;

assign rd_rsp_vld = i_tx_rd_ack && !u_rdflag_o_rd_empty;
assign rd_rsp_rmw_flag = u_rdflag_o_rd_data;
assign rd_rsp_rmw_addr = u_rmw_info_o_rd_data[RMW_INFO_DW-1-:AW];
assign rd_rsp_rmw_strb = u_rmw_info_o_rd_data[DW+STRB_W-1-:STRB_W];
assign rd_rsp_rmw_data = u_rmw_info_o_rd_data[DW-1:0];

assign rmw_addr_wr_ptr_nxt = r_rmw_addr_wr_ptr==tie_rmw_depth_m1 ?
                             '0 : (r_rmw_addr_wr_ptr + 1'b1);
assign rmw_addr_rd_ptr_nxt = r_rmw_addr_rd_ptr==tie_rmw_depth_m1 ?
                             '0 : (r_rmw_addr_rd_ptr + 1'b1);
assign rmw_pend_cnt_nxt = r_rmw_pend_cnt + rmw_rd_hs - rmw_wb_hs;
assign rmw_addr_ptr_same = r_rmw_addr_wr_ptr==r_rmw_addr_rd_ptr;

//Block a request until every older RMW to the same address is written back.
always @* begin
    w_wr_addr_busy = 1'b0;
    w_rd_addr_busy = 1'b0;
    for( int i=0; i<RMW_DEPTH; i++ ) begin
        if( r_rmw_addr_vld[i] ) begin
            if( i_rx_wr_addr==r_rmw_addr_mem[i] )
                w_wr_addr_busy = 1'b1;
            if( i_rx_rd_addr==r_rmw_addr_mem[i] )
                w_rd_addr_busy = 1'b1;
        end
    end
end

//Strobe bit i replaces data bits [i*SUB_DW +: SUB_DW].
for( genvar gi=0; gi<STRB_W; gi++ ) begin:gen_rmw_merge_data
    assign rmw_merge_data[gi*SUB_DW+:SUB_DW] =
        rd_rsp_rmw_strb[gi] ? rd_rsp_rmw_data[gi*SUB_DW+:SUB_DW] :
                              i_tx_rd_data[gi*SUB_DW+:SUB_DW];
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rmw_addr_vld <= '0;
    else if( clear )
        r_rmw_addr_vld <= '0;
    else begin
        if( rmw_rd_hs && rmw_wb_hs && rmw_addr_ptr_same )
            r_rmw_addr_vld[r_rmw_addr_wr_ptr] <= 1'b1;
        else if( rmw_rd_hs && rmw_wb_hs ) begin
            r_rmw_addr_vld[r_rmw_addr_wr_ptr] <= 1'b1;
            r_rmw_addr_vld[r_rmw_addr_rd_ptr] <= 1'b0;
        end
        else if( rmw_rd_hs )
            r_rmw_addr_vld[r_rmw_addr_wr_ptr] <= 1'b1;
        else if( rmw_wb_hs )
            r_rmw_addr_vld[r_rmw_addr_rd_ptr] <= 1'b0;
    end
end

always @(posedge clk) begin
    if( rmw_rd_hs )
        r_rmw_addr_mem[r_rmw_addr_wr_ptr] <= i_rx_wr_addr;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rmw_addr_wr_ptr <= '0;
    else if( clear )
        r_rmw_addr_wr_ptr <= '0;
    else if( rmw_rd_hs )
        r_rmw_addr_wr_ptr <= rmw_addr_wr_ptr_nxt;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rmw_addr_rd_ptr <= '0;
    else if( clear )
        r_rmw_addr_rd_ptr <= '0;
    else if( rmw_wb_hs )
        r_rmw_addr_rd_ptr <= rmw_addr_rd_ptr_nxt;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rmw_pend_cnt <= '0;
    else if( clear )
        r_rmw_pend_cnt <= '0;
    else if( rmw_rd_hs || rmw_wb_hs )
        r_rmw_pend_cnt <= rmw_pend_cnt_nxt;
end

//instance----
assign u_rdflag_i_wr_en = tx_rd_hs;
assign u_rdflag_i_wr_data = select_rmw_rd;
assign u_rdflag_i_rd_en = rd_rsp_vld;
com_sync_fifo_reg #(
    .DW                   ( 1                            ), //8
    .DEPTH                ( RMW_DEPTH                    )  //4
)u_com_sync_fifo_reg_rdflag
(
    .clk                  ( clk                           ), //i
    .rst_n                ( rst_n                         ), //i
    .clear                ( clear                         ), //i

    .i_wr_en              ( u_rdflag_i_wr_en             ), //i
    .i_wr_data            ( u_rdflag_i_wr_data           ), //i
    .o_wr_full            ( u_rdflag_o_wr_full           ), //o
    .i_rd_en              ( u_rdflag_i_rd_en             ), //i
    .o_rd_data            ( u_rdflag_o_rd_data           ), //o
    .o_rd_empty           ( u_rdflag_o_rd_empty          ), //o
    .o_water_level        ( u_rdflag_o_water_level       )  //o
);

assign u_rmw_info_i_wr_en = rmw_rd_hs;
assign u_rmw_info_i_wr_data = {i_rx_wr_addr,i_rx_wr_vld,i_rx_wr_data};
assign u_rmw_info_i_rd_en = rd_rsp_vld && rd_rsp_rmw_flag;
com_sync_fifo_reg #(
    .DW                   ( RMW_INFO_DW                   ), //8
    .DEPTH                ( RMW_DEPTH                     )  //4
)u_com_sync_fifo_reg_rmw_info
(
    .clk                  ( clk                           ), //i
    .rst_n                ( rst_n                         ), //i
    .clear                ( clear                         ), //i

    .i_wr_en              ( u_rmw_info_i_wr_en            ), //i
    .i_wr_data            ( u_rmw_info_i_wr_data          ), //i
    .o_wr_full            ( u_rmw_info_o_wr_full          ), //o
    .i_rd_en              ( u_rmw_info_i_rd_en            ), //i
    .o_rd_data            ( u_rmw_info_o_rd_data          ), //o
    .o_rd_empty           ( u_rmw_info_o_rd_empty         ), //o
    .o_water_level        ( u_rmw_info_o_water_level      )  //o
);

assign u_rmw_wb_i_wr_en = rd_rsp_vld && rd_rsp_rmw_flag;
assign u_rmw_wb_i_wr_data = {rd_rsp_rmw_addr,rmw_merge_data};
assign u_rmw_wb_i_rd_en = rmw_wb_hs;
com_sync_fifo_reg #(
    .DW                   ( RMW_WB_DW                    ), //8
    .DEPTH                ( RMW_DEPTH                    )  //4
)u_com_sync_fifo_reg_rmw_wb
(
    .clk                  ( clk                           ), //i
    .rst_n                ( rst_n                         ), //i
    .clear                ( clear                         ), //i

    .i_wr_en              ( u_rmw_wb_i_wr_en             ), //i
    .i_wr_data            ( u_rmw_wb_i_wr_data           ), //i
    .o_wr_full            ( u_rmw_wb_o_wr_full           ), //o
    .i_rd_en              ( u_rmw_wb_i_rd_en             ), //i
    .o_rd_data            ( u_rmw_wb_o_rd_data           ), //o
    .o_rd_empty           ( u_rmw_wb_o_rd_empty          ), //o
    .o_water_level        ( u_rmw_wb_o_water_level       )  //o
);

//assert---------------------------------------------------------------------
`COM_PARAM_ASSERT( STRB_W>=1 && DW%STRB_W==0, "DW must be divisible by STRB_W" );
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "ram read delay range is [1:16]" );
`COM_PARAM_ASSERT( WR_PRIORITY==0 || WR_PRIORITY==1, "WR_PRIORITY must be 0 or 1" );
`COM_SIGNAL_ASSERT_LITE( a0, i_tx_rd_ack,!u_rdflag_o_rd_empty, "read ack without request flag" );
`COM_SIGNAL_ASSERT_LITE( a1, u_rmw_info_i_rd_en,!u_rmw_info_o_rd_empty, "rmw response without request info" );
`COM_SIGNAL_ASSERT_LITE( a2, u_rmw_wb_i_wr_en,!u_rmw_wb_o_wr_full, "rmw writeback fifo overflow" );

endmodule //end of com_ram_adp_rmw
