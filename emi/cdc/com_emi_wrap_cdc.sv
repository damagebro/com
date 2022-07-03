/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/06/22-14:59:18
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_wrap_cdc_v
`define com_emi_wrap_cdc_v
module com_emi_wrap_cdc #( parameter
    AW      = 32        , //emi bus addr bit_width
    DW      = 128       , //emi bus data bit_width
    USR_W   = 0         , //emi bus user signal bit_width, typical value=0; maybe used by cache control, and any DIY functions

    RCH     = 4         , //number of read channel
    WCH     = 4         , //number of write channel
    MAX_CH  = 16        , //number of max (write||read) channels

    STR_LOG_PREFIX = ""//, dump_emi log prefix
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
input  wire                     axi_clk             ,
input  wire                     axi_rst_n           ,
`COM_SYS_IF                     sys_cfg             ,
//cfg&status---
input  wire [7:0]               max_burst_len       ,
output wire                     clr_ongoing         ,
//dp---
com_emi_if.usr_rch_rx           usr_emi_rdifs[RCH-1:0],
com_emi_if.usr_wch_rx           usr_emi_wrifs[WCH-1:0],
com_emi_if.tx                   ext_emi_ifm           //,
);
//localparam-----------------------------------------------------------------
localparam UW =(USR_W>0?USR_W:1); //spyglass disable W362
localparam SW = DW/8            ;
localparam IW = $clog2(MAX_CH)  ;

localparam MAX_OSD = 16        ; //number of max outstanding
localparam MAX_LEN = 16        ; //number of max burst len
localparam BOUND_BYTES = 4096  ; //4k boundary split required by interleave dram bank; modify this value must be 2^n, typical value is (512, 1024, 2048, 4096)

//ram---
localparam WR_RAM_DEPTH = MAX_OSD*MAX_LEN; //write channel data ram depth, typical value is MAX_OSD*MAX_LEN,  available vaule is [2,MAX_OSD*MAX_LEN] \
                   //when RAM_DEPTH==0, the spram_if(cen,we..) don't need connect to sram;
localparam WR_RAM_ONE_DEPTH = WR_RAM_DEPTH/2;
localparam WR_RAM_AW = $clog2(WR_RAM_DEPTH>2?WR_RAM_DEPTH:2); //spyglass disable W362
localparam WR_RAM_DW = USR_W + SW + DW;//, //{user,strb,data}

localparam RD_RAM_DEPTH = 16; //read channel data ram depth, typical value is 16,  available vaule is [2,MAX_OSD*MAX_LEN] \
                   //recommend use the default value, for user send read request, must make sure read data can be received, \
                   //so emi bus don't need storaged read data \
                   //when RAM_DEPTH==0, the spram_if(cen,we..) don't need connect to sram;
localparam RD_RAM_AW = $clog2(RD_RAM_DEPTH>2?RD_RAM_DEPTH:2); //spyglass disable W362
localparam RD_RAM_DW    = USR_W + 1 + IW + DW;//, //{user,rlast,rid,data}
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire rch_clr_onging;
wire wch_clr_onging;

com_emi_if #( .EMI_AW(AW), .EMI_DW(DW), .EMI_UW(UW), .EMI_MAX_CH(MAX_CH) )  ext_emi_wrifm();
com_emi_if #( .EMI_AW(AW), .EMI_DW(DW), .EMI_UW(UW), .EMI_MAX_CH(MAX_CH) )  ext_emi_rdifm();
//statement------------------------------------------------------------------

//---------------------------------------------------------------------------
//com_emi_rch
//---------------------------------------------------------------------------
wire                     emi_rch_ram_wr_en   ;
wire [RD_RAM_AW-1:0]     emi_rch_ram_wr_addr ;
wire [RD_RAM_DW-1:0]     emi_rch_ram_wr_data ;
wire                     emi_rch_ram_rd_en   ;
wire [RD_RAM_AW-1:0]     emi_rch_ram_rd_addr ;
wire [RD_RAM_DW-1:0]     emi_rch_ram_rd_data ;
com_emi_rch_cdc_opt1 #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .USR_W      ( USR_W      ), //0

    .RCH        ( RCH        ), //4
    .MAX_RCH    ( MAX_CH     ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .MAX_LEN    ( MAX_LEN    ), //16
    .BOUND_BYTES ( BOUND_BYTES ),//4096
    .STR_LOG_PREFIX ( STR_LOG_PREFIX ),

    .RAM_DEPTH  ( RD_RAM_DEPTH ) //0
)u_com_emi_rch_cdc_opt1
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    .axi_clk              ( axi_clk              ), //i
    .axi_rst_n            ( axi_rst_n            ), //i
    .axi_clear            ( 1'b0                 ), //i
    //cfg&status---
    .max_burst_len        ( max_burst_len        ), //i
    .clr_ongoing          ( clr_ongoing          ), //o
    //sram_if---
    .emi_rch_ram_wr_en    ( emi_rch_ram_wr_en    ), //o
    .emi_rch_ram_wr_addr  ( emi_rch_ram_wr_addr  ), //o
    .emi_rch_ram_wr_data  ( emi_rch_ram_wr_data  ), //o
    .emi_rch_ram_rd_en    ( emi_rch_ram_rd_en    ), //o
    .emi_rch_ram_rd_addr  ( emi_rch_ram_rd_addr  ), //o
    .emi_rch_ram_rd_data  ( emi_rch_ram_rd_data  ), //i
    //dp---
    .usr_emi_ifs          ( usr_emi_rdifs        ), //if
    .ext_emi_ifm          ( ext_emi_rdifm        )  //if
);

generate
if( RD_RAM_DEPTH==0 )begin:gen_rch_sram_n
    assign emi_rch_ram_rd_data = 'b0;
end
else begin:gen_rch_sram_y
    com_tpram2ck_cell #(
        .DEPTH      ( RD_RAM_DEPTH ), //32
        .DATA_W     ( RD_RAM_DW    )//, //20
    )u_com_tpram2ck_cell
    (
        .wr_clk               ( axi_clk              ), //i
        .rd_clk               ( clk                  ), //i
        .mem_cfg              ( sys_cfg              ), //i

        .wr_en                ( emi_rch_ram_wr_en    ), //i
        .wr_addr              ( emi_rch_ram_wr_addr  ), //i
        .wr_data              ( emi_rch_ram_wr_data  ), //i
        .rd_en                ( emi_rch_ram_rd_en    ), //i
        .rd_addr              ( emi_rch_ram_rd_addr  ), //i
        .rd_data              ( emi_rch_ram_rd_data  )  //o
    );
end
endgenerate

//---------------------------------------------------------------------------
//com_emi_wch
//---------------------------------------------------------------------------
wire                     emi_wch_ram_wr_en   ;
wire [WR_RAM_AW-1:0]     emi_wch_ram_wr_addr ;
wire [WR_RAM_DW-1:0]     emi_wch_ram_wr_data ;
wire                     emi_wch_ram_rd_en   ;
wire [WR_RAM_AW-1:0]     emi_wch_ram_rd_addr ;
wire [WR_RAM_DW-1:0]     emi_wch_ram_rd_data ;
com_emi_wch_cdc_opt1 #(
    .AW         ( AW         ), //32
    .DW         ( DW         ), //128
    .USR_W      ( USR_W      ), //0

    .WCH        ( WCH        ), //4
    .MAX_WCH    ( MAX_CH     ), //16
    .MAX_OSD    ( MAX_OSD    ), //16
    .MAX_LEN    ( MAX_LEN    ), //16
    .BOUND_BYTES ( BOUND_BYTES ), //4096
    .STR_LOG_PREFIX ( STR_LOG_PREFIX ),

    .RAM_DEPTH  ( WR_RAM_DEPTH ) //0
)u_com_emi_wch_cdc_opt1
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    .axi_clk              ( axi_clk              ), //i
    .axi_rst_n            ( axi_rst_n            ), //i
    .axi_clear            ( 1'b0                 ), //i
    //cfg&status---
    .max_burst_len        ( max_burst_len        ), //i
    .clr_ongoing          ( wrh_clr_ongoing      ), //o
    //sram_if---
    .emi_wch_ram_wr_en    ( emi_wch_ram_wr_en    ), //o
    .emi_wch_ram_wr_addr  ( emi_wch_ram_wr_addr  ), //o
    .emi_wch_ram_wr_data  ( emi_wch_ram_wr_data  ), //o
    .emi_wch_ram_rd_en    ( emi_wch_ram_rd_en    ), //o
    .emi_wch_ram_rd_addr  ( emi_wch_ram_rd_addr  ), //o
    .emi_wch_ram_rd_data  ( emi_wch_ram_rd_data  ), //i
    //dp---
    .usr_emi_ifs          ( usr_emi_wrifs        ), //if
    .ext_emi_ifm          ( ext_emi_wrifm        )  //if
);
generate
if( WR_RAM_DEPTH==0 )begin:gen_wch_sram_n
    assign emi_wch_ram_qout = 'b0;
end
else begin:gen_wch_sram_y
    com_tpram2ck_cell #(
        .DEPTH      ( WR_RAM_DEPTH ), //32
        .DATA_W     ( WR_RAM_DW    )//, //20
    )u_com_tpram2ck_cell
    (
        .wr_clk               ( clk                  ), //i
        .rd_clk               ( axi_clk              ), //i
        .mem_cfg              ( sys_cfg              ), //i

        .wr_en                ( emi_wch_ram_wr_en    ), //i
        .wr_addr              ( emi_wch_ram_wr_addr  ), //i
        .wr_data              ( emi_wch_ram_wr_data  ), //i
        .rd_en                ( emi_wch_ram_rd_en    ), //i
        .rd_addr              ( emi_wch_ram_rd_addr  ), //i
        .rd_data              ( emi_wch_ram_rd_data  )  //o
    );
end
endgenerate


//---------------------------------------------------------------------------
//out
//---------------------------------------------------------------------------
assign ext_emi_ifm.emi_arvalid = ext_emi_rdifm.emi_arvalid;
assign ext_emi_ifm.emi_arid    = ext_emi_rdifm.emi_arid   ;
assign ext_emi_ifm.emi_araddr  = ext_emi_rdifm.emi_araddr ;
assign ext_emi_ifm.emi_arlen   = ext_emi_rdifm.emi_arlen  ;
assign ext_emi_ifm.emi_aruser  = ext_emi_rdifm.emi_aruser ;
assign ext_emi_rdifm.emi_arready = ext_emi_ifm.emi_arready;

assign ext_emi_rdifm.emi_rvalid = ext_emi_ifm.emi_rvalid;
assign ext_emi_rdifm.emi_rid    = ext_emi_ifm.emi_rid   ;
assign ext_emi_rdifm.emi_rdata  = ext_emi_ifm.emi_rdata ;
assign ext_emi_rdifm.emi_rlast  = ext_emi_ifm.emi_rlast ;
assign ext_emi_rdifm.emi_ruser  = ext_emi_ifm.emi_ruser ;
assign ext_emi_ifm.emi_rready = ext_emi_rdifm.emi_rready;

assign ext_emi_ifm.emi_awvalid = ext_emi_wrifm.emi_awvalid;
assign ext_emi_ifm.emi_awid    = ext_emi_wrifm.emi_awid   ;
assign ext_emi_ifm.emi_awaddr  = ext_emi_wrifm.emi_awaddr ;
assign ext_emi_ifm.emi_awlen   = ext_emi_wrifm.emi_awlen  ;
assign ext_emi_ifm.emi_awuser  = ext_emi_wrifm.emi_awuser ;
assign ext_emi_wrifm.emi_awready = ext_emi_ifm.emi_awready;
assign ext_emi_ifm.emi_wvalid  = ext_emi_wrifm.emi_wvalid ;
// assign ext_emi_ifm.emi_wid     = ext_emi_wrifm.emi_wid    ;
assign ext_emi_ifm.emi_wdata   = ext_emi_wrifm.emi_wdata  ;
assign ext_emi_ifm.emi_wstrb   = ext_emi_wrifm.emi_wstrb  ;
assign ext_emi_ifm.emi_wlast   = ext_emi_wrifm.emi_wlast  ;
assign ext_emi_ifm.emi_wuser   = ext_emi_wrifm.emi_wuser  ;
assign ext_emi_wrifm.emi_wready = ext_emi_ifm.emi_wready  ;
assign ext_emi_wrifm.emi_bvalid= ext_emi_ifm.emi_bvalid   ;
assign ext_emi_wrifm.emi_bid   = ext_emi_ifm.emi_bid      ;
assign ext_emi_wrifm.emi_buser = ext_emi_ifm.emi_buser    ;
assign ext_emi_ifm.emi_bready  = ext_emi_wrifm.emi_bready ;

endmodule //end of com_emi_wrap_cdc
`endif //end of com_emi_wrap_cdc_v

