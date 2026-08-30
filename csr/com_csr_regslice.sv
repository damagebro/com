module com_csr_regslice #(
    parameter CSR_AW    = 16, //range=[1::]
    parameter CSR_DW    = 32, //range=[8::8]
    parameter REQ_DEPTH = 2,  //range=[2::]
    parameter RSP_DEPTH = 2   //range=[2::]
)
(
    input  wire                     clk                 ,
    input  wire                     rst_n               ,
    input  wire                     clear               ,

    input  wire                     i_rx_csr_req_write  ,
    input  wire [CSR_AW-1:0]        i_rx_csr_req_addr   ,
    input  wire [CSR_DW-1:0]        i_rx_csr_req_wdata  ,
    input  wire [CSR_DW/8-1:0]      i_rx_csr_req_wstrb  ,
    input  wire                     i_rx_csr_req_valid  ,
    output wire                     o_rx_csr_req_ready  ,
    output wire [CSR_DW-1:0]        o_rx_csr_rsp_rdata  ,
    output wire                     o_rx_csr_rsp_rvalid ,

    output wire                     o_tx_csr_req_write  ,
    output wire [CSR_AW-1:0]        o_tx_csr_req_addr   ,
    output wire [CSR_DW-1:0]        o_tx_csr_req_wdata  ,
    output wire [CSR_DW/8-1:0]      o_tx_csr_req_wstrb  ,
    output wire                     o_tx_csr_req_valid  ,
    input  wire                     i_tx_csr_req_ready  ,
    input  wire [CSR_DW-1:0]        i_tx_csr_rsp_rdata  ,
    input  wire                     i_tx_csr_rsp_rvalid //,
);

//localparam-----------------------------------------------------------------
localparam CSR_SW = CSR_DW/8;
localparam REQ_DW = 1+CSR_AW+CSR_DW+CSR_SW;
//signal declare-------------------------------------------------------------
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
assign o_rx_csr_req_ready = !u_req_o_wr_full;
assign o_rx_csr_rsp_rdata = u_rsp_o_rd_data;
assign o_rx_csr_rsp_rvalid = !u_rsp_o_rd_empty;

assign {o_tx_csr_req_wstrb,o_tx_csr_req_wdata,
        o_tx_csr_req_addr,o_tx_csr_req_write} = u_req_o_rd_data;
assign o_tx_csr_req_valid = !u_req_o_rd_empty;

//instance-------------------------------------------------------------------
assign u_req_i_wr_en = i_rx_csr_req_valid && o_rx_csr_req_ready;
assign u_req_i_wr_data = {i_rx_csr_req_wstrb,i_rx_csr_req_wdata,
                          i_rx_csr_req_addr,i_rx_csr_req_write};
assign u_req_i_rd_en = o_tx_csr_req_valid && i_tx_csr_req_ready;
com_sync_fifo_reg #(
    .DW    (REQ_DW   ),
    .DEPTH (REQ_DEPTH)
)u_com_sync_fifo_reg_req
(
    .clk           (clk             ), //i
    .rst_n         (rst_n           ), //i
    .clear         (clear           ), //i
    .i_wr_en       (u_req_i_wr_en   ), //i
    .i_wr_data     (u_req_i_wr_data ), //i
    .o_wr_full     (u_req_o_wr_full ), //o
    .i_rd_en       (u_req_i_rd_en   ), //i
    .o_rd_data     (u_req_o_rd_data ), //o
    .o_rd_empty    (u_req_o_rd_empty), //o
    .o_water_level (                )  //o
);

assign u_rsp_i_wr_en = i_tx_csr_rsp_rvalid;
assign u_rsp_i_wr_data = i_tx_csr_rsp_rdata;
assign u_rsp_i_rd_en = !u_rsp_o_rd_empty;
com_sync_fifo_reg #(
    .DW    (CSR_DW   ),
    .DEPTH (RSP_DEPTH)
)u_com_sync_fifo_reg_rsp
(
    .clk           (clk             ), //i
    .rst_n         (rst_n           ), //i
    .clear         (clear           ), //i
    .i_wr_en       (u_rsp_i_wr_en   ), //i
    .i_wr_data     (u_rsp_i_wr_data ), //i
    .o_wr_full     (u_rsp_o_wr_full ), //o
    .i_rd_en       (u_rsp_i_rd_en   ), //i
    .o_rd_data     (u_rsp_o_rd_data ), //o
    .o_rd_empty    (u_rsp_o_rd_empty), //o
    .o_water_level (                )  //o
);

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( CSR_DW>=8 && CSR_DW%8==0, "CSR_DW must be byte aligned" )
`COM_PARAM_ASSERT( REQ_DEPTH>=2, "request fifo depth must not be less than 2" )
`COM_PARAM_ASSERT( RSP_DEPTH>=2, "response fifo depth must not be less than 2" )
`COM_SIGNAL_ASSERT_LITE( a0, i_tx_csr_rsp_rvalid,!u_rsp_o_wr_full, "csr response fifo overflow" )

endmodule
