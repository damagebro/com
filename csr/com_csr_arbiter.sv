module com_csr_arbiter #(
    parameter REQ_N  = 2,  //range=[1:256:]
    parameter CSR_AW = 16, //range=[1::]
    parameter CSR_DW = 32, //range=[8::8]
    parameter RD_OSD = 8,  //range=[1:256:]
    localparam REQ_N_L2 = $clog2(REQ_N>2?REQ_N:2)
)
(
    input  wire                            clk                  ,
    input  wire                            rst_n                ,
    input  wire                            clear                ,

    input  wire [REQ_N-1:0]                i_rx_csr_req_write   ,
    input  wire [REQ_N-1:0][CSR_AW-1:0]    i_rx_csr_req_addr    ,
    input  wire [REQ_N-1:0][CSR_DW-1:0]    i_rx_csr_req_wdata   ,
    input  wire [REQ_N-1:0][CSR_DW/8-1:0]  i_rx_csr_req_wstrb   ,
    input  wire [REQ_N-1:0]                i_rx_csr_req_valid   ,
    output wire [REQ_N-1:0]                o_rx_csr_req_ready   ,
    output wire [REQ_N-1:0][CSR_DW-1:0]    o_rx_csr_rsp_rdata   ,
    output wire [REQ_N-1:0]                o_rx_csr_rsp_rvalid  ,

    output wire                            o_tx_csr_req_write   ,
    output wire [CSR_AW-1:0]               o_tx_csr_req_addr    ,
    output wire [CSR_DW-1:0]               o_tx_csr_req_wdata   ,
    output wire [CSR_DW/8-1:0]             o_tx_csr_req_wstrb   ,
    output wire                            o_tx_csr_req_valid   ,
    input  wire                            i_tx_csr_req_ready   ,
    input  wire [CSR_DW-1:0]               i_tx_csr_rsp_rdata   ,
    input  wire                            i_tx_csr_rsp_rvalid  //,
);

//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  [REQ_N-1:0]              arb_req_vld;
reg  [REQ_N-1:0]              req_owner_avl;
reg  [REQ_N-1:0][CSR_DW-1:0]  w_rsp_rdata;
wire                          csr_req_hs;
wire                          csr_read_hs;
wire [REQ_N-1:0]              rsp_owner_onehot;

//instance signal---
wire [REQ_N-1:0]    u_arb_i_req_vld;
wire [REQ_N-1:0]    u_arb_o_req_rdy;
wire [REQ_N-1:0]    u_arb_o_gnt_onehot;
wire [REQ_N_L2-1:0] u_arb_o_gnt_idx;
wire                u_arb_o_gnt_vld;
wire                u_arb_i_gnt_rdy;

wire                 u_owner_i_wr_en;
wire [REQ_N_L2-1:0]  u_owner_i_wr_data;
wire                 u_owner_o_wr_full;
wire                 u_owner_i_rd_en;
wire [REQ_N_L2-1:0]  u_owner_o_rd_data;
wire                 u_owner_o_rd_empty;
//statement------------------------------------------------------------------
//output assign---
assign o_rx_csr_req_ready = u_arb_o_req_rdy & req_owner_avl;
assign o_rx_csr_rsp_rdata = w_rsp_rdata;
assign o_rx_csr_rsp_rvalid = i_tx_csr_rsp_rvalid && !u_owner_o_rd_empty ?
                             rsp_owner_onehot : '0;

assign o_tx_csr_req_write = i_rx_csr_req_write[u_arb_o_gnt_idx];
assign o_tx_csr_req_addr = i_rx_csr_req_addr[u_arb_o_gnt_idx];
assign o_tx_csr_req_wdata = i_rx_csr_req_wdata[u_arb_o_gnt_idx];
assign o_tx_csr_req_wstrb = i_rx_csr_req_wstrb[u_arb_o_gnt_idx];
assign o_tx_csr_req_valid = u_arb_o_gnt_vld;

//body---
always @* begin
    arb_req_vld = '0;
    req_owner_avl = '0;
    w_rsp_rdata = '0;
    for( int i=0; i<REQ_N; i=i+1 ) begin
        w_rsp_rdata[i] = i_tx_csr_rsp_rdata;
        req_owner_avl[i] = i_rx_csr_req_write[i] || !u_owner_o_wr_full;
        arb_req_vld[i] = i_rx_csr_req_valid[i] && req_owner_avl[i];
    end
end

assign csr_req_hs = o_tx_csr_req_valid && i_tx_csr_req_ready;
assign csr_read_hs = csr_req_hs && !o_tx_csr_req_write;
assign rsp_owner_onehot = REQ_N'(1'b1) << u_owner_o_rd_data;

//instance-------------------------------------------------------------------
assign u_arb_i_req_vld = arb_req_vld;
assign u_arb_i_gnt_rdy = i_tx_csr_req_ready;
com_arbiter_rr #(
    .REQ_N (REQ_N)
)u_com_arbiter_rr_req
(
    .clk          (clk                 ), //i
    .rst_n        (rst_n               ), //i
    .clear        (clear               ), //i
    .i_req_vld    (u_arb_i_req_vld     ), //i
    .o_req_rdy    (u_arb_o_req_rdy     ), //o
    .o_gnt_onehot (u_arb_o_gnt_onehot  ), //o
    .o_gnt_idx    (u_arb_o_gnt_idx     ), //o
    .o_gnt_vld    (u_arb_o_gnt_vld     ), //o
    .i_gnt_rdy    (u_arb_i_gnt_rdy     )  //i
);

assign u_owner_i_wr_en = csr_read_hs;
assign u_owner_i_wr_data = u_arb_o_gnt_idx;
assign u_owner_i_rd_en = i_tx_csr_rsp_rvalid && !u_owner_o_rd_empty;
com_sync_fifo_reg #(
    .DW    (REQ_N_L2),
    .DEPTH (RD_OSD  )
)u_com_sync_fifo_reg_owner
(
    .clk           (clk               ), //i
    .rst_n         (rst_n             ), //i
    .clear         (clear             ), //i
    .i_wr_en       (u_owner_i_wr_en   ), //i
    .i_wr_data     (u_owner_i_wr_data ), //i
    .o_wr_full     (u_owner_o_wr_full ), //o
    .i_rd_en       (u_owner_i_rd_en   ), //i
    .o_rd_data     (u_owner_o_rd_data ), //o
    .o_rd_empty    (u_owner_o_rd_empty), //o
    .o_water_level (                  )  //o
);

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( RD_OSD>=1 && RD_OSD<=256, "RD_OSD must be in range 1 to 256" )
`COM_SIGNAL_ASSERT_LITE( a0, i_tx_csr_rsp_rvalid,!u_owner_o_rd_empty, "csr arbiter response without owner" )

endmodule
