module com_csr_timeout #(
    parameter CSR_AW        = 16,  //range=[1::]
    parameter CSR_DW        = 32,  //range=[8::8]
    parameter TIMEOUT_CYCLE = 1000 //range=[1::]
)
(
    input  wire                     clk                     ,
    input  wire                     rst_n                   ,
    input  wire                     clear                   ,

    input  wire                     i_rx_csr_req_write      ,
    input  wire [CSR_AW-1:0]        i_rx_csr_req_addr       ,
    input  wire [CSR_DW-1:0]        i_rx_csr_req_wdata      ,
    input  wire [CSR_DW/8-1:0]      i_rx_csr_req_wstrb      ,
    input  wire                     i_rx_csr_req_valid      ,
    output wire                     o_rx_csr_req_ready      ,
    output wire [CSR_DW-1:0]        o_rx_csr_rsp_rdata      ,
    output wire                     o_rx_csr_rsp_rvalid     ,

    output wire                     o_tx_csr_req_write      ,
    output wire [CSR_AW-1:0]        o_tx_csr_req_addr       ,
    output wire [CSR_DW-1:0]        o_tx_csr_req_wdata      ,
    output wire [CSR_DW/8-1:0]      o_tx_csr_req_wstrb      ,
    output wire                     o_tx_csr_req_valid      ,
    input  wire                     i_tx_csr_req_ready      ,
    input  wire [CSR_DW-1:0]        i_tx_csr_rsp_rdata      ,
    input  wire                     i_tx_csr_rsp_rvalid     ,

    output wire                     o_pls_err_req_timeout   ,
    output wire                     o_pls_err_rsp_timeout   //,
);

//localparam-----------------------------------------------------------------
localparam TO_CW = $clog2((TIMEOUT_CYCLE>1?TIMEOUT_CYCLE:1)+1);
//signal declare-------------------------------------------------------------
reg  [15:0]      r_rd_pend_cnt;
reg  [TO_CW-1:0] r_req_timeout_cnt;
reg  [TO_CW-1:0] r_rsp_timeout_cnt;
reg              r_req_timeout_rsp_pend;
reg              r_rsp_timeout_flag;

wire csr_req_hs;
wire csr_read_hs;
wire takeover_read_hs;
wire normal_rsp_vld;
wire req_wait;
wire rsp_wait;
wire req_timeout_last;
wire rsp_timeout_last;
wire req_timeout_read;
wire req_timeout_rsp_direct;
wire req_timeout_rsp_pend_fire;
wire rsp_timeout_takeover;
wire timeout_rsp_vld;
//statement------------------------------------------------------------------
//output assign---
// C:\personal\proj\ai_proj\dmg\com\csr\com_csr_regslice.sv

assign o_rx_csr_req_ready = r_rsp_timeout_flag ? 1'b1 :
                            !r_req_timeout_rsp_pend && (i_tx_csr_req_ready || req_timeout_last);
assign o_rx_csr_rsp_rdata = normal_rsp_vld ? i_tx_csr_rsp_rdata : '0;
assign o_rx_csr_rsp_rvalid = normal_rsp_vld || timeout_rsp_vld;

assign o_tx_csr_req_write = i_rx_csr_req_write;
assign o_tx_csr_req_addr = i_rx_csr_req_addr;
assign o_tx_csr_req_wdata = i_rx_csr_req_wdata;
assign o_tx_csr_req_wstrb = i_rx_csr_req_wstrb;
assign o_tx_csr_req_valid = i_rx_csr_req_valid && !r_req_timeout_rsp_pend && !r_rsp_timeout_flag;

assign o_pls_err_req_timeout = req_timeout_last;
assign o_pls_err_rsp_timeout = rsp_timeout_last;

//body---
assign csr_req_hs = o_tx_csr_req_valid && i_tx_csr_req_ready;
assign csr_read_hs = csr_req_hs && !o_tx_csr_req_write;
assign takeover_read_hs = r_rsp_timeout_flag && i_rx_csr_req_valid && !i_rx_csr_req_write;
assign normal_rsp_vld = i_tx_csr_rsp_rvalid && !r_rsp_timeout_flag;
assign req_wait = i_rx_csr_req_valid && !i_tx_csr_req_ready && !r_req_timeout_rsp_pend && !r_rsp_timeout_flag;
assign rsp_wait = r_rd_pend_cnt!='0 && !i_tx_csr_rsp_rvalid && !r_rsp_timeout_flag;
assign req_timeout_last = req_wait && r_req_timeout_cnt==TO_CW'(TIMEOUT_CYCLE-1);
assign rsp_timeout_last = rsp_wait && r_rsp_timeout_cnt==TO_CW'(TIMEOUT_CYCLE-1);
assign req_timeout_read = req_timeout_last && !i_rx_csr_req_write;
assign req_timeout_rsp_direct = req_timeout_read && r_rd_pend_cnt=='0 && !normal_rsp_vld;
assign req_timeout_rsp_pend_fire = r_req_timeout_rsp_pend && r_rd_pend_cnt=='0 && !normal_rsp_vld;
assign rsp_timeout_takeover = r_rsp_timeout_flag && r_rd_pend_cnt!='0;
assign timeout_rsp_vld = req_timeout_rsp_direct ||
                         req_timeout_rsp_pend_fire || rsp_timeout_last || rsp_timeout_takeover;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_pend_cnt <= '0;
    else if( clear )
        r_rd_pend_cnt <= '0;
    else if( csr_read_hs || takeover_read_hs || normal_rsp_vld || rsp_timeout_last || rsp_timeout_takeover )
        r_rd_pend_cnt <= r_rd_pend_cnt + csr_read_hs + takeover_read_hs -
                         normal_rsp_vld - rsp_timeout_last - rsp_timeout_takeover;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_timeout_rsp_pend <= 1'b0;
    else if( clear )
        r_req_timeout_rsp_pend <= 1'b0;
    else if( req_timeout_rsp_pend_fire )
        r_req_timeout_rsp_pend <= 1'b0;
    else if( req_timeout_read && !req_timeout_rsp_direct )
        r_req_timeout_rsp_pend <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rsp_timeout_flag <= 1'b0;
    else if( clear )
        r_rsp_timeout_flag <= 1'b0;
    else if( rsp_timeout_last )
        r_rsp_timeout_flag <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_timeout_cnt <= '0;
    else if( clear || !req_wait || req_timeout_last )
        r_req_timeout_cnt <= '0;
    else
        r_req_timeout_cnt <= r_req_timeout_cnt + 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rsp_timeout_cnt <= '0;
    else if( clear || !rsp_wait || rsp_timeout_last )
        r_rsp_timeout_cnt <= '0;
    else
        r_rsp_timeout_cnt <= r_rsp_timeout_cnt + 1'b1;
end

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( TIMEOUT_CYCLE>=1, "TIMEOUT_CYCLE must not be less than 1" )
`COM_SIGNAL_ASSERT_LITE( a0, normal_rsp_vld,r_rd_pend_cnt!='0 || csr_read_hs, "csr timeout response without request" )

endmodule
