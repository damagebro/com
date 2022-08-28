/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/10/21-11:35:17
*
*  Description:
*  -fifo_ram data path:
*   (1)!out_fifo_wr_full && ram_fifo_rd_empty,  wr_en->out_fifo;
*   (2) out_fifo_wr_full && ram_fifo_rd_empty,  wr_en->ram_fifo->out_fifo;
*   (3)!ram_fifo_rd_empty,  wr_en->ram_fifo->out_fifo;
*  -water_level means (out_fifo_depth + ram_fifo_depth);
*  -RAM_DEPTH is sum of 2's spram depth;
*--------------
*  -advantage: when SPRAM_DEPTH=TPRAM_DEPTH*2, as for spram, the area is nearly the same, but the capacity twice than tpram;
*
*  Modify:
*  2022/8/28, use ibuf(depth=1) instand of in_fifo
*
******************************************************************************/

`ifndef com_sync_fifo_ram_1p2bank_v
`define com_sync_fifo_ram_1p2bank_v
module com_sync_fifo_ram_1p2bank #( parameter
    DW = 8,
    RAM_DEPTH = 4, //ram_depth,
    OUT_DEPTH = 3,
    RAM_ONE_DEPTH = RAM_DEPTH/2,
    TOL_DEPTH = RAM_DEPTH+OUT_DEPTH,
    TOL_AW    = $clog2(TOL_DEPTH+1),
    RAM_ONE_AW= $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2)//,
)
(
input  wire                       clk               ,
input  wire                       rst_n             ,
input  wire                       clear             ,

input  wire                       wr_en             ,
input  wire [DW-1:0]              wr_data           ,
output wire                       wr_full           ,
input  wire                       rd_en             ,
output wire [DW-1:0]              rd_data           ,
output wire                       rd_empty          ,
output wire [TOL_AW-1:0]          water_level       ,

output wire [1:0]                 ram_cen           ,
output wire [1:0]                 ram_we            ,
output wire [1:0][RAM_ONE_AW-1:0] ram_addr          ,
output wire [1:0][DW-1:0]         ram_din           ,
input  wire [1:0][DW-1:0]         ram_qout          //,
);
//localparam-----------------------------------------------------------------
localparam RAM_AW = $clog2(RAM_DEPTH+1);
localparam RAM_CW = $clog2(RAM_DEPTH+1);
localparam OUT_AW = $clog2(OUT_DEPTH+1);

`COM_PARAM_ASSERT( OUT_DEPTH>=3, "fifo_1p2bank out_depth must larger than 3" );
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire out_wr_full;
wire out_rd_empty;

wire ram_wr_en    ;
wire ram_wr_full  ;
wire ram_rd_empty ;
wire ram_rd_en    ;
wire ram_rd_ack   ;
wire ram_rd_empty_do = ram_rd_empty && !ram_rd_ack;
wire [DW-1:0] ram_rd_data;
//statement------------------------------------------------------------------

//out fifo---
wire              out_wr_en_tmp= !ram_rd_empty_do ? ram_rd_ack  : wr_en;
wire              out_wr_en    = out_wr_en_tmp && !out_wr_full;
wire [DW-1:0]     out_wr_data  = !ram_rd_empty_do ? ram_rd_data : wr_data;
wire              out_rd_en    = rd_en;
wire [DW-1:0]     out_rd_data  ;
wire [OUT_AW-1:0] out_water_level;
com_sync_fifo_reg #(
    .DW         ( DW         ), //8
    .DEPTH      ( OUT_DEPTH  )  //4
)r_com_sync_fifo_reg_out
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( out_wr_en            ), //i
    .wr_data              ( out_wr_data          ), //i
    .wr_full              ( out_wr_full          ), //o
    .rd_en                ( out_rd_en            ), //i
    .rd_data              ( out_rd_data          ), //o
    .rd_empty             ( out_rd_empty         ), //o
    .water_level          ( out_water_level      )  //o
);
assign rd_data = out_rd_data;
assign rd_empty= out_rd_empty;
assign wr_full = ram_wr_full;

//ram fifo---
generate
if( RAM_DEPTH>0 )begin:GEN_RAM_FIFO
    wire [RAM_AW-1:0] ram_wr_addr;
    wire [RAM_AW-1:0] ram_rd_addr;
    wire [RAM_CW-1:0] ram_water_level_t;
    com_sync_fifo_ctrl #(
        .DEPTH      ( RAM_DEPTH      )  //4
    )u_com_sync_fifo_ctrl_ram
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i

        .wr_en                ( ram_wr_en            ), //i
        .wr_addr              ( ram_wr_addr          ), //o
        .wr_full              ( ram_wr_full          ), //o
        .rd_en                ( ram_rd_en            ), //i
        .rd_addr              ( ram_rd_addr          ), //o
        .rd_empty             ( ram_rd_empty         ), //o
        .water_level          ( ram_water_level_t    )  //o
    );
    wire [RAM_AW-0:0] ram_water_level = {1'b0,ram_water_level_t} - ram_rd_ack;

    //in buf---
    //deal 2sram conflic bellow
    // >>>
    // T1: 写ping(d0);
    // T2: 写pong(d1);
    // T3: 写ping(d2), 读ping(d0);  读写冲突，d2->ibuf
    // T4: 写pong(d3); //若读pong(d1), 对应情况(1)
    // T5: 写ping(d4); //若读pong(d1), 对应情况(3)
    // //T3发生冲突后，T4~T5时钟周期有以下4种情况
    // (1) T4又写又读, 写pong(d3)->ibuf, 读pong(d1), ibuf(d2)->ping;
    // (2) T4不写不读, ibuf(d2)->ping;
    // (3) T4只写不读, 写pong(d3), ibuf(d2)->ping
    // (4) T4不写只读, 读pong(d1), ibuf(d2)->ping
    // >>>
    reg  rc_ibuf_busy;
    wire ram_conflict = ram_wr_en&&ram_rd_en && ram_wr_addr[0]==ram_rd_addr[0];
    wire [RAM_AW-1:0] ram_conflict_addr = ram_wr_addr-1'b1;
    wire after_conflict_cond1 = rc_ibuf_busy &&  ram_wr_en&& ram_rd_en;
    wire after_conflict_cond2 = rc_ibuf_busy && !ram_wr_en&&!ram_rd_en;
    wire after_conflict_cond3 = rc_ibuf_busy &&  ram_wr_en&&!ram_rd_en;
    wire after_conflict_cond4 = rc_ibuf_busy && !ram_wr_en&& ram_rd_en;
    wire ibuf_wr_en = ram_conflict;
    wire ibuf_rd_en = rc_ibuf_busy && !ram_conflict;
    reg  [DW-1:0] rc_ibuf;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            rc_ibuf_busy <= 1'b0;
        else if( clear )
            rc_ibuf_busy <= 1'b0;
        else if( ibuf_wr_en )
            rc_ibuf_busy <= 1'b1;
        else if( ibuf_rd_en )
            rc_ibuf_busy <= 1'b0;
    end
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            rc_ibuf <= 'b0;
        else if( ibuf_wr_en )
            rc_ibuf <= wr_data;
    end

    //ram signal
    reg  rc_ram_rd_ack;
    reg  rc_rd_banksel_flag;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n ) begin
            rc_ram_rd_ack <= 1'b0;
            rc_rd_banksel_flag <= 1'b0;
        end
        else begin
            rc_ram_rd_ack <= ram_rd_en;
            rc_rd_banksel_flag <= ram_rd_en && ram_rd_addr[0];
        end
    end
    assign ram_rd_ack = rc_ram_rd_ack;

    wire [OUT_AW-0:0] out_buf_needed = out_wr_en + (OUT_AW+1)'(0);
    wire   ram_wr_en_t = !ram_rd_empty_do || out_wr_full ? wr_en : 1'b0;
    wire   ram_rd_en_t = !ram_rd_empty && {1'b0,out_water_level}>out_buf_needed;
    // assign ram_wr_en   = ram_wr_en_t && !ram_wr_hold;
    // assign ram_rd_en   = ram_rd_en_t;
    assign ram_wr_en = ram_wr_en_t;
    assign ram_rd_en = ram_rd_en_t;
    assign water_level = out_water_level + ram_water_level; //spyglass disable W164b

    // assign ram_wr_hold = ram_rd_en && (ram_wr_addr[0]==ram_rd_addr[0]);
    // assign ram_rd_hold = ram_rd_en_t && ram_wr_en && (ram_wr_addr[0]==ram_rd_addr[0]);
    wire ram_wr_en_do = ram_wr_en && !ram_conflict;
    assign ram_cen [0] = !( (ram_wr_en_do && ram_wr_addr[0]==1'b0) || (ram_rd_en && ram_rd_addr[0]==1'b0) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b0) );
    assign ram_we  [0] = (ram_wr_en_do && ram_wr_addr[0]==1'b0) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b0);
    assign ram_addr[0] = (ram_wr_en_do && ram_wr_addr[0]==1'b0) ? ram_wr_addr[RAM_AW-1:1] : (rc_ibuf_busy && ram_conflict_addr[0]==1'b0) ? ram_conflict_addr[RAM_AW-1:1] : ram_rd_addr[RAM_AW-1:1];
    assign ram_din [0] = (rc_ibuf_busy && ram_conflict_addr[0]==1'b0) ? rc_ibuf : wr_data;
    assign ram_cen [1] = !( (ram_wr_en_do && ram_wr_addr[0]==1'b1) || (ram_rd_en && ram_rd_addr[0]==1'b1) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b1) );
    assign ram_we  [1] = (ram_wr_en_do && ram_wr_addr[0]==1'b1) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b1);
    assign ram_addr[1] = (ram_wr_en_do && ram_wr_addr[0]==1'b1) ? ram_wr_addr[RAM_AW-1:1] : (rc_ibuf_busy && ram_conflict_addr[0]==1'b1) ? ram_conflict_addr[RAM_AW-1:1] : ram_rd_addr[RAM_AW-1:1];
    assign ram_din [1] = (rc_ibuf_busy && ram_conflict_addr[0]==1'b1) ? rc_ibuf : wr_data;
    assign ram_rd_data = !rc_rd_banksel_flag ? ram_qout[0] : ram_qout[1];
end//end of if(RAM_DEPTH)
else begin:GEN_NO_RAM_FIFO
    assign ram_wr_full  = 1'b0;
    assign ram_rd_empty = 1'b1;
    assign ram_rd_ack   = 1'b0;

    assign ram_wr_en   = 1'b0;
    assign ram_rd_en   = 1'b0;
    assign water_level = out_water_level; //spyglass disable W164b

    // assign ram_wr_hold = 1'b0;
    assign ram_rd_hold = 1'b0;
    assign ram_cen [0] = 1'b0;
    assign ram_we  [0] = 1'b0;
    assign ram_addr[0] = RAM_ONE_AW'(0);
    assign ram_din [0] = DW'(0);
    assign ram_cen [1] = 1'b0;
    assign ram_we  [1] = 1'b0;
    assign ram_addr[1] = RAM_ONE_AW'(0);
    assign ram_din [1] = DW'(0);
    assign ram_rd_data = DW'(0);
end//end of else(RAM_DEPTH)
endgenerate

endmodule //end of com_sync_fifo_ram_1p2bank
`endif //end of com_sync_fifo_ram_1p2bank_v

