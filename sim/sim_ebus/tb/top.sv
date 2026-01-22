module top();

event all_done;
bit clk   ;
bit rst_n ;
bit clear ;

always #2   clk= ~clk;

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
import DmaPkg::*;
import EmiPkg::*;
localparam AXI_LW      = 8  ;
localparam BOUND_BYTES = 512;
localparam MAX_OSD     = 64;
localparam WR_BUF_DEPTH= 16;
localparam RD_BUF_DEPTH= 0 ;
wire [7:0]  cfg_max_blen_m1 = 8'd3;
wire [15:0] cfg_max_rdcmd_osd = '0;

DmaIf dma_if( clk );
com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH), .EMI_UW(1) ) emi_resp_if(clk);
dma_test dma_t1( emi_resp_if, dma_if );

assign emi_resp_if.emi_arid = '0;
assign emi_resp_if.emi_awid = '0;
com_axi_extd_wr #(
    .AW                             ( BUS_AW                        ), //32
    .DW                             ( BUS_DW                        ), //128
    .EBUS_LW                        ( BUS_LW                        ), //32
    .LW                             ( AXI_LW                        ), //8
    .UW                             ( 1                             ), //1
    .BOUND_BYTES                    ( BOUND_BYTES                   ), //4096
    .MAX_OSD                        ( MAX_OSD                       ), //128
    .BUF_DEPTH                      ( WR_BUF_DEPTH                  )  //8
)u_com_axi_extd_wr(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( clear                ), //i
    .i_cfg_max_blen_m1   ( cfg_max_blen_m1      ), //i
    .ebus_wa_user        ( '0                   ), //i
    .ebus_wa_addr        ( dma_if.bus_wa_addr       ), //i
    .ebus_wa_bytelen     ( dma_if.bus_wa_bytelen    ), //i
    .ebus_wa_valid       ( dma_if.bus_wa_valid      ), //i
    .ebus_wa_ready       ( dma_if.bus_wa_ready      ), //o
    .ebus_wd_data        ( dma_if.bus_wd_data       ), //i
    .ebus_wd_valid       ( dma_if.bus_wd_valid      ), //i
    .ebus_wd_ready       ( dma_if.bus_wd_ready      ), //o
    .ebus_wb_valid       ( dma_if.bus_wb_resp       ), //o
    .axi_awaddr          ( emi_resp_if.emi_awaddr   ), //o
    .axi_awlen           ( emi_resp_if.emi_awlen    ), //o
    .axi_awuser          (                          ), //o
    .axi_awvalid         ( emi_resp_if.emi_awvalid  ), //o
    .axi_awready         ( emi_resp_if.emi_awready  ), //i
    .axi_wdata           ( emi_resp_if.emi_wdata    ), //o
    .axi_wstrb           ( emi_resp_if.emi_wstrb    ), //o
    .axi_wlast           ( emi_resp_if.emi_wlast    ), //o
    .axi_wvalid          ( emi_resp_if.emi_wvalid   ), //o
    .axi_wready          ( emi_resp_if.emi_wready   ), //i
    .axi_bvalid          ( emi_resp_if.emi_bvalid   ), //i
    .axi_bready          ( emi_resp_if.emi_bready   )  //o
);
com_axi_extd_rd #(
    .AW                   ( BUS_AW              ), //32
    .DW                   ( BUS_DW              ), //128
    .EBUS_LW              ( BUS_LW              ), //32
    .AXI_LW               ( AXI_LW              ), //4
    .UW                   ( 1                   ), //1
    .BOUND_BYTES          ( BOUND_BYTES         ), //4096
    .MAX_OSD              ( MAX_OSD             ), //128
    .BUF_DEPTH            ( RD_BUF_DEPTH        )  //0
)u_com_axi_extd_rd
(
    .clk                 ( clk                     ), //i
    .rst_n               ( rst_n                   ), //i
    .clear               ( clear                   ), //i
    .i_cfg_max_blen_m1   ( cfg_max_blen_m1         ), //i
    .i_cfg_max_rdcmd_osd ( cfg_max_rdcmd_osd       ), //i
    .o_sta_rdbuf_wl      ( o_sta_rdbuf_wl          ), //o
    .ebus_ra_user        ( '0                      ), //i
    .ebus_ra_addr        ( dma_if.bus_ra_addr      ), //i
    .ebus_ra_bytelen     ( dma_if.bus_ra_bytelen   ), //i
    .ebus_ra_valid       ( dma_if.bus_ra_valid     ), //i
    .ebus_ra_ready       ( dma_if.bus_ra_ready     ), //o
    .ebus_rd_data        ( dma_if.bus_rd_data      ), //o
    .ebus_rd_last        ( dma_if.bus_rd_done      ), //o
    .ebus_rd_valid       ( dma_if.bus_rd_valid     ), //o
    .ebus_rd_ready       ( dma_if.bus_rd_ready     ), //i
    .axi_araddr          ( emi_resp_if.emi_araddr  ), //o
    .axi_arlen           ( emi_resp_if.emi_arlen   ), //o
    .axi_aruser          (                         ), //o
    .axi_arvalid         ( emi_resp_if.emi_arvalid ), //o
    .axi_arready         ( emi_resp_if.emi_arready ), //i
    .axi_rdata           ( emi_resp_if.emi_rdata   ), //i
    .axi_rlast           ( emi_resp_if.emi_rlast   ), //i
    .axi_rvalid          ( emi_resp_if.emi_rvalid  ), //i
    .axi_rready          ( emi_resp_if.emi_rready  )  //o
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
