module com_csr_cdc #(
    parameter CSR_AW    = 16, //range=[1::]
    parameter CSR_DW    = 32, //range=[8::8]
    parameter REQ_DEPTH = 8,  //range=[1:256:]
    parameter RD_OSD    = 8,  //range=[1:256:]
    parameter SYNC_S    = 3
)
(
    input  wire                     src_clk                 ,
    input  wire                     src_rst_n               ,
    input  wire                     dst_clk                 ,
    input  wire                     dst_rst_n               ,

    input  wire                     i_src_csr_req_write     ,
    input  wire [CSR_AW-1:0]        i_src_csr_req_addr      ,
    input  wire [CSR_DW-1:0]        i_src_csr_req_wdata     ,
    input  wire [CSR_DW/8-1:0]      i_src_csr_req_wstrb     ,
    input  wire                     i_src_csr_req_valid     ,
    output wire                     o_src_csr_req_ready     ,
    output wire [CSR_DW-1:0]        o_src_csr_rsp_rdata     ,
    output wire                     o_src_csr_rsp_rvalid    ,

    output wire                     o_dst_csr_req_write     ,
    output wire [CSR_AW-1:0]        o_dst_csr_req_addr      ,
    output wire [CSR_DW-1:0]        o_dst_csr_req_wdata     ,
    output wire [CSR_DW/8-1:0]      o_dst_csr_req_wstrb     ,
    output wire                     o_dst_csr_req_valid     ,
    input  wire                     i_dst_csr_req_ready     ,
    input  wire [CSR_DW-1:0]        i_dst_csr_rsp_rdata     ,
    input  wire                     i_dst_csr_rsp_rvalid    //,
);

//localparam-----------------------------------------------------------------
localparam CSR_SW = CSR_DW/8;
localparam REQ_DW = 1+CSR_AW+CSR_DW+CSR_SW;
localparam RD_CW = $clog2(RD_OSD+1);
//signal declare-------------------------------------------------------------
reg  [RD_CW-1:0] r_src_rd_osd_cnt;

wire src_req_hs;
wire src_read_hs;
wire src_rsp_fire;
wire dst_req_hs;
wire src_rd_osd_avl;

//instance signal---
wire                 u_req_i_wr_en;
wire [REQ_DW-1:0]    u_req_i_wr_data;
wire                 u_req_o_wr_full;
wire                 u_req_i_rd_en;
wire [REQ_DW-1:0]    u_req_o_rd_data;
wire                 u_req_o_rd_empty;

wire                 u_rsp_i_wr_en;
wire [CSR_DW-1:0]    u_rsp_i_wr_data;
wire                 u_rsp_o_wr_full;
wire                 u_rsp_i_rd_en;
wire [CSR_DW-1:0]    u_rsp_o_rd_data;
wire                 u_rsp_o_rd_empty;
//statement------------------------------------------------------------------
//output assign---
assign o_src_csr_req_ready = !u_req_o_wr_full &&
                             (i_src_csr_req_write || src_rd_osd_avl);
assign o_src_csr_rsp_rdata = u_rsp_o_rd_data;
assign o_src_csr_rsp_rvalid = !u_rsp_o_rd_empty;

assign {o_dst_csr_req_wstrb,o_dst_csr_req_wdata,
        o_dst_csr_req_addr,o_dst_csr_req_write} = u_req_o_rd_data;
assign o_dst_csr_req_valid = !u_req_o_rd_empty;

//body---
assign src_req_hs = i_src_csr_req_valid && o_src_csr_req_ready;
assign src_read_hs = src_req_hs && !i_src_csr_req_write;
assign src_rsp_fire = o_src_csr_rsp_rvalid;
assign dst_req_hs = o_dst_csr_req_valid && i_dst_csr_req_ready;
assign src_rd_osd_avl = r_src_rd_osd_cnt<RD_CW'(RD_OSD);

always @(posedge src_clk or negedge src_rst_n) begin
    if( !src_rst_n )
        r_src_rd_osd_cnt <= '0;
    else if( src_read_hs || src_rsp_fire )
        r_src_rd_osd_cnt <= r_src_rd_osd_cnt + src_read_hs - src_rsp_fire;
end

//instance-------------------------------------------------------------------
assign u_req_i_wr_en = src_req_hs;
assign u_req_i_wr_data = {i_src_csr_req_wstrb,i_src_csr_req_wdata,
                          i_src_csr_req_addr,i_src_csr_req_write};
assign u_req_i_rd_en = dst_req_hs;
com_async_fifo_reg #(
    .DW     (REQ_DW   ),
    .DEPTH  (REQ_DEPTH),
    .SYNC_S (SYNC_S   )
)u_com_async_fifo_reg_req
(
    .wr_clk        (src_clk         ), //i
    .wr_rst_n      (src_rst_n       ), //i
    .rd_clk        (dst_clk         ), //i
    .rd_rst_n      (dst_rst_n       ), //i
    .i_wr_en       (u_req_i_wr_en   ), //i
    .i_wr_data     (u_req_i_wr_data ), //i
    .o_wr_full     (u_req_o_wr_full ), //o
    .i_rd_en       (u_req_i_rd_en   ), //i
    .o_rd_data     (u_req_o_rd_data ), //o
    .o_rd_empty    (u_req_o_rd_empty), //o
    .o_water_level (                )  //o
);

assign u_rsp_i_wr_en = i_dst_csr_rsp_rvalid;
assign u_rsp_i_wr_data = i_dst_csr_rsp_rdata;
assign u_rsp_i_rd_en = !u_rsp_o_rd_empty;
com_async_fifo_reg #(
    .DW     (CSR_DW   ),
    .DEPTH  (RD_OSD   ),
    .SYNC_S (SYNC_S   )
)u_com_async_fifo_reg_rsp
(
    .wr_clk        (dst_clk         ), //i
    .wr_rst_n      (dst_rst_n       ), //i
    .rd_clk        (src_clk         ), //i
    .rd_rst_n      (src_rst_n       ), //i
    .i_wr_en       (u_rsp_i_wr_en   ), //i
    .i_wr_data     (u_rsp_i_wr_data ), //i
    .o_wr_full     (u_rsp_o_wr_full ), //o
    .i_rd_en       (u_rsp_i_rd_en   ), //i
    .o_rd_data     (u_rsp_o_rd_data ), //o
    .o_rd_empty    (u_rsp_o_rd_empty), //o
    .o_water_level (                )  //o
);

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( RD_OSD>=1 && RD_OSD<=256, "RD_OSD must be in range 1 to 256" )
`COM_SIGNAL_ASSERT( a0, dst_clk,dst_rst_n,i_dst_csr_rsp_rvalid,!u_rsp_o_wr_full, "csr cdc response fifo overflow" )
`COM_SIGNAL_ASSERT( a1, src_clk,src_rst_n,src_rsp_fire,r_src_rd_osd_cnt!='0, "csr cdc response without request" )

endmodule
