/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/11-15:35:37
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include com_arbiter_lite.sv
//`include com_pipe_ctrl.sv

`ifndef com_emi_rch_arb_v
`define com_emi_rch_arb_v
module com_emi_rch_arb #( parameter
    AW      = 32        ,
    DW      = 128       ,
    RCH     = 4         ,
    MAX_RCH = 16        ,
    USR_W   = 0         ,

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_RCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

com_emi_if.usr_rch_rx           usr_emi_ifs[RCH-1:0],

output wire                     tx_arvalid          ,
input  wire                     tx_arready          ,
output wire [IW-1:0]            tx_arid             ,
output wire [AW-1:0]            tx_araddr           ,
output wire [7:0]               tx_arlen            ,
output wire [UW-1:0]            tx_aruser           ,

input  wire                     tx_rvalid           ,
output wire                     tx_rready           ,
input  wire [IW-1:0]            tx_rid              ,
input  wire [DW-1:0]            tx_rdata            ,
input  wire                     tx_rlast            ,
input  wire [UW-1:0]            tx_ruser            //,
);
//localparam-----------------------------------------------------------------
//assert( RCH>0 );
//assert( UW>0 );
localparam PRI_MODE= "round_from_small"; //small_first, large_first, round_from_small, round_from_large, round_hold_small, round_hold_large
localparam RCH_IW = $clog2(RCH>2?RCH:2);

localparam SW_L2 = $clog2(SW);
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire [RCH-1:0]             rx_arvalid ;
wire [RCH-1:0]             rx_arready ;
wire [RCH-1:0][AW-1:0]     rx_araddr  ;
wire [RCH-1:0][7:0]        rx_arlen   ;
wire [RCH-1:0][UW-1:0]     rx_aruser  ;
wire [RCH-1:0]             rx_rvalid  ;
wire [RCH-1:0]             rx_rready  ;
wire [RCH-1:0][DW-1:0]     rx_rdata   ;
wire [RCH-1:0]             rx_rlast   ;
wire [RCH-1:0][UW-1:0]     rx_ruser   ;
//statement------------------------------------------------------------------
generate
for( genvar gi=0; gi<RCH; gi++ )begin
    assign rx_arvalid[gi] = usr_emi_ifs[gi].emi_arvalid ;
    assign rx_araddr [gi] = usr_emi_ifs[gi].emi_araddr  ;
    assign rx_arlen  [gi] = usr_emi_ifs[gi].emi_arlen   ;
    assign rx_aruser [gi] = usr_emi_ifs[gi].emi_aruser  ;
    assign usr_emi_ifs[gi].emi_arready = rx_arready[gi] ;

    assign usr_emi_ifs[gi].emi_rvalid = rx_rvalid[gi]   ;
    assign usr_emi_ifs[gi].emi_rdata  = rx_rdata [gi]   ;
    assign usr_emi_ifs[gi].emi_rlast  = rx_rlast [gi]   ;
    assign usr_emi_ifs[gi].emi_ruser  = rx_ruser [gi]   ;
    // assign rx_rready[gi] = usr_emi_ifs[gi].emi_rready;
end
endgenerate

//ra channel---
wire [RCH_IW-1:0] arid;
wire [RCH-1:0]    arr_arvalid;
com_arbiter_lite #(.MODE( PRI_MODE ), .PORT_N( RCH )) r_com_arbiter_lite( .clk(clk),.rst_n(rst_n),.clear(clear),.requests( arr_arvalid ),.grant_id( arid ) );

wire rch_ivld    = |rx_arvalid;
wire rch_irdy    ;
wire rch_ovld    ;
wire rch_ordy    = tx_arready;
wire rch_in_upen ;
com_pipe_ctrl #( .NUM_PIPE(1) ) r_com_pipe_ctrl_ra( clk, rst_n, clear, rch_ivld, rch_irdy, rch_ovld, rch_ordy, rch_in_upen );
assign arr_arvalid = rch_irdy ? rx_arvalid : RCH'(0);

//rx_arready-
reg  [RCH-1:0] arb_ra_rdy;
always @*
begin
    arb_ra_rdy = RCH'(0);
    for( int i=0; i<RCH; i++ )begin
        if( arid==i[RCH_IW-1:0] )
            arb_ra_rdy[i] = rch_irdy;
    end
end
assign rx_arready = arb_ra_rdy;

//ra reg latch-
wire [AW-1:0] rx_araddr_sel = rx_araddr[arid];
wire [AW-1:0] rx_araddr_t = rx_araddr_sel;
// wire [AW-1:0] rx_araddr_t = { rx_araddr_sel[AW-1:SW_L2], {SW_L2{1'b0}} };
//assert( rx_araddr_sel[SW_L2-1:0]==0 );
reg  [IW-1:0] rc_arid   ;
reg  [AW-1:0] rc_araddr ;
reg  [7:0]    rc_arlen  ;
reg  [UW-1:0] rc_aruser ;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_arid   <= 'b0;
        rc_araddr <= 'b0;
        rc_arlen  <= 'b0;
        rc_aruser <= 'b0;
    end
    else if( rch_in_upen )begin
        rc_arid   <= arid + IW'(0);
        rc_araddr <= rx_araddr_t;
        rc_arlen  <= rx_arlen [arid];
        rc_aruser <= rx_aruser[arid];
    end
end

//rd channel---
reg  [RCH-1:0]         arb_rd_vld    ;
reg  [RCH-1:0][DW-1:0] arb_rd_data   ;
reg  [RCH-1:0]         arb_rd_last   ;
reg  [RCH-1:0][UW-1:0] arb_rd_user   ;
always @*
begin
    arb_rd_vld = RCH'(0);
    arb_rd_last= RCH'(0);
    for( int i=0; i<RCH; i++ )begin
        arb_rd_data[i] = tx_rdata;
        arb_rd_user[i] = tx_ruser;

        if( tx_rid==i )begin
            arb_rd_vld[i] = tx_rvalid;
            arb_rd_last[i]= tx_rlast;
        end
    end
end

//out---
assign tx_arvalid = rch_ovld;
assign tx_arid    = rc_arid  ;
assign tx_araddr  = rc_araddr;
assign tx_arlen   = rc_arlen ;
assign tx_aruser  = rc_aruser;

assign rx_rvalid  = arb_rd_vld;
assign rx_rdata   = arb_rd_data;
assign rx_rlast   = arb_rd_last;
assign rx_ruser   = arb_rd_user;
assign rx_rready  = {RCH{1'b1}};
assign tx_rready  = rx_rready[tx_rid];

endmodule //end of com_emi_rch_arb
`endif //end of com_emi_rch_arb_v

