/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/17-10:54:12
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include com_arbiter.sv
//`include com_pipe_ctrl_cell.sv
//`include com_sync_fifo_reg.sv

`ifndef com_emi_wch_arb_v
`define com_emi_wch_arb_v
module com_emi_wch_arb #( parameter
    AW      = 32        ,
    DW      = 128       ,
    WCH     = 4         ,
    MAX_WCH = 16        ,
    MAX_OSD = 16        ,
    USR_W   = 0         ,

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_WCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

com_emi_if.usr_wch_rx           usr_emi_ifs[WCH-1:0],

output wire                     tx_awvalid          ,
input  wire                     tx_awready          ,
output wire [IW-1:0]            tx_awid             ,
output wire [AW-1:0]            tx_awaddr           ,
output wire [7:0]               tx_awlen            ,
output wire [UW-1:0]            tx_awuser           ,

output wire                     tx_wvalid           ,
input  wire                     tx_wready           ,
// output wire [IW-1:0]            tx_wid              ,
output wire [DW-1:0]            tx_wdata            ,
output wire [SW-1:0]            tx_wstrb            ,
output wire                     tx_wlast            ,
output wire [UW-1:0]            tx_wuser            ,

input  wire                     tx_bvalid           ,
output wire                     tx_bready           ,
input  wire [IW-1:0]            tx_bid              ,
input  wire [UW-1:0]            tx_buser            //,
);
//localparam-----------------------------------------------------------------
//assert( WCH>0 );
//assert( UW>0 );
localparam PRI_MODE= "round_from_small"; //small_first, large_first, round_from_small, round_from_large, round_hold_small, round_hold_large
localparam WCH_IW = $clog2(WCH>2?WCH:2);

localparam SW_L2 = $clog2(SW);
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire [WCH-1:0]         rx_awvalid ;
wire [WCH-1:0]         rx_awready ;
wire [WCH-1:0][AW-1:0] rx_awaddr  ;
wire [WCH-1:0][7:0]    rx_awlen   ;
wire [WCH-1:0][UW-1:0] rx_awuser  ;
wire [WCH-1:0]         rx_wvalid  ;
wire [WCH-1:0]         rx_wready  ;
wire [WCH-1:0][DW-1:0] rx_wdata   ;
wire [WCH-1:0][SW-1:0] rx_wstrb   ;
wire [WCH-1:0]         rx_wlast   ;
wire [WCH-1:0][UW-1:0] rx_wuser   ;
wire [WCH-1:0]         rx_bvalid  ;
wire [WCH-1:0]         rx_bready  ;
wire [WCH-1:0][UW-1:0] rx_buser   ;
//statement------------------------------------------------------------------
generate
for( genvar gi=0; gi<WCH; gi++ )begin
    assign rx_awvalid[gi] = usr_emi_ifs[gi].emi_awvalid ;
    assign rx_awaddr [gi] = usr_emi_ifs[gi].emi_awaddr  ;
    assign rx_awlen  [gi] = usr_emi_ifs[gi].emi_awlen   ;
    assign rx_awuser [gi] = usr_emi_ifs[gi].emi_awuser  ;
    assign usr_emi_ifs[gi].emi_awready = rx_awready[gi] ;

    assign rx_wvalid[gi] = usr_emi_ifs[gi].emi_wvalid;
    assign rx_wdata [gi] = usr_emi_ifs[gi].emi_wdata ;
    assign rx_wstrb [gi] = usr_emi_ifs[gi].emi_wstrb ;
    assign rx_wlast [gi] = usr_emi_ifs[gi].emi_wlast ;
    assign rx_wuser [gi] = usr_emi_ifs[gi].emi_wuser ;
    assign usr_emi_ifs[gi].emi_wready = rx_wready[gi];

    assign usr_emi_ifs[gi].emi_bvalid = rx_bvalid[gi];
    assign usr_emi_ifs[gi].emi_buser  = rx_buser [gi];
    // assign rx_bready[gi] = usr_emi_ifs[gi].emi_bready;
end
endgenerate

//wa channel---
wire [WCH_IW-1:0] awid;
wire [WCH-1:0]    arr_awvalid;
com_arbiter_lite #(.MODE( PRI_MODE ), .PORT_N( WCH )) r_com_arbiter_lite( .clk(clk),.rst_n(rst_n),.clear(clear),.requests( arr_awvalid ),.grant_id( awid ) );

wire wch_ivld    = |rx_awvalid;
wire wch_irdy    ;
wire wch_ovld    ;
wire wch_ordy    = tx_awready;
wire wch_in_upen ;
com_pipe_ctrl #( .NUM_PIPE(1) ) r_com_pipe_ctrl_wa( clk, rst_n, clear, wch_ivld, wch_irdy, wch_ovld, wch_ordy, wch_in_upen );
assign arr_awvalid = wch_irdy ? rx_awvalid : WCH'(0);

//rx_awready-
reg  [WCH-1:0] arb_wa_rdy;
always @*
begin
    arb_wa_rdy = WCH'(0);
    for( int i=0; i<WCH; i++ )begin
        if( awid==i[WCH_IW-1:0] ) //spyglass disable W216
            arb_wa_rdy[i] = wch_irdy;  //spyglass disable W415a
    end
end
assign rx_awready = arb_wa_rdy;

//wa reg latch-
wire [AW-1:0] rx_awaddr_sel = rx_awaddr[awid];
wire [AW-1:0] rx_awaddr_t = rx_awaddr_sel;
// wire [AW-1:0] rx_awaddr_t = { rx_awaddr_sel[AW-1:SW_L2], {SW_L2{1'b0}} };
//assert( rx_awaddr_sel[SW_L2-1:0]==0 );
reg  [IW-1:0] rc_awid   ;
reg  [AW-1:0] rc_awaddr ;
reg  [7:0]    rc_awlen  ;
reg  [UW-1:0] rc_awuser ;
reg  [SW_L2-1:0] rc_awaddr_lo;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_awid   <= 'b0;
        rc_awaddr <= 'b0;
        rc_awlen  <= 'b0;
        rc_awuser <= 'b0;
        rc_awaddr_lo <= 'b0;
    end
    else if( wch_in_upen )begin
        rc_awid   <= awid + IW'(0);
        rc_awaddr <= rx_awaddr_t;
        rc_awlen  <= rx_awlen [awid];
        rc_awuser <= rx_awuser[awid];
        rc_awaddr_lo <= rx_awaddr_sel[SW_L2-1:0];
    end
end

//wd channel---
wire              wch_wr_en    = wch_in_upen;
wire [WCH_IW-1:0] wch_wr_data  = awid;
wire              wch_wr_full  ;
wire              wch_rd_en    = tx_wvalid&&tx_wready&&tx_wlast;
wire [WCH_IW-1:0] wch_rd_data  ;
wire              wch_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( WCH_IW   ), //8
    .DEPTH      ( MAX_OSD+4)  //4
)r_com_sync_fifo_reg_arb_wch
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wch_wr_en            ), //i
    .wr_data              ( wch_wr_data          ), //i
    .wr_full              ( wch_wr_full          ), //o
    .rd_en                ( wch_rd_en            ), //i
    .rd_data              ( wch_rd_data          ), //o
    .rd_empty             ( wch_rd_empty         ), //o
    .water_level          (                      )  //o
);
wire [WCH_IW-1:0] wid = wch_rd_data;

//rx_wready-
reg  [WCH-1:0] arb_wd_rdy;
always @*
begin
    arb_wd_rdy = WCH'(0);
    if( !wch_rd_empty )begin
        for( int i=0; i<WCH; i++ )begin
            if( wid==i[WCH_IW-1:0] ) //spyglass disable W216
                arb_wd_rdy[i] = !wch_wr_full && tx_wready;  //spyglass disable W415a
        end
    end
end
assign rx_wready = arb_wd_rdy;
//assert( !wch_wr_full );

//wb--
reg  [WCH-1:0]         arb_wb_vld ;
reg  [WCH-1:0][UW-1:0] arb_wb_user;
always @*
begin
    arb_wb_vld = WCH'(0);
    for( int i=0; i<WCH; i++ )begin
        arb_wb_user[i] = tx_buser;

        if( tx_bid==i )begin
            arb_wb_vld[i] = tx_bvalid; //spyglass disable W415a
        end
    end
end

//out---
wire [SW-1:0] awstrb = |rc_awaddr_lo ? ((1<<rc_awaddr_lo) - 1) : {SW{1'b1}}; //spyglass disable W164b,W528
assign tx_awvalid = wch_ovld;
assign tx_awid    = rc_awid  ;
assign tx_awaddr  = rc_awaddr;
assign tx_awlen   = rc_awlen ;
assign tx_awuser  = rc_awuser;
// assign tx_awstrb_tmp = awstrb;

assign tx_wvalid  = rx_wvalid[wid] && !wch_rd_empty;
// assign tx_wid     = wid + IW'(0);
assign tx_wdata   = rx_wdata [wid];
assign tx_wstrb   = rx_wstrb [wid];
assign tx_wlast   = rx_wlast [wid];
assign tx_wuser   = rx_wuser [wid];

assign rx_bvalid = arb_wb_vld ;
assign rx_buser  = arb_wb_user;
assign rx_bready  = {WCH{1'b1}};
assign tx_bready  = rx_bready[tx_bid];

endmodule //end of com_emi_wch_arb
`endif //end of com_emi_wch_arb_v

