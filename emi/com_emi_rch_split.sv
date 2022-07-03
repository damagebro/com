/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/12-09:35:34
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include com_sync_fifo_reg.sv

`ifndef com_emi_rch_split_v
`define com_emi_rch_split_v
module com_emi_rch_split #( parameter
    AW      = 32        ,
    DW      = 128       ,
    RCH     = 4         ,
    MAX_RCH = 16        ,
    MAX_OSD = 16        ,
    USR_W   = 0         ,
    BOUND_BYTES = 4096  , //must be 2^n, typical value is (512, 1024, 2048, 4096)

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_RCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg---
input  wire [7:0]               max_burst_len       ,
//dp---
input  wire                     rx_arvalid          ,
output wire                     rx_arready          ,
input  wire [IW-1:0]            rx_arid             ,
input  wire [AW-1:0]            rx_araddr           ,
input  wire [7:0]               rx_arlen            ,
input  wire [UW-1:0]            rx_aruser           ,

output wire                     rx_rvalid           ,
input  wire                     rx_rready           ,
output wire [IW-1:0]            rx_rid              ,
output wire                     rx_rlast            ,

output wire                     tx_arvalid          ,
input  wire                     tx_arready          ,
output wire [IW-1:0]            tx_arid             ,
output wire [AW-1:0]            tx_araddr           ,
output wire [7:0]               tx_arlen            ,
output wire [UW-1:0]            tx_aruser           ,

input  wire                     tx_rvalid           ,
output wire                     tx_rready           ,
input  wire [IW-1:0]            tx_rid              ,
input  wire                     tx_rlast            //,
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

wire [RCH-1:0] ost_fifo_rd_data;
wire [RCH-1:0] ost_fifo_wr_full;
wire [RCH-1:0] ost_fifo_rd_empty;
//statement------------------------------------------------------------------
//ra---
wire [7:0] len_sel = rcb_split_flag ? rc_rem_len : rx_arlen;
wire [8:0] len_sub = len_sel - max_burst_len - 1'b1; //spyglass disable W164b
wire [7:0] len_out_t = len_sel>max_burst_len ? max_burst_len : len_sel;
wire [7:0] len_out;
wire [7:0] len_out_p1 = len_out + 1'b1;
wire [BOUND_BYTES_L2-1:0] len_out_t_bytes= ((len_out_t+1)<<SW_L2) + BOUND_BYTES_L2'(0);

wire [BOUND_BYTES_L2-1:0] addr_lo_t = rcb_split_flag ? rc_addr[BOUND_BYTES_L2-1:0] : rx_araddr[BOUND_BYTES_L2-1:0];
wire [BOUND_BYTES_L2-1:0] addr_lo = {addr_lo_t[BOUND_BYTES_L2-1:SW_L2], {SW_L2{1'b0}}};
wire [BOUND_BYTES_L2-0:0] addr_t  = addr_lo + len_out_t_bytes; //spyglass disable W164b
wire [BOUND_BYTES_L2-0:0] addr_before_ovf = BOUND_BYTES[BOUND_BYTES_L2-0:0] - addr_lo;
wire [7:0] len_before_ovf_t = addr_before_ovf[BOUND_BYTES_L2-0:SW_L2] + 8'b0;
wire [7:0] len_before_ovf = len_before_ovf_t - 8'd1;

wire b_bnd_need_split = addr_t[BOUND_BYTES_L2] && |addr_t[BOUND_BYTES_L2-1:0];
wire b_len_need_split = len_sel>max_burst_len;
wire b_len_last_split = len_sub[8] && !b_bnd_need_split;
assign len_out = b_bnd_need_split ? len_before_ovf : len_out_t;
assign rem_len_nxt = len_sel - len_out_p1;
//assert( ps_split_done && rem_len_nxt==0 );
assign ps_split_start = (rx_arvalid&&rx_arready) && (b_bnd_need_split||b_len_need_split);
assign ps_split_done  = (tx_arvalid&&tx_arready) && b_len_last_split && rcb_split_flag;

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

wire [AW-1:0] addr_out = rcb_split_flag ? rc_addr : rx_araddr;
wire [AW-1:0] addr_nxt = addr_out + (len_out_p1<<SW_L2);
reg  [IW-1:0] rc_id;
reg  [UW-1:0] rc_user;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_addr <= 'b0;
        rc_rem_len <= 'b0;
    end
    else if( ps_split_start || (rcb_split_flag&&tx_arvalid&&tx_arready) )begin
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
        rc_id   <= rx_arid ;
        rc_user <= rx_aruser;
    end
end
//ra out-
wire           ost_wr_en    = tx_arvalid&&tx_arready;
wire [1 -1:0]  ost_wr_data  = 1'b0;
wire           ost_wr_full  ;
wire           ost_rd_en    = tx_rvalid&&tx_rready&&tx_rlast;
wire [1 -1:0]  ost_rd_data  ;
wire           ost_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 1      ), //8
    .DEPTH      ( MAX_OSD)  //4
)r_com_sync_fifo_reg_ost
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( ost_wr_en            ), //i
    .wr_data              ( ost_wr_data          ), //i
    .wr_full              ( ost_wr_full          ), //o
    .rd_en                ( ost_rd_en            ), //i
    .rd_data              ( ost_rd_data          ), //o
    .rd_empty             ( ost_rd_empty         ), //o
    .water_level          (                      )  //o
);

wire tx_arvalid_t = rcb_split_flag ? 1'b1  : rx_arvalid;
assign tx_arvalid = tx_arvalid_t && !(|ost_fifo_wr_full) && !ost_wr_full;
assign tx_arid    = rcb_split_flag ? rc_id : rx_arid;
assign tx_araddr  = addr_out;
assign tx_arlen   = len_out;
assign tx_aruser  = rcb_split_flag ? rc_user : rx_aruser;

wire rx_arready_t = rcb_split_flag ? 1'b0 : tx_arready;
assign rx_arready = rx_arready_t && !(|ost_fifo_wr_full) && !ost_wr_full;


//rd---
generate
for( genvar gi=0; gi<RCH; gi++ )begin: gen_split_rd
    wire           split_wr_en    = tx_arvalid&&tx_arready && tx_arid==gi;
    wire [1 -1:0]  split_wr_data  = {b_len_last_split};
    wire           split_wr_full  ;
    wire           split_rd_en    = tx_rvalid&&tx_rready&&tx_rlast && tx_rid==gi;
    wire [1 -1:0]  split_rd_data  ;
    wire           split_rd_empty ;
    com_sync_fifo_reg #(
        .DW         ( 1      ), //8
        .DEPTH      ( MAX_OSD)  //4
    )r_com_sync_fifo_reg_split_rd
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
    assign ost_fifo_rd_data [gi] = split_rd_data;
    assign ost_fifo_wr_full [gi] = split_wr_full;
    assign ost_fifo_rd_empty[gi] = split_rd_empty;
end
endgenerate

//rd out-
assign rx_rvalid = tx_rvalid;
assign rx_rid    = tx_rid   ;
assign rx_rlast  = ost_fifo_rd_empty[tx_rid] ? 1'b0 : (tx_rlast && ost_fifo_rd_data[tx_rid]);
assign tx_rready = rx_rready;


//debug only begin-
reg  [RCH-1:0][7:0] arc_txrd_cnt;//data transfer cnt;
reg  [RCH-1:0][7:0] arc_rxrd_cnt;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        arc_txrd_cnt <= 'b0;
        arc_rxrd_cnt <= 'b0;
    end
    else begin
        for( int i=0; i<RCH; i++ )begin
            if( tx_rvalid&&tx_rready && tx_rid==i )begin
                if( tx_rlast )
                    arc_txrd_cnt[i] <= 'b0;
                else
                    arc_txrd_cnt[i] <= arc_txrd_cnt[i] + 1'b1;
            end

            if( rx_rvalid&&rx_rready && rx_rid==i )begin
                if( rx_rlast )
                    arc_rxrd_cnt[i] <= 'b0;
                else
                    arc_rxrd_cnt[i] <= arc_rxrd_cnt[i] + 1'b1;
            end
        end//end of for
    end//end of else
end

generate
for( genvar gi=0; gi<RCH; gi++ )begin: gen_dbg_split_rd
    wire             dbg_tx_wr_en    = tx_arvalid&&tx_arready && tx_arid==gi;
    wire [8+1 -1:0]  dbg_tx_wr_data  = {tx_arlen,b_len_last_split};
    wire             dbg_tx_wr_full  ;
    wire             dbg_tx_rd_en    = tx_rvalid&&tx_rready&&tx_rlast && tx_rid==gi;
    wire [8+1 -1:0]  dbg_tx_rd_data  ;
    wire             dbg_tx_rd_empty ;
    com_sync_fifo_reg #(
        .DW         ( 8+1    ), //8
        .DEPTH      ( MAX_OSD)  //4
    )r_com_sync_fifo_reg_dbg_tx_rd
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i

        .wr_en                ( dbg_tx_wr_en      ), //i
        .wr_data              ( dbg_tx_wr_data    ), //i
        .wr_full              ( dbg_tx_wr_full    ), //o
        .rd_en                ( dbg_tx_rd_en      ), //i
        .rd_data              ( dbg_tx_rd_data    ), //o
        .rd_empty             ( dbg_tx_rd_empty   ), //o
        .water_level          (                      )  //o
    );

    wire           dbg_rx_wr_en    = rx_arvalid&&rx_arready && rx_arid==gi;
    wire [8 -1:0]  dbg_rx_wr_data  = rx_arlen;
    wire           dbg_rx_wr_full  ;
    wire           dbg_rx_rd_en    = rx_rvalid&&rx_rready&&rx_rlast && rx_rid==gi;
    wire [8 -1:0]  dbg_rx_rd_data  ;
    wire           dbg_rx_rd_empty ;
    com_sync_fifo_reg #(
        .DW         ( 8      ), //8
        .DEPTH      ( MAX_OSD)  //4
    )r_com_sync_fifo_reg_dbg_rx_rd
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i

        .wr_en                ( dbg_rx_wr_en      ), //i
        .wr_data              ( dbg_rx_wr_data    ), //i
        .wr_full              ( dbg_rx_wr_full    ), //o
        .rd_en                ( dbg_rx_rd_en      ), //i
        .rd_data              ( dbg_rx_rd_data    ), //o
        .rd_empty             ( dbg_rx_rd_empty   ), //o
        .water_level          (                      )  //o
    );
end
endgenerate
//debug only end-

endmodule //end of com_emi_rch_split
`endif //end of com_emi_rch_split_v

