module com_csr_apb2csr #(
    parameter APB_AW = 32, //range=[1::]
    parameter APB_DW = 32, //range=[8::8]
    parameter CSR_AW = 16, //range=[1::]
    parameter CSR_DW = APB_DW
)
(
    input  wire                     clk                 ,
    input  wire                     rst_n               ,
    input  wire                     clear               ,

    input  wire [APB_AW-1:0]        i_apb_paddr         ,
    input  wire [2:0]               i_apb_pprot         ,
    input  wire                     i_apb_psel          ,
    input  wire                     i_apb_penable       ,
    input  wire                     i_apb_pwrite        ,
    input  wire [APB_DW-1:0]        i_apb_pwdata        ,
    input  wire [APB_DW/8-1:0]      i_apb_pstrb         ,
    output wire                     o_apb_pready        ,
    output wire [APB_DW-1:0]        o_apb_prdata        ,
    output wire                     o_apb_pslverr       ,

    output wire                     o_csr_req_write     ,
    output wire [CSR_AW-1:0]        o_csr_req_addr      ,
    output wire [CSR_DW-1:0]        o_csr_req_wdata     ,
    output wire [CSR_DW/8-1:0]      o_csr_req_wstrb     ,
    output wire                     o_csr_req_valid     ,
    input  wire                     i_csr_req_ready     ,
    input  wire [CSR_DW-1:0]        i_csr_rsp_rdata     ,
    input  wire                     i_csr_rsp_rvalid    //,
);

//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg                  r_req_sent;
reg                  r_rsp_vld;
reg  [CSR_DW-1:0]    r_rsp_data;

wire apb_setup;
wire apb_access;
wire apb_done;
wire csr_req_hs;
wire write_done;
wire read_done;
//statement------------------------------------------------------------------
//output assign---
assign o_apb_pready = apb_access &&
                      (i_apb_pwrite ? write_done : read_done);
assign o_apb_prdata = APB_DW'(r_rsp_vld ? r_rsp_data : i_csr_rsp_rdata);
assign o_apb_pslverr = 1'b0;

assign o_csr_req_write = i_apb_pwrite;
assign o_csr_req_addr = CSR_AW'(i_apb_paddr);
assign o_csr_req_wdata = CSR_DW'(i_apb_pwdata);
assign o_csr_req_wstrb = i_apb_pstrb;
assign o_csr_req_valid = apb_access && !r_req_sent && !clear;

//body---
assign apb_setup = i_apb_psel && !i_apb_penable;
assign apb_access = i_apb_psel && i_apb_penable;
assign apb_done = apb_access && o_apb_pready;
assign csr_req_hs = o_csr_req_valid && i_csr_req_ready;
assign write_done = r_req_sent || csr_req_hs;
assign read_done = r_rsp_vld || i_csr_rsp_rvalid;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_sent <= 1'b0;
    else if( clear )
        r_req_sent <= 1'b0;
    else if( apb_setup )
        r_req_sent <= csr_req_hs;
    else if( apb_done )
        r_req_sent <= 1'b0;
    else if( csr_req_hs )
        r_req_sent <= 1'b1;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rsp_vld <= 1'b0;
    else if( clear )
        r_rsp_vld <= 1'b0;
    else if( apb_setup )
        r_rsp_vld <= i_csr_rsp_rvalid;
    else if( apb_done )
        r_rsp_vld <= 1'b0;
    else if( i_csr_rsp_rvalid )
        r_rsp_vld <= 1'b1;
end

always @(posedge clk) begin
    if( i_csr_rsp_rvalid )
        r_rsp_data <= i_csr_rsp_rdata;
end

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( APB_DW==CSR_DW, "APB_DW and CSR_DW must be equal" )
`COM_PARAM_ASSERT( APB_DW>=8 && APB_DW%8==0, "APB_DW must be byte aligned" )

endmodule
