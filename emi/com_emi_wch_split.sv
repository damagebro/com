/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/17-16:14:42
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include com_sync_fifo_reg.sv

`ifndef com_emi_wch_split_v
`define com_emi_wch_split_v
module com_emi_wch_split #( parameter
    AW      = 32        ,
    DW      = 128       ,
    WCH     = 4         ,
    MAX_WCH = 16        ,
    MAX_OSD = 16        ,
    USR_W   = 0         ,
    BOUND_BYTES = 4096  , //must be 2^n, typical value is (512, 1024, 2048, 4096)

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_WCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg---
input  wire [7:0]               max_burst_len       ,
//dp---
input  wire                     rx_awvalid          ,
output wire                     rx_awready          ,
input  wire [IW-1:0]            rx_awid             ,
input  wire [AW-1:0]            rx_awaddr           ,
input  wire [7:0]               rx_awlen            ,
input  wire [UW-1:0]            rx_awuser           ,

input  wire                     rx_wvalid           ,
input  wire                     rx_wready           ,
input  wire                     rx_wlast            ,

output wire                     rx_bvalid           ,
input  wire                     rx_bready           ,
output wire [IW-1:0]            rx_bid              ,

output wire                     tx_awvalid          ,
input  wire                     tx_awready          ,
output wire [IW-1:0]            tx_awid             ,
output wire [AW-1:0]            tx_awaddr           ,
output wire [7:0]               tx_awlen            ,
output wire [UW-1:0]            tx_awuser           ,

input  wire                     tx_wvalid_i         ,
output wire                     tx_wready_i         ,
output wire                     tx_wvalid           ,
input  wire                     tx_wready           ,
output wire                     tx_wlast            ,

input  wire                     tx_bvalid           ,
output wire                     tx_bready           ,
input  wire [IW-1:0]            tx_bid              //,
);
//localparam-----------------------------------------------------------------
localparam BOUND_BYTES_L2 = $clog2(BOUND_BYTES);
localparam SW_L2 = $clog2(SW);
//assert( $clog2(BOUND_BYTES)!=$clog2(BOUND_BYTES+1) ); //BOUND_BYTES==2^n
//assert( AW>BOUND_BYTES_L2 );
//assert( BOUND_BYTES_L2>SW_L2 );
//reg  declare---------------------------------------------------------------
reg  rcb_split_flag;
reg  [7:0]    rc_rem_len;
reg  [AW-1:0] rc_addr;
//wire declare---------------------------------------------------------------
wire ps_split_start;
wire ps_split_done;
wire [7:0] rem_len_nxt;

wire ost_wd_fifo_wr_full ;
wire ost_wd_fifo_rd_empty;
wire ost_wb_fifo_wr_full ;
// wire ost_wb_fifo_rd_empty;
//statement------------------------------------------------------------------

//wa---
wire [7:0] len_sel = rcb_split_flag ? rc_rem_len : rx_awlen;
wire [8:0] len_sub = len_sel - max_burst_len - 1'b1;
wire [7:0] len_out_t = len_sel>max_burst_len ? max_burst_len : len_sel;
wire [7:0] len_out;
wire [7:0] len_out_p1 = len_out + 1'b1;
wire [BOUND_BYTES_L2-1:0] len_out_t_bytes= ((len_out_t+1)<<SW_L2) + BOUND_BYTES_L2'(0);

wire [BOUND_BYTES_L2-1:0] addr_lo_t = rcb_split_flag ? rc_addr[BOUND_BYTES_L2-1:0] : rx_awaddr[BOUND_BYTES_L2-1:0];
wire [BOUND_BYTES_L2-1:0] addr_lo = {addr_lo_t[BOUND_BYTES_L2-1:SW_L2], {SW_L2{1'b0}}};
wire [BOUND_BYTES_L2-0:0] addr_t  = addr_lo + len_out_t_bytes;
wire [BOUND_BYTES_L2-0:0] addr_before_ovf = BOUND_BYTES[BOUND_BYTES_L2-0:0] - addr_lo;
wire [7:0] len_before_ovf_t = addr_before_ovf[BOUND_BYTES_L2-0:SW_L2] + 8'b0;
wire [7:0] len_before_ovf = len_before_ovf_t - 8'd1;

wire b_bnd_need_split = addr_t[BOUND_BYTES_L2] && |addr_t[BOUND_BYTES_L2-1:0];
wire b_len_need_split = len_sel>max_burst_len;
wire b_len_last_split = len_sub[8] && !b_bnd_need_split;
assign len_out = b_bnd_need_split ? len_before_ovf : len_out_t;
assign rem_len_nxt = len_sel - len_out_p1;
//assert( ps_split_done && rem_len_nxt==0 );
assign ps_split_start = (rx_awvalid&&rx_awready) && (b_bnd_need_split||b_len_need_split);
assign ps_split_done  = (tx_awvalid&&tx_awready) && b_len_last_split && rcb_split_flag;

always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rcb_split_flag <= 1'b0;
    end
    else if( clear || ps_split_done )begin
        rcb_split_flag <= 1'b0;
    end
    else if( ps_split_start )begin
        rcb_split_flag <= 1'b1;
    end
end

wire [AW-1:0] addr_out = rcb_split_flag ? rc_addr : rx_awaddr;
wire [AW-1:0] addr_nxt = addr_out + (len_out_p1<<SW_L2);
reg  [IW-1:0] rc_id;
reg  [UW-1:0] rc_user;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_addr <= 'b0;
        rc_rem_len <= 'b0;
    end
    else if( ps_split_start || (rcb_split_flag&&tx_awvalid&&tx_awready) )begin
        rc_addr <= addr_nxt;
        rc_rem_len <= rem_len_nxt;
    end
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_id   <= 'b0;
        rc_user <= 'b0;
    end
    else if( ps_split_start )begin
        rc_id   <= rx_awid ;
        rc_user <= rx_awuser;
    end
end

//wa out-
wire tx_awvalid_t = rcb_split_flag ? 1'b1  : rx_awvalid;
assign tx_awvalid = tx_awvalid_t && !(ost_wd_fifo_wr_full || ost_wb_fifo_wr_full);
assign tx_awid    = rcb_split_flag ? rc_id : rx_awid;
assign tx_awaddr  = addr_out;
assign tx_awlen   = len_out;
assign tx_awuser  = rcb_split_flag ? rc_user : rx_awuser;

wire rx_awready_t = rcb_split_flag ? 1'b0 : tx_awready;
assign rx_awready = rx_awready_t && !(ost_wd_fifo_wr_full || ost_wb_fifo_wr_full);


//ost_fifo_wb---
wire [WCH-1:0] wb_fifo_rd_data;
wire [WCH-1:0] wb_fifo_wr_full;
wire [WCH-1:0] wb_fifo_rd_empty;
generate
for( genvar gi=0; gi<WCH; gi++ )begin: gen_split_wb
    wire           split_wr_en    = tx_awvalid&&tx_awready && tx_awid==gi;
    wire [1 -1:0]  split_wr_data  = {b_len_last_split};
    wire           split_wr_full  ;
    wire           split_rd_en    = tx_bvalid&&tx_bready && tx_bid==gi;
    wire [1 -1:0]  split_rd_data  ;
    wire           split_rd_empty ;
    com_sync_fifo_reg #(
        .DW         ( 1      ), //8
        .DEPTH      ( MAX_OSD)  //4
    )r_com_sync_fifo_reg_split_wb
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i

        .wr_en                ( split_wr_en          ), //i
        .wr_data              ( split_wr_data        ), //i
        .wr_full              ( split_wr_full        ), //o
        .rd_en                ( split_rd_en          ), //i
        .rd_data              ( split_rd_data        ), //o
        .rd_empty             ( split_rd_empty       ), //o
        .water_level          (                      )  //o
    );
    assign wb_fifo_rd_data [gi] = split_rd_data;
    assign wb_fifo_wr_full [gi] = split_wr_full;
    assign wb_fifo_rd_empty[gi] = split_rd_empty;
end
endgenerate

assign rx_bvalid = wb_fifo_rd_empty[tx_bid] ? 1'b0 : (tx_bvalid && wb_fifo_rd_data[tx_bid]);
assign rx_bid    = tx_bid   ;
assign tx_bready = rx_bready;
// assign ost_wb_fifo_rd_empty = |wb_fifo_rd_empty;
assign ost_wb_fifo_wr_full  = |wb_fifo_wr_full ;

//ost_fifo_wd&wlast---
wire       ost_wd_wr_en    = tx_awvalid&&tx_awready;
wire [7:0] ost_wd_wr_data  = tx_awlen;
wire       ost_wd_wr_full  ;
wire       ost_wd_rd_en    = tx_wvalid&&tx_wready&&tx_wlast;
wire [7:0] ost_wd_rd_data  ;
wire       ost_wd_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 8        ), //8
    .DEPTH      ( MAX_OSD  )  //4
)r_com_sync_fifo_reg_ost_wd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( ost_wd_wr_en         ), //i
    .wr_data              ( ost_wd_wr_data       ), //i
    .wr_full              ( ost_wd_wr_full       ), //o
    .rd_en                ( ost_wd_rd_en         ), //i
    .rd_data              ( ost_wd_rd_data       ), //o
    .rd_empty             ( ost_wd_rd_empty      ), //o
    .water_level          (                      )  //o
);
wire [7:0] tx_wlen = ost_wd_rd_data;
assign ost_wd_fifo_rd_empty = ost_wd_rd_empty;
assign ost_wd_fifo_wr_full  = ost_wd_wr_full ;
assign tx_wvalid   = ost_wd_rd_empty ? 1'b0 : tx_wvalid_i;
assign tx_wready_i = ost_wd_rd_empty ? 1'b0 : tx_wready  ;

wire rx_whs = rx_wvalid && rx_wready;
wire tx_whs = tx_wvalid && tx_wready;
reg  [7:0] rc_rx_wcnt;
reg  [7:0] rc_tx_wcnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_rx_wcnt <= 'b0;
    end
    else if( clear || (rx_whs&&rx_wlast) )begin
        rc_rx_wcnt <= 'b0;
    end
    else if( rx_whs )begin
        rc_rx_wcnt <= rc_rx_wcnt + 1'b1;
    end
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_tx_wcnt <= 'b0;
    end
    else if( clear || (tx_whs&&tx_wlast) )begin
        rc_tx_wcnt <= 'b0;
    end
    else if( tx_whs )begin
        rc_tx_wcnt <= rc_tx_wcnt + 1'b1;
    end
end
assign tx_wlast = tx_wvalid && rc_tx_wcnt==tx_wlen;


//debug only begin---
wire       dbg_rx_wlen_wr_en    = rx_awvalid&&rx_awready;
wire [7:0] dbg_rx_wlen_wr_data  = rx_awlen;
wire       dbg_rx_wlen_wr_full  ;
wire       dbg_rx_wlen_rd_en    ;
wire [7:0] dbg_rx_wlen_rd_data  ;
wire       dbg_rx_wlen_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 8        ), //8
    .DEPTH      ( MAX_OSD+4)  //4
)r_com_sync_fifo_reg_dbg_rx_wlen
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( dbg_rx_wlen_wr_en    ), //i
    .wr_data              ( dbg_rx_wlen_wr_data  ), //i
    .wr_full              ( dbg_rx_wlen_wr_full  ), //o
    .rd_en                ( dbg_rx_wlen_rd_en    ), //i
    .rd_data              ( dbg_rx_wlen_rd_data  ), //o
    .rd_empty             ( dbg_rx_wlen_rd_empty ), //o
    .water_level          (                      )  //o
);
wire dbg_rx_wd_wr_en    = rx_wvalid&&rx_wready&&rx_wlast;
wire dbg_rx_wd_wr_data  = 1'b0; //not use
wire dbg_rx_wd_wr_full  ;
wire dbg_rx_wd_rd_en    ;
wire dbg_rx_wd_rd_data  ;
wire dbg_rx_wd_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 1        ), //8
    .DEPTH      ( MAX_OSD+4)  //4
)r_com_sync_fifo_reg_dbg_rx_wd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( dbg_rx_wd_wr_en      ), //i
    .wr_data              ( dbg_rx_wd_wr_data    ), //i
    .wr_full              ( dbg_rx_wd_wr_full    ), //o
    .rd_en                ( dbg_rx_wd_rd_en      ), //i
    .rd_data              ( dbg_rx_wd_rd_data    ), //o
    .rd_empty             ( dbg_rx_wd_rd_empty   ), //o
    .water_level          (                      )  //o
);
assign dbg_rx_wlen_rd_en = !dbg_rx_wlen_rd_empty && !dbg_rx_wd_rd_empty;
assign dbg_rx_wd_rd_en   = !dbg_rx_wlen_rd_empty && !dbg_rx_wd_rd_empty;
wire [7:0] rx_wlen = dbg_rx_wlen_rd_data;
//assert( rc_rx_wcnt==rx_wlen && rx_whs&&rx_wlast && !dbg_rx_wlen_rd_empty );
//debug only end  ---

endmodule //end of com_emi_wch_split
`endif //end of com_emi_wch_split_v

