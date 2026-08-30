module com_csr_ahb2csr #(
    parameter AHB_AW = 32, //range=[1::]
    parameter AHB_DW = 32, //range=[8::8]
    parameter CSR_AW = 16, //range=[1::]
    parameter CSR_DW = AHB_DW
)
(
    input  wire                     clk                 ,
    input  wire                     rst_n               ,
    input  wire                     clear               ,

    input  wire                     i_ahb_hsel          ,
    input  wire                     i_ahb_hready        ,
    input  wire [AHB_AW-1:0]        i_ahb_haddr         ,
    input  wire [1:0]               i_ahb_htrans        ,
    input  wire                     i_ahb_hwrite        ,
    input  wire [2:0]               i_ahb_hsize         ,
    input  wire [2:0]               i_ahb_hburst        ,
    input  wire [3:0]               i_ahb_hprot         ,
    input  wire [AHB_DW-1:0]        i_ahb_hwdata        ,
    output wire [AHB_DW-1:0]        o_ahb_hrdata        ,
    output wire                     o_ahb_hreadyout     ,
    output wire                     o_ahb_hresp         ,

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
localparam CSR_SW = CSR_DW/8;
localparam CSR_LSB_W = $clog2(CSR_SW>2?CSR_SW:2);
//signal declare-------------------------------------------------------------
reg                  r_trans_vld;
reg                  r_trans_write;
reg                  r_trans_err;
reg  [AHB_AW-1:0]    r_trans_addr;
reg  [2:0]           r_trans_size;
reg                  r_req_sent;

reg  [CSR_SW-1:0]    w_csr_wstrb;

wire ahb_addr_hs;
wire ahb_direct_read_req;
wire current_req;
wire csr_req_hs;
wire csr_current_req_hs;
wire csr_direct_read_hs;
wire read_done;
wire trans_done;
wire [CSR_LSB_W-1:0] trans_addr_lsb;
//statement------------------------------------------------------------------
//output assign---
assign o_ahb_hrdata = AHB_DW'(i_csr_rsp_rdata);
assign o_ahb_hreadyout = !r_trans_vld ? 1'b1 :
                         r_trans_err ? 1'b1 :
                         r_trans_write ? (r_req_sent || csr_current_req_hs) :
                                         read_done;
assign o_ahb_hresp = r_trans_vld && r_trans_err;

assign o_csr_req_write = current_req ? r_trans_write : 1'b0;
assign o_csr_req_addr = current_req ? CSR_AW'(r_trans_addr) :
                                      CSR_AW'(i_ahb_haddr);
assign o_csr_req_wdata = CSR_DW'(i_ahb_hwdata);
assign o_csr_req_wstrb = current_req ? w_csr_wstrb : '1;
assign o_csr_req_valid = (current_req || ahb_direct_read_req) && !clear;

//body---
assign ahb_addr_hs = i_ahb_hsel && i_ahb_hready && i_ahb_htrans[1];
assign current_req = r_trans_vld && !r_trans_err && !r_req_sent;
assign csr_req_hs = o_csr_req_valid && i_csr_req_ready;
assign csr_current_req_hs = current_req && i_csr_req_ready && !clear;
assign csr_direct_read_hs = csr_req_hs && !current_req;
assign read_done = i_csr_rsp_rvalid && r_req_sent;
assign trans_done = r_trans_vld && o_ahb_hreadyout;
assign ahb_direct_read_req = ahb_addr_hs && !i_ahb_hwrite &&
                             (!r_trans_vld || trans_done) && !current_req;
assign trans_addr_lsb = r_trans_addr[CSR_LSB_W-1:0];

always @* begin
    w_csr_wstrb = '0;
    if( !r_trans_err )
        w_csr_wstrb = ({CSR_SW{1'b1}} >>
                       (CSR_SW-(1<<r_trans_size))) << trans_addr_lsb;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_trans_vld <= 1'b0;
    else if( clear )
        r_trans_vld <= 1'b0;
    else if( ahb_addr_hs )
        r_trans_vld <= 1'b1;
    else if( trans_done )
        r_trans_vld <= 1'b0;
end

always @(posedge clk) begin
    if( ahb_addr_hs ) begin
        r_trans_write <= i_ahb_hwrite;
        r_trans_addr <= i_ahb_haddr;
        r_trans_size <= i_ahb_hsize;
        r_trans_err <= i_ahb_hsize>$clog2(CSR_SW);
    end
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_sent <= 1'b0;
    else if( clear )
        r_req_sent <= 1'b0;
    else if( ahb_addr_hs )
        r_req_sent <= !i_ahb_hwrite && csr_direct_read_hs;
    else if( trans_done )
        r_req_sent <= 1'b0;
    else if( csr_current_req_hs )
        r_req_sent <= 1'b1;
end

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( AHB_DW==CSR_DW, "AHB_DW and CSR_DW must be equal" )
`COM_PARAM_ASSERT( AHB_DW>=8 && AHB_DW%8==0, "AHB_DW must be byte aligned" )

endmodule
