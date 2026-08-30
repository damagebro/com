module com_csr2apb #(
    parameter CSR_AW    = 16, //range=[1::]
    parameter CSR_DW    = 32, //range=[8::8]
    parameter APB_AW    = 32, //range=[1::]
    parameter REQ_DEPTH = 2   //range=[2:256:]
)
(
    input  wire                     clk                 ,
    input  wire                     rst_n               ,
    input  wire                     clear               ,

    input  wire                     i_csr_req_write     ,
    input  wire [CSR_AW-1:0]        i_csr_req_addr      ,
    input  wire [CSR_DW-1:0]        i_csr_req_wdata     ,
    input  wire [CSR_DW/8-1:0]      i_csr_req_wstrb     ,
    input  wire                     i_csr_req_valid     ,
    output wire                     o_csr_req_ready     ,
    output wire [CSR_DW-1:0]        o_csr_rsp_rdata     ,
    output wire                     o_csr_rsp_rvalid    ,

    output wire [APB_AW-1:0]        o_apb_paddr         ,
    output wire [2:0]               o_apb_pprot         ,
    output wire                     o_apb_psel          ,
    output wire                     o_apb_penable       ,
    output wire                     o_apb_pwrite        ,
    output wire [CSR_DW-1:0]        o_apb_pwdata        ,
    output wire [CSR_DW/8-1:0]      o_apb_pstrb         ,
    input  wire                     i_apb_pready        ,
    input  wire [CSR_DW-1:0]        i_apb_prdata        ,
    input  wire                     i_apb_pslverr       ,
    output wire                     o_pls_err_pslverr   //,
);

//localparam-----------------------------------------------------------------
localparam REQ_DW = 1+CSR_AW+CSR_DW+CSR_DW/8;
localparam REQ_AW = $clog2(REQ_DEPTH>2?REQ_DEPTH:2);
localparam REQ_CW = $clog2(REQ_DEPTH+1);
//signal declare-------------------------------------------------------------
reg  [REQ_DEPTH-1:0][REQ_DW-1:0] r_req_mem;
reg  [REQ_AW-1:0]                r_req_wr_addr;
reg  [REQ_AW-1:0]                r_req_rd_addr;
reg  [REQ_CW-1:0]                r_req_cnt;
reg                              r_apb_access;

wire [REQ_DW-1:0] req_head;
wire req_head_write;
wire [CSR_AW-1:0] req_head_addr;
wire [CSR_DW-1:0] req_head_wdata;
wire [CSR_DW/8-1:0] req_head_wstrb;
wire req_full;
wire req_empty;
wire csr_req_hs;
wire apb_done;
wire [REQ_AW-1:0] req_wr_addr_nxt;
wire [REQ_AW-1:0] req_rd_addr_nxt;
//statement------------------------------------------------------------------
//output assign---
assign o_csr_req_ready = !req_full && !clear;
assign o_csr_rsp_rdata = i_apb_prdata;
assign o_csr_rsp_rvalid = apb_done && !req_head_write;

assign o_apb_paddr = APB_AW'(req_head_addr);
assign o_apb_pprot = 3'b001;
assign o_apb_psel = !req_empty && !clear;
assign o_apb_penable = r_apb_access && !clear;
assign o_apb_pwrite = req_head_write;
assign o_apb_pwdata = req_head_wdata;
assign o_apb_pstrb = req_head_wstrb;
assign o_pls_err_pslverr = apb_done && i_apb_pslverr;

//body---
assign req_head = r_req_mem[r_req_rd_addr];
assign {req_head_wstrb,req_head_wdata,
        req_head_addr,req_head_write} = req_head;
assign req_full = r_req_cnt==REQ_CW'(REQ_DEPTH);
assign req_empty = r_req_cnt=='0;
assign csr_req_hs = i_csr_req_valid && o_csr_req_ready;
assign apb_done = !req_empty && r_apb_access && i_apb_pready && !clear;
assign req_wr_addr_nxt = r_req_wr_addr==REQ_AW'(REQ_DEPTH-1) ?
                         '0 : r_req_wr_addr + 1'b1;
assign req_rd_addr_nxt = r_req_rd_addr==REQ_AW'(REQ_DEPTH-1) ?
                         '0 : r_req_rd_addr + 1'b1;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_wr_addr <= '0;
    else if( clear )
        r_req_wr_addr <= '0;
    else if( csr_req_hs )
        r_req_wr_addr <= req_wr_addr_nxt;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_rd_addr <= '0;
    else if( clear )
        r_req_rd_addr <= '0;
    else if( apb_done )
        r_req_rd_addr <= req_rd_addr_nxt;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_cnt <= '0;
    else if( clear )
        r_req_cnt <= '0;
    else if( csr_req_hs || apb_done )
        r_req_cnt <= r_req_cnt + csr_req_hs - apb_done;
end

always @(posedge clk) begin
    if( csr_req_hs )
        r_req_mem[r_req_wr_addr] <= {i_csr_req_wstrb,i_csr_req_wdata,
                                     i_csr_req_addr,i_csr_req_write};
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_apb_access <= 1'b0;
    else if( clear )
        r_apb_access <= 1'b0;
    else if( req_empty )
        r_apb_access <= 1'b0;
    else if( r_apb_access && i_apb_pready )
        r_apb_access <= 1'b0;
    else
        r_apb_access <= 1'b1;
end

endmodule
