/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/08/13-20:00:23
*
*  Description:
*  -fifo_ram data path:
*   (1)!out_fifo_wr_full,  wr_en->out_fifo;
*   (2)!in_fifo_rd_empty && !out_fifo_wr_full,  wr_en->in_fifo->out_fifo;
*   (3)!in_fifo_rd_empty &&  out_fifo_wr_full,  wr_en->in_fifo->ram_fifo->out_fifo;
*  -water_level means (in_fifo_depth + out_fifo_depth + ram_fifo_depth);
*  -the ram's wr/rd clock domain is the same;
*--------------
*  -advantage: the RAM_DEPTH can be any value;
*  -disadvantage: when wr_clk slower than rd_clk, the performance may not be ok;
*
*  Modify:
*  -
*
******************************************************************************/

//`include "com_async_fifo_reg.v"

`ifndef com_async_fifo_ram_2p1ck_v
`define com_async_fifo_ram_2p1ck_v
module com_async_fifo_ram_2p1ck #( parameter
    DW        = 8,
    RAM_DEPTH = 4, //ram_depth
    IN_DEPTH  = 0,
    OUT_DEPTH = 8,
    TOL_DEPTH = RAM_DEPTH+IN_DEPTH+OUT_DEPTH,
    TOL_AW    = $clog2(TOL_DEPTH+1),
    RAM_AW    = $clog2(RAM_DEPTH+1)//,
)
(
input  wire                     wr_clk              ,
input  wire                     wr_rst_n            ,
input  wire                     wr_clear            ,
input  wire                     rd_clk              ,
input  wire                     rd_rst_n            ,
input  wire                     rd_clear            ,

input  wire                     wr_en               ,
input  wire [DW    -1:0]        wr_data             ,
output wire                     wr_full             ,
input  wire                     rd_en               ,
output wire [DW    -1:0]        rd_data             ,
output wire                     rd_empty            ,
output wire [TOL_AW-1:0]        water_level         ,

output wire                     ram_wr_en           ,
output wire [RAM_AW-1:0]        ram_wr_addr         ,
output wire [DW    -1:0]        ram_wr_data         ,
output wire                     ram_rd_en           ,
output wire [RAM_AW-1:0]        ram_rd_addr         ,
input  wire [DW    -1:0]        ram_rd_data         //,
);
//localparam-----------------------------------------------------------------
localparam IN_AW  = $clog2(IN_DEPTH +1);
localparam OUT_AW = $clog2(OUT_DEPTH+1);
//reg  declare---------------------------------------------------------------
reg  [RAM_AW-0:0] rc_wrcnt;
reg  [RAM_AW-0:0] rc_rdcnt;
//wire declare---------------------------------------------------------------
wire in_wr_full;
wire in_rd_empty;
wire out_wr_full;
wire out_rd_empty;

wire ram_wr_full  ;
wire ram_rd_empty ;
wire ram_rd_ack   ;
wire ram_rd_empty_do = ram_rd_empty && !ram_rd_ack;
//statement------------------------------------------------------------------

//in fifo---
wire              in_wr_en      ;
wire [DW-1:0]     in_wr_data    ;
wire              in_rd_en      ;
wire [DW-1:0]     in_rd_data    ;
wire [IN_AW-1:0]  in_water_level;
generate
if( IN_DEPTH>0 )begin:gen_in_fifo_y
    assign in_wr_en      = (!in_rd_empty || !ram_rd_empty_do || out_wr_full) ? wr_en   : 1'b0;
    assign in_wr_data    = wr_data;
    assign in_rd_en      = !in_rd_empty && ((!ram_rd_empty_do||out_wr_full) ? !ram_wr_full : !out_wr_full);
    com_sync_fifo_reg #(
        .DATA_W     ( DW         ), //8
        .DEPTH      ( IN_DEPTH   )  //4
    )r_com_sync_fifo_reg_in
    (
        .clk                  ( wr_clk               ), //i
        .rst_n                ( wr_rst_n             ), //i
        .clear                ( wr_clear             ), //i

        .wr_en                ( in_wr_en             ), //i
        .wr_data              ( in_wr_data           ), //i
        .wr_full              ( in_wr_full           ), //o
        .rd_en                ( in_rd_en             ), //i
        .rd_data              ( in_rd_data           ), //o
        .rd_empty             ( in_rd_empty          ), //o
        .water_level          ( in_water_level       )  //o
    );
end:gen_in_fifo_y
else begin:gen_in_fifo_n
    assign in_wr_en    = 1'b0;
    assign in_wr_data  = 'b0;
    assign in_wr_full  = ram_wr_full;
    assign in_rd_en    = wr_en  ;
    assign in_rd_data  = wr_data;
    assign in_rd_empty =!wr_en;
    assign in_water_level = 'b0;
end:gen_in_fifo_n
endgenerate

//out fifo---
wire              out_wr_en_tmp= !ram_rd_empty_do ? ram_rd_ack  : !in_rd_empty ? in_rd_en   : wr_en;
wire              out_wr_en    = out_wr_en_tmp && !out_wr_full;
wire [DW    -1:0] out_wr_data  = !ram_rd_empty_do ? ram_rd_data : !in_rd_empty ? in_rd_data : wr_data;
wire              out_rd_en    = rd_en;
wire [DW    -1:0] out_rd_data  ;
wire [OUT_AW-1:0] out_water_level;
com_async_fifo_reg #(
    .DW         ( DW        ), //8
    .DEPTH      ( OUT_DEPTH )  //4
)r_com_async_fifo_reg_out
(
    .wr_clk               ( wr_clk               ), //i
    .wr_rst_n             ( wr_rst_n             ), //i
    .wr_clear             ( wr_clear             ), //i
    .rd_clk               ( rd_clk               ), //i
    .rd_rst_n             ( rd_rst_n             ), //i
    .rd_clear             ( rd_clear             ), //i

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
assign wr_full = in_wr_full;

//ram fifo---
generate
if( RAM_DEPTH>0 )begin:GEN_RAM_FIFO

    wire [RAM_AW-1:0] ram_water_level_t;
    com_sync_fifo_ctrl #(
        .DEPTH      ( RAM_DEPTH )  //4
    )u_com_sync_fifo_ctrl_ram
    (
        .clk                  ( wr_clk               ), //i
        .rst_n                ( wr_rst_n             ), //i
        .clear                ( wr_clear             ), //i

        .wr_en                ( ram_wr_en            ), //i
        .wr_addr              ( ram_wr_addr          ), //o
        .wr_full              ( ram_wr_full          ), //o
        .rd_en                ( ram_rd_en            ), //i
        .rd_addr              ( ram_rd_addr          ), //o
        .rd_empty             ( ram_rd_empty         ), //o
        .water_level          ( ram_water_level_t    )  //o
    );
    wire [RAM_AW-1:0] ram_water_level = ram_water_level_t - ram_rd_ack;

    //ram signal
    reg  rc_ram_rd_ack;
    always @(posedge wr_clk or negedge wr_rst_n)
    begin
        if( !wr_rst_n ) begin
            rc_ram_rd_ack <= 1'b0;
        end
        else begin
            rc_ram_rd_ack <= ram_rd_en;
        end
    end
    assign ram_rd_ack = rc_ram_rd_ack;

    wire [OUT_AW-0:0] out_buf_needed = out_wr_en + (OUT_AW+1)'(0);
    wire   ram_wr_en_t = !ram_rd_empty_do || out_wr_full ? !in_rd_empty : 1'b0;
    assign ram_wr_en   = ram_wr_en_t && !ram_wr_full;
    assign ram_wr_data = in_rd_data;
    assign ram_rd_en   = !ram_rd_empty && out_water_level>out_buf_needed;
    assign water_level = in_water_level + out_water_level + ram_water_level;
end//end of if(RAM_DEPTH)
else begin:GEN_NO_RAM_FIFO
    assign ram_wr_full  = 1'b0;
    assign ram_rd_empty = 1'b1;
    assign ram_rd_ack   = 1'b0;

    assign ram_wr_en   = 1'b0;
    assign ram_wr_addr = RAM_AW'(0);
    assign ram_wr_data = DW'(0);
    assign ram_rd_en   = 1'b0;
    assign ram_rd_addr = RAM_AW'(0);
    assign water_level = in_water_level + out_water_level;
end//end of else(RAM_DEPTH)
endgenerate

endmodule //end of com_async_fifo_ram_2p1ck
`endif //end of com_async_fifo_ram_2p1ck_v

