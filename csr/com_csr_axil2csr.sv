module com_csr_axil2csr #(
    parameter AXI_AW      = 32, //range=[1::]
    parameter AXI_DW      = 32, //range=[8::8]
    parameter CSR_AW      = 16, //range=[1::]
    parameter CSR_DW      = AXI_DW,
    parameter RD_REQ_OSD  = 1,  //range=[1:256:]
    parameter RD_DATA_OSD = 0   //range=[0:256:]
)
(
    input  wire                     clk                 ,
    input  wire                     rst_n               ,
    input  wire                     clear               ,

    input  wire [AXI_AW-1:0]        i_axil_awaddr       ,
    input  wire [2:0]               i_axil_awprot       ,
    input  wire                     i_axil_awvalid      ,
    output wire                     o_axil_awready      ,
    input  wire [AXI_DW-1:0]        i_axil_wdata        ,
    input  wire [AXI_DW/8-1:0]      i_axil_wstrb        ,
    input  wire                     i_axil_wvalid       ,
    output wire                     o_axil_wready       ,
    output wire [1:0]               o_axil_bresp        ,
    output wire                     o_axil_bvalid       ,
    input  wire                     i_axil_bready       ,

    input  wire [AXI_AW-1:0]        i_axil_araddr       ,
    input  wire [2:0]               i_axil_arprot       ,
    input  wire                     i_axil_arvalid      ,
    output wire                     o_axil_arready      ,
    output wire [AXI_DW-1:0]        o_axil_rdata        ,
    output wire [1:0]               o_axil_rresp        ,
    output wire                     o_axil_rvalid       ,
    input  wire                     i_axil_rready       ,

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
localparam AXI_RESP_OKAY = 2'b00;
localparam RD_REQ_CW = $clog2(RD_REQ_OSD+1);
localparam RD_DATA_CW = $clog2((RD_DATA_OSD>1?RD_DATA_OSD:1)+1);
//signal declare-------------------------------------------------------------
reg                   r_aw_vld;
reg  [AXI_AW-1:0]     r_aw_addr;
reg                   r_w_vld;
reg  [AXI_DW-1:0]     r_w_data;
reg  [AXI_DW/8-1:0]   r_w_strb;
reg                   r_b_vld;
reg  [RD_REQ_CW-1:0]  r_rd_req_osd_cnt;
reg  [RD_DATA_CW-1:0] r_rd_data_osd_cnt;

wire axil_aw_hs;
wire axil_w_hs;
wire axil_b_hs;
wire axil_ar_hs;
wire axil_r_hs;
wire csr_req_hs;
wire csr_write_hs;
wire csr_read_hs;
wire csr_write_avl;
wire csr_read_avl;
wire rd_req_osd_avl;
wire rd_data_osd_avl;
wire read_order_block;

//instance signal---
wire                 u_ar_i_wr_en;
wire [AXI_AW-1:0]    u_ar_i_wr_data;
wire                 u_ar_o_wr_full;
wire                 u_ar_i_rd_en;
wire [AXI_AW-1:0]    u_ar_o_rd_data;
wire                 u_ar_o_rd_empty;
//statement------------------------------------------------------------------
//output assign---
assign o_axil_awready = !r_aw_vld && !read_order_block && !clear;
assign o_axil_wready = !r_w_vld && !read_order_block && !clear;
assign o_axil_bresp = AXI_RESP_OKAY;
assign o_axil_bvalid = r_b_vld;
assign o_axil_arready = !u_ar_o_wr_full && !clear;
assign o_axil_rresp = AXI_RESP_OKAY;

assign o_csr_req_write = csr_write_avl;
assign o_csr_req_addr = csr_write_avl ? CSR_AW'(r_aw_addr) :
                                        CSR_AW'(u_ar_o_rd_data);
assign o_csr_req_wdata = CSR_DW'(r_w_data);
assign o_csr_req_wstrb = r_w_strb;
assign o_csr_req_valid = (csr_write_avl || csr_read_avl) && !clear;

//body---
assign axil_aw_hs = i_axil_awvalid && o_axil_awready;
assign axil_w_hs = i_axil_wvalid && o_axil_wready;
assign axil_b_hs = o_axil_bvalid && i_axil_bready;
assign axil_ar_hs = i_axil_arvalid && o_axil_arready;
assign axil_r_hs = o_axil_rvalid && i_axil_rready;
assign csr_write_avl = r_aw_vld && r_w_vld && !r_b_vld;
assign csr_read_avl = !u_ar_o_rd_empty && rd_req_osd_avl &&
                      rd_data_osd_avl && !csr_write_avl;
assign csr_req_hs = o_csr_req_valid && i_csr_req_ready;
assign csr_write_hs = csr_req_hs && o_csr_req_write;
assign csr_read_hs = csr_req_hs && !o_csr_req_write;
assign rd_req_osd_avl = r_rd_req_osd_cnt<RD_REQ_CW'(RD_REQ_OSD);
assign rd_data_osd_avl = RD_DATA_OSD==0 ? 1'b1 :
                         r_rd_data_osd_cnt<RD_DATA_CW'(RD_DATA_OSD);
// A later write cannot overtake any AXI read still waiting to enter CSR.
assign read_order_block = !u_ar_o_rd_empty || i_axil_arvalid;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_aw_vld <= 1'b0;
    else if( clear )
        r_aw_vld <= 1'b0;
    else if( csr_write_hs )
        r_aw_vld <= 1'b0;
    else if( axil_aw_hs )
        r_aw_vld <= 1'b1;
end

always @(posedge clk) begin
    if( axil_aw_hs )
        r_aw_addr <= i_axil_awaddr;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_w_vld <= 1'b0;
    else if( clear )
        r_w_vld <= 1'b0;
    else if( csr_write_hs )
        r_w_vld <= 1'b0;
    else if( axil_w_hs )
        r_w_vld <= 1'b1;
end

always @(posedge clk) begin
    if( axil_w_hs ) begin
        r_w_data <= i_axil_wdata;
        r_w_strb <= i_axil_wstrb;
    end
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_b_vld <= 1'b0;
    else if( clear )
        r_b_vld <= 1'b0;
    else if( csr_write_hs )
        r_b_vld <= 1'b1;
    else if( axil_b_hs )
        r_b_vld <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_req_osd_cnt <= '0;
    else if( clear )
        r_rd_req_osd_cnt <= '0;
    else if( csr_read_hs || i_csr_rsp_rvalid )
        r_rd_req_osd_cnt <= r_rd_req_osd_cnt + csr_read_hs -
                            i_csr_rsp_rvalid;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_data_osd_cnt <= '0;
    else if( clear )
        r_rd_data_osd_cnt <= '0;
    else if( RD_DATA_OSD==0 )
        r_rd_data_osd_cnt <= '0;
    else if( csr_read_hs || axil_r_hs )
        r_rd_data_osd_cnt <= r_rd_data_osd_cnt + csr_read_hs - axil_r_hs;
end

//instance-------------------------------------------------------------------
assign u_ar_i_wr_en = axil_ar_hs;
assign u_ar_i_wr_data = i_axil_araddr;
assign u_ar_i_rd_en = csr_read_hs;
com_sync_fifo_reg #(
    .DW    (AXI_AW   ),
    .DEPTH (RD_REQ_OSD)
)u_com_sync_fifo_reg_ar
(
    .clk           (clk            ), //i
    .rst_n         (rst_n          ), //i
    .clear         (clear          ), //i
    .i_wr_en       (u_ar_i_wr_en   ), //i
    .i_wr_data     (u_ar_i_wr_data ), //i
    .o_wr_full     (u_ar_o_wr_full ), //o
    .i_rd_en       (u_ar_i_rd_en   ), //i
    .o_rd_data     (u_ar_o_rd_data ), //o
    .o_rd_empty    (u_ar_o_rd_empty), //o
    .o_water_level (               )  //o
);

generate
if( RD_DATA_OSD==0 ) begin: gen_rdata_direct
    assign o_axil_rdata = AXI_DW'(i_csr_rsp_rdata);
    assign o_axil_rvalid = i_csr_rsp_rvalid;

    `COM_SIGNAL_ASSERT_LITE( a0, o_axil_rvalid,i_axil_rready===1'b1, "AXI RREADY must be high when RD_DATA_OSD is 0" )
end
else begin: gen_rdata_fifo
    wire                 u_r_i_wr_en;
    wire [AXI_DW-1:0]    u_r_i_wr_data;
    wire                 u_r_o_wr_full;
    wire                 u_r_i_rd_en;
    wire [AXI_DW-1:0]    u_r_o_rd_data;
    wire                 u_r_o_rd_empty;

    assign o_axil_rdata = u_r_o_rd_data;
    assign o_axil_rvalid = !u_r_o_rd_empty;

    assign u_r_i_wr_en = i_csr_rsp_rvalid;
    assign u_r_i_wr_data = AXI_DW'(i_csr_rsp_rdata);
    assign u_r_i_rd_en = axil_r_hs;
    com_sync_fifo_reg #(
        .DW    (AXI_DW    ),
        .DEPTH (RD_DATA_OSD)
    )u_com_sync_fifo_reg_r
    (
        .clk           (clk           ), //i
        .rst_n         (rst_n         ), //i
        .clear         (clear         ), //i
        .i_wr_en       (u_r_i_wr_en   ), //i
        .i_wr_data     (u_r_i_wr_data ), //i
        .o_wr_full     (u_r_o_wr_full ), //o
        .i_rd_en       (u_r_i_rd_en   ), //i
        .o_rd_data     (u_r_o_rd_data ), //o
        .o_rd_empty    (u_r_o_rd_empty), //o
        .o_water_level (              )  //o
    );

    `COM_SIGNAL_ASSERT_LITE( a1, i_csr_rsp_rvalid,!u_r_o_wr_full, "csr read response fifo overflow" )
end
endgenerate

//assert----------------------------------------------------------------------
`COM_PARAM_ASSERT( AXI_DW==CSR_DW, "AXI_DW and CSR_DW must be equal" )
`COM_PARAM_ASSERT( AXI_DW>=8 && AXI_DW%8==0, "AXI_DW must be byte aligned" )
`COM_PARAM_ASSERT( RD_REQ_OSD>=1 && RD_REQ_OSD<=256, "RD_REQ_OSD must be in range 1 to 256" )
`COM_PARAM_ASSERT( RD_DATA_OSD>=0 && RD_DATA_OSD<=256, "RD_DATA_OSD must be in range 0 to 256" )
`COM_SIGNAL_ASSERT_LITE( a2, i_csr_rsp_rvalid,r_rd_req_osd_cnt!='0 || csr_read_hs, "csr read response without request" )

endmodule
