module top();

bit clk   ;
bit rst_n ;
bit clear ;
bit axi_clk   ;
event all_done;
string tc_dir = "../tc/";

always #2   clk= ~clk;
always #2   axi_clk= ~axi_clk;

task reset();
    #10; rst_n = 1'b1;
    #15; rst_n = 1'b0;
    #20; rst_n = 1'b1;
endtask //reset_isp
task xclear();
    @( posedge clk ); clear <= 1'b0;
    @( posedge clk ); clear <= 1'b1;
    @( posedge clk ); clear <= 1'b0;
endtask //reset_isp


//-------------------------------------------------------
//dut
//-------------------------------------------------------
import EmiPkg::*;
localparam BUS_AW = EMI_AW;
localparam BUS_DW = EMI_DW;
localparam BUS_LW = 24;

import ImgPkg::*;
ImgIf img_if( clk );
img_test img_t1( img_if );

wire [BUS_AW-1:0]  bus_wa_addr     ;
wire [BUS_LW-1:0]  bus_wa_bytelen  ;
wire               bus_wa_valid    ;
wire               bus_wa_ready    ;
wire [BUS_DW-1:0]  bus_wd_data     ;
wire               bus_wd_valid    ;
wire               bus_wd_ready    ;
wire               bus_wb_resp     ;
wire [BUS_AW-1:0]  bus_ra_addr     ;
wire [BUS_LW-1:0]  bus_ra_bytelen  ;
wire               bus_ra_valid    ;
wire               bus_ra_ready    ;
wire [BUS_DW-1:0]  bus_rd_data     ;
wire               bus_rd_valid    ;
wire               bus_rd_ready    ;
com_img_cut_wr #(
    .XW         ( XW         ), //12
    .PW         ( PW         ), //16
    .PXL_N      ( PXL_N      ), //1
    .BUS_AW     ( BUS_AW     ), //32
    .BUS_DW     ( BUS_DW     ), //128
    .BUS_LW     ( BUS_LW     )  //32
)u_com_img_cut_wr
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg&status--
    .pic_width_m1         ( img_if.pic_width_m1         ), //i
    .pic_heigh_m1         ( img_if.pic_heigh_m1         ), //i
    .pixel_bitlen         ( img_if.pixel_bitlen         ), //i
    .pic_base_addr        ( img_if.pic_base_addr        ), //i
    .line_stride          ( img_if.line_stride          ), //i
    //dp---
    .cut_xpos             ( img_if.img_cut_wr_xpos      ), //i
    .cut_ypos             ( img_if.img_cut_wr_ypos      ), //i
    .cut_width_m1         ( img_if.img_cut_wr_width_m1  ), //i
    .cut_heigh_m1         ( img_if.img_cut_wr_heigh_m1  ), //i
    .cut_wr_vld           ( img_if.img_cut_wr_vld       ), //i
    .cut_wr_rdy           ( img_if.img_cut_wr_rdy       ), //o
    .cut_wb_resp          ( img_if.img_cut_wb_resp      ), //o

    .pixel_sob            ( img_if.pixel_sof     ), //i
    .pixel_last           ( img_if.pixel_last    ), //i
    .pixel_data           ( img_if.pixel_data    ), //i
    .pixel_valid          ( img_if.pixel_valid   ), //i
    .pixel_ready          ( img_if.pixel_ready   ), //o

    .bus_wa_addr          ( bus_wa_addr          ), //o
    .bus_wa_bytelen       ( bus_wa_bytelen       ), //o
    .bus_wa_valid         ( bus_wa_valid         ), //o
    .bus_wa_ready         ( bus_wa_ready         ), //i
    .bus_wd_data          ( bus_wd_data          ), //o
    .bus_wd_valid         ( bus_wd_valid         ), //o
    .bus_wd_ready         ( bus_wd_ready         ), //i
    .bus_wb_resp          ( bus_wb_resp          )  //i
);

com_img_cut_rd #(
    .XW         ( XW         ), //12
    .PW         ( PW         ), //16
    .PXL_N      ( PXL_N      ), //1
    .BUS_AW     ( BUS_AW     ), //32
    .BUS_DW     ( BUS_DW     ), //128
    .BUS_LW     ( BUS_LW     )  //32
)u_com_img_cut_rd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //cfg&status--
    .pic_width_m1         ( img_if.pic_width_m1         ), //i
    .pic_heigh_m1         ( img_if.pic_heigh_m1         ), //i
    .pixel_bitlen         ( img_if.pixel_bitlen         ), //i
    .pic_base_addr        ( img_if.pic_base_addr        ), //i
    .line_stride          ( img_if.line_stride          ), //i
    //dp---
    .cut_xpos             ( img_if.img_cut_rd_xpos      ), //i
    .cut_ypos             ( img_if.img_cut_rd_ypos      ), //i
    .cut_width_m1         ( img_if.img_cut_rd_width_m1  ), //i
    .cut_heigh_m1         ( img_if.img_cut_rd_heigh_m1  ), //i
    .cut_rd_vld           ( img_if.img_cut_rd_vld       ), //i
    .cut_rd_rdy           ( img_if.img_cut_rd_rdy       ), //o

    .pixel_sob            ( img_if.img_cut_rd_pixel_sof    ), //o
    .pixel_eob            ( img_if.img_cut_rd_pixel_eof    ), //o
    .pixel_last           ( img_if.img_cut_rd_pixel_last   ), //o
    .pixel_data           ( img_if.img_cut_rd_pixel_data   ), //o
    .pixel_valid          ( img_if.img_cut_rd_pixel_valid  ), //o
    .pixel_ready          ( img_if.img_cut_rd_pixel_ready  ), //i

    .bus_ra_addr          ( bus_ra_addr          ), //o
    .bus_ra_bytelen       ( bus_ra_bytelen       ), //o
    .bus_ra_valid         ( bus_ra_valid         ), //o
    .bus_ra_ready         ( bus_ra_ready         ), //i
    .bus_rd_data          ( bus_rd_data          ), //i
    .bus_rd_valid         ( bus_rd_valid         ), //i
    .bus_rd_ready         ( bus_rd_ready         )  //o
);

//dma----
// com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH), .EMI_UW(4) )  emi_resp_if(axi_clk);
com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH), .EMI_UW(4) )  emi_resp_if(clk);
emi_test t_emi_test();
com_dma #(
    .BUS_AW     ( BUS_AW     ), //32
    .BUS_DW     ( BUS_DW     ), //128
    .BUS_LW     ( BUS_LW     ), //32
    .WCH        ( 1          ), //5
    .RCH        ( 1          ), //6
    .MAX_CH     ( 16         ), //16
    .AXI_UW     ( 4          )  //4
)u_com_dma
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    // .axi_clk              ( axi_clk              ), //i
    // .axi_rst_n            ( rst_n                ), //i
    .sys_cfg              (                      ), //i
    //cfg&status---
    .wdma_burst_len       ( 8'd7                 ), //i
    .rdma_burst_len       ( 8'd7                 ), //i
    .axi_burst_len        ( 8'd7                 ), //i
    .clr_ongoing          (                      ), //o
    //bus
    .bus_wa_valid         ( bus_wa_valid         ), //i
    .bus_wa_ready         ( bus_wa_ready         ), //o
    .bus_wa_addr          ( bus_wa_addr          ), //i
    .bus_wa_bytelen       ( bus_wa_bytelen       ), //i
    .bus_wd_valid         ( bus_wd_valid         ), //i
    .bus_wd_ready         ( bus_wd_ready         ), //o
    .bus_wd_data          ( bus_wd_data          ), //i
    .bus_wb_resp          ( bus_wb_resp          ), //o
    .bus_ra_valid         ( bus_ra_valid         ), //i
    .bus_ra_ready         ( bus_ra_ready         ), //o
    .bus_ra_addr          ( bus_ra_addr          ), //i
    .bus_ra_bytelen       ( bus_ra_bytelen       ), //i
    .bus_rd_valid         ( bus_rd_valid         ), //o
    .bus_rd_ready         ( bus_rd_ready         ), //i
    .bus_rd_data          ( bus_rd_data          ), //o
    .bus_rd_done          ( bus_rd_done          ), //o
    //axi
    .xm_arvalid           ( emi_resp_if.emi_arvalid ), //o
    .xm_arready           ( emi_resp_if.emi_arready ), //i
    .xm_arid              ( emi_resp_if.emi_arid    ), //o
    .xm_araddr            ( emi_resp_if.emi_araddr  ), //o
    .xm_arlen             ( emi_resp_if.emi_arlen   ), //o
    .xm_aruser            ( emi_resp_if.emi_aruser  ), //o
    .xm_arsize            (                         ), //o
    .xm_arbusrt           (                         ), //o
    .xm_arcache           (                         ), //o
    .xm_arprot            (                         ), //o
    .xm_arqos             (                         ), //o
    .xm_arregion          (                         ), //o
    .xm_rvalid            ( emi_resp_if.emi_rvalid  ), //i
    .xm_rready            ( emi_resp_if.emi_rready  ), //o
    .xm_rid               ( emi_resp_if.emi_rid     ), //i
    .xm_rdata             ( emi_resp_if.emi_rdata   ), //i
    .xm_rlast             ( emi_resp_if.emi_rlast   ), //i
    .xm_ruser             ( emi_resp_if.emi_ruser   ), //i
    .xm_rresp             ( 2'b0                    ), //i
    .xm_awvalid           ( emi_resp_if.emi_awvalid ), //o
    .xm_awready           ( emi_resp_if.emi_awready ), //i
    .xm_awid              ( emi_resp_if.emi_awid    ), //o
    .xm_awaddr            ( emi_resp_if.emi_awaddr  ), //o
    .xm_awlen             ( emi_resp_if.emi_awlen   ), //o
    .xm_awuser            ( emi_resp_if.emi_awuser  ), //o
    .xm_awsize            (                         ), //o
    .xm_awbusrt           (                         ), //o
    .xm_awcache           (                         ), //o
    .xm_awprot            (                         ), //o
    .xm_awqos             (                         ), //o
    .xm_awregion          (                         ), //o
    .xm_wvalid            ( emi_resp_if.emi_wvalid  ), //o
    .xm_wready            ( emi_resp_if.emi_wready  ), //i
    .xm_wdata             ( emi_resp_if.emi_wdata   ), //o
    .xm_wstrb             ( emi_resp_if.emi_wstrb   ), //o
    .xm_wlast             ( emi_resp_if.emi_wlast   ), //o
    .xm_wuser             ( emi_resp_if.emi_wuser   ), //o
    .xm_bvalid            ( emi_resp_if.emi_bvalid  ), //i
    .xm_bready            ( emi_resp_if.emi_bready  ), //o
    .xm_bid               ( emi_resp_if.emi_bid     ), //i
    .xm_buser             ( emi_resp_if.emi_buser   ), //i
    .xm_bresp             ( 2'b0                    )  //i
);

//-------------------------------------------------------
//dump fsdb
//-------------------------------------------------------
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("run.fsdb");
    $fsdbDumpMDA(0,top)  ;   //dump array
    $fsdbDumpvars(0,top) ;  //dump struct
    $fsdbDumpvars(top,"+all");  //dump struct
    $fsdbDumpon();
end
`endif

endmodule
