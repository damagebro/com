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

module com_sync_fifo_ram_1p2bank #( parameter
    RAM_RD_DELAY = 1, // range=[1:8], ram read cmd req->read data ack delay cycles;  normally=1, if ecc_sram=2 maybe;
    DW        = 8,
    RAM_DEPTH = 4, //fifo_ram depth    , range=[0::2]
    OUT_DEPTH = 3, //out fifo_reg depth, range=[2+RAM_RD_DELAY::]
    //localparam in param_list feature support after verilog2009, need verdi "-2009" option; to prevant localparam ambiguous in eda software, still use parameter bellow:
    parameter RAM_ONE_DEPTH = RAM_DEPTH/2,
    parameter TOL_DEPTH     = RAM_DEPTH+OUT_DEPTH,
    parameter TOL_CW        = $clog2(TOL_DEPTH+1),
    parameter RAM_ONE_AW    = $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2)//,
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
output wire [TOL_CW-1:0]          water_level       ,

output wire [1:0]                 ram_cen           ,
output wire [1:0]                 ram_we            ,
output wire [1:0][RAM_ONE_AW-1:0] ram_addr          ,
output wire [1:0][DW-1:0]         ram_din           ,
input  wire [1:0][DW-1:0]         ram_qout          //,
);
//localparam-----------------------------------------------------------------
localparam RAM_AW = $clog2(RAM_DEPTH);
localparam RAM_CW = $clog2(RAM_DEPTH+1);
localparam OUT_CW = $clog2(OUT_DEPTH+1);
localparam RAM_RD_DELAY_L2 = $clog2(RAM_RD_DELAY+1);

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
wire ram_rd_empty_do;
wire [DW-1:0] ram_rd_data;
//statement------------------------------------------------------------------

//out fifo---
wire              out_wr_en_tmp= !ram_rd_empty_do ? ram_rd_ack  : wr_en;
wire              out_wr_en    = out_wr_en_tmp && !out_wr_full;
wire [DW-1:0]     out_wr_data  = !ram_rd_empty_do ? ram_rd_data : wr_data;
wire              out_rd_en    = rd_en;
wire [DW-1:0]     out_rd_data  ;
wire [OUT_CW-1:0] out_water_level;
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

//ram fifo---
generate
if( RAM_DEPTH>0 )begin:gen_ram_fifo
    reg  [RAM_RD_DELAY_L2-1:0] r_otf_cnt;  //read ram cmd otf cnt, rd_en+1, rd_ack-1;
//the same as com_sync_fifo_reg begin---------------------
    localparam AW = RAM_AW;
    localparam DEPTH = RAM_DEPTH;
    localparam CW = $clog2(DEPTH+1);
    reg  [AW-0:0] r_wrcnt;
    reg  [AW-0:0] r_rdcnt;
    reg           r_wr_full;
    reg           r_rd_empty;
    reg  [CW-1:0] r_water_level;
    //wrcnt
    wire [AW-0:0] wrcnt_p1  = r_wrcnt[AW-1:0] + 1'b1;
    wire [AW-0:0] wrcnt_nxt = wrcnt_p1==DEPTH[AW-0:0] ? { !r_wrcnt[AW],{AW{1'b0}} } : {r_wrcnt[AW],wrcnt_p1[AW-1:0]};
    wire [AW-0:0] wrcnt_tmp = wr_en ? wrcnt_nxt : r_wrcnt;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            r_wrcnt <= '0;
        else if( clear )
            r_wrcnt <= '0;
        else if( wr_en && !r_wr_full )
            r_wrcnt <= wrcnt_nxt;
    end
    //rdcnt
    wire [AW-0:0] rdcnt_p1  = r_rdcnt[AW-1:0] + 1'b1;
    wire [AW-0:0] rdcnt_nxt = rdcnt_p1==DEPTH[AW-0:0] ? { !r_rdcnt[AW],{AW{1'b0}} } : {r_rdcnt[AW],rdcnt_p1[AW-1:0]};
    wire [AW-0:0] rdcnt_tmp = rd_en ? rdcnt_nxt : r_rdcnt;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            r_rdcnt <= '0;
        else if( clear )
            r_rdcnt <= '0;
        else if( rd_en && !r_rd_empty )
            r_rdcnt <= rdcnt_nxt;
    end
    //full&empty
    wire tmp_full = (wrcnt_tmp[AW-1:0]==rdcnt_tmp[AW-1:0]) && (wrcnt_tmp[AW]==!rdcnt_tmp[AW]);
    wire tmp_empty= (wrcnt_tmp[AW-0:0]==rdcnt_tmp[AW-0:0]);
    wire [AW-0:0] depth_max = DEPTH[AW:0];
    wire [AW-0:0] equ_wl = depth_max + {1'b0,rdcnt_tmp[AW-1:0]} - {1'b0,wrcnt_tmp[AW-1:0]};
    wire [AW-0:0] neq_wl = {1'b0,rdcnt_tmp[AW-1:0]} - {1'b0,wrcnt_tmp[AW-1:0]};
    wire [AW-0:0] tmp_wl = (wrcnt_tmp[AW]==rdcnt_tmp[AW]) ? equ_wl : neq_wl;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )begin
            r_wr_full <= 1'b0;
            r_rd_empty<= 1'b1;
            r_water_level <= DEPTH[CW-1:0];
        end
        else if( clear )begin
            r_wr_full <= 1'b0;
            r_rd_empty<= 1'b1;
            r_water_level <= DEPTH[CW-1:0];
        end
        else if( rd_en || wr_en )begin
            r_wr_full <= tmp_full;
            r_rd_empty<= tmp_empty;
            r_water_level <= CW'(tmp_wl);
        end
    end
//the same as com_sync_fifo_reg end  ---------------------
    assign ram_wr_full   = r_wr_full;
    assign ram_rd_empty  = r_rd_empty;
    assign wr_full = ram_wr_full;
    wire [RAM_AW-1:0] ram_wr_addr = r_wrcnt[AW-1:0];
    wire [RAM_AW-1:0] ram_rd_addr = r_rdcnt[AW-1:0];
    wire [RAM_CW-1:0] ram_water_level_t = r_water_level;
    wire [RAM_CW-1:0] ram_water_level = {ram_water_level_t} - r_otf_cnt;

    //in buf---
    //deal 2sram conflic bellow
    // >>>
    // T1: write ping(d0);
    // T2: write pong(d1);
    // T3: write ping(d2), read ping(d0);  write/read conflict, d2->ibuf
    // T4: write pong(d3); //if read pong(d1), refer condition(1)
    // T5: write ping(d4); //if read pong(d1), refer condition(3)
    // //when T3 conflict, T4~T5 have four condition bellow:
    // (1) T4 write yes read yes, write pong(d3)->ibuf, read pong(d1), ibuf(d2)->ping;
    // (2) T4 write no  read no , ibuf(d2)->ping;
    // (3) T4 write yes read no , write pong(d3), ibuf(d2)->ping
    // (4) T4 write no  read yes, read  pong(d1), ibuf(d2)->ping
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
    wire rd_banksel_flag = ram_rd_en && ram_rd_addr[0];
    reg  [RAM_RD_DELAY-1:0] rc_ram_rd_ack;
    reg  [RAM_RD_DELAY-1:0] rc_rd_banksel_flag;
    assign ram_rd_ack = rc_ram_rd_ack[RAM_RD_DELAY-1];
    assign ram_rd_empty_do = ram_rd_empty && !(|r_otf_cnt);
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n ) begin
            rc_ram_rd_ack      <= '0;
            rc_rd_banksel_flag <= '0;
        end
        else if( clear )begin
            rc_ram_rd_ack      <= '0;
            rc_rd_banksel_flag <= '0;
        end
        else begin
            rc_ram_rd_ack     [0] <= ram_rd_en;
            rc_rd_banksel_flag[0] <= rd_banksel_flag;
            for( int i=1; i<RAM_RD_DELAY; i++ )begin
                rc_ram_rd_ack     [i] <= rc_ram_rd_ack     [i-1];
                rc_rd_banksel_flag[i] <= rc_rd_banksel_flag[i-1];
            end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            r_otf_cnt <= '0;
        else if( clear )
            r_otf_cnt <= '0;
        else if( ram_rd_en || ram_rd_ack )
            r_otf_cnt <= r_otf_cnt + ram_rd_en - ram_rd_ack;
    end

    wire [OUT_CW-0:0] out_buf_needed = out_wr_en + (OUT_CW+1)'(0);
    wire   ram_wr_en_t = !ram_rd_empty_do || out_wr_full ? wr_en : 1'b0;
    wire   ram_rd_en_t = !ram_rd_empty && {1'b0,out_water_level}>out_buf_needed;
    assign ram_wr_en = ram_wr_en_t;
    assign ram_rd_en = ram_rd_en_t;
    assign water_level = out_water_level + TOL_CW'(ram_water_level);

    wire ram_wr_en_do = ram_wr_en && !ram_conflict;
    assign ram_cen [0] = !( (ram_wr_en_do && ram_wr_addr[0]==1'b0) || (ram_rd_en && ram_rd_addr[0]==1'b0) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b0) );
    assign ram_we  [0] = (ram_wr_en_do && ram_wr_addr[0]==1'b0) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b0);
    assign ram_addr[0] = (ram_wr_en_do && ram_wr_addr[0]==1'b0) ? ram_wr_addr[RAM_AW-1:1] : (rc_ibuf_busy && ram_conflict_addr[0]==1'b0) ? ram_conflict_addr[RAM_AW-1:1] : ram_rd_addr[RAM_AW-1:1];
    assign ram_din [0] = (rc_ibuf_busy && ram_conflict_addr[0]==1'b0) ? rc_ibuf : wr_data;
    assign ram_cen [1] = !( (ram_wr_en_do && ram_wr_addr[0]==1'b1) || (ram_rd_en && ram_rd_addr[0]==1'b1) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b1) );
    assign ram_we  [1] = (ram_wr_en_do && ram_wr_addr[0]==1'b1) || (rc_ibuf_busy && ram_conflict_addr[0]==1'b1);
    assign ram_addr[1] = (ram_wr_en_do && ram_wr_addr[0]==1'b1) ? ram_wr_addr[RAM_AW-1:1] : (rc_ibuf_busy && ram_conflict_addr[0]==1'b1) ? ram_conflict_addr[RAM_AW-1:1] : ram_rd_addr[RAM_AW-1:1];
    assign ram_din [1] = (rc_ibuf_busy && ram_conflict_addr[0]==1'b1) ? rc_ibuf : wr_data;
    assign ram_rd_data = !rc_rd_banksel_flag[RAM_RD_DELAY-1] ? ram_qout[0] : ram_qout[1];
end//end of if(RAM_DEPTH)
else begin:gen_no_ram_fifo
    assign ram_wr_full  = 1'b0;
    assign ram_rd_empty = 1'b1;
    assign ram_rd_ack   = 1'b0;
    assign ram_rd_empty_do = ram_rd_empty;

    assign ram_wr_en   = 1'b0;
    assign ram_rd_en   = 1'b0;
    assign water_level = TOL_CW'(out_water_level);
    assign wr_full = out_wr_full;

    assign ram_cen     = '0;
    assign ram_we      = '0;
    assign ram_addr    = '0;
    assign ram_din     = '0;
    assign ram_rd_data = '0;
end//end of else(RAM_DEPTH)
endgenerate

endmodule //end of com_sync_fifo_ram_1p2bank


