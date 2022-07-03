/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2019/11/08-09:51:03
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include "com_arbiter_lite.v"
//`include "com_pipe_ctrl.v"
//`include "com_sync_fifo_reg.v"

`ifndef com_spram_mate_v
`define com_spram_mate_v
module com_spram_mate #( parameter
    DEPTH = 16,
    DW    = 8,
    WSTB  = 1, //strobe
    WCH   = 3, //number of write channel
    RCH   = 2, //number of read  channel
    WREG  = 0, //number of register pipeline to   ram;
    RREG  = 0, //number of register pipeline from ram;  2020/03/18, not surport now; fixed=0
    WRPRI = 1, //1:write/read priority,  0:read, 1:write
    CASACADE = 0, //0: connect to ram, 1: connect to next ram_mate;
    AW    = $clog2(DEPTH>2?DEPTH:2)
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [WCH-1:0][WSTB-1:0] arr_wr_vld             ,
output wire [WCH-1:0]           arr_wr_rdy             ,
input  wire [WCH-1:0][AW-1:0]   arr_wr_addr            ,
input  wire [WCH-1:0][DW-1:0]   arr_wr_data            ,
input  wire [RCH-1:0]           arr_rd_vld             ,
output wire [RCH-1:0]           arr_rd_rdy             ,
input  wire [RCH-1:0][AW-1:0]   arr_rd_addr            ,
output wire [RCH-1:0]           arr_rd_ack             ,
output wire [RCH-1:0][DW-1:0]   arr_rd_data            ,

output wire                     cen                 ,
output wire [WSTB-1:0]          we                  ,
output wire [AW-1:0]            addr                ,
output wire [DW-1:0]            din                 ,
input  wire [DW-1:0]            qout                ,
input  wire                     rd_ack              ,     //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
input  wire                     rd_rdy              ,     //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
input  wire                     wr_rdy              //,   //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
);
//localparam-----------------------------------------------------------------
localparam PRI_MODE= "round_hold_small"; //small_first, large_first, round_from_small, round_from_large, round_hold_small, round_hold_large
localparam WCH_AW= $clog2(WCH>2?WCH:2); //spyglass disable W362
localparam RCH_AW= $clog2(RCH>2?RCH:2); //spyglass disable W362
integer i;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire binwr_busy;
wire binrd_busy;
wire bcon_busy;
wire bwrgnt_flag;
wire brdgnt_flag;
wire mem_busy;
wire wr_busy;
wire rd_busy;
//statement------------------------------------------------------------------
reg  [WCH-1:0] abrb_wrvld;//array,bool,register_block
reg  [RCH-1:0] abrb_rdvld;
always @*
begin
    for( i=0; i<WCH; i=i+1 )
        abrb_wrvld[i] = |arr_wr_vld[i];
end
always @*
begin
    for( i=0; i<RCH; i=i+1 )
        abrb_rdvld[i] = |arr_rd_vld[i];
end

//arbiter, wrch/ rdch
wire [WCH_AW-1:0] pwrch_id;
wire [RCH_AW-1:0] prdch_id;
com_arbiter_lite #(.MODE( PRI_MODE ), .PORT_N( WCH )) r_com_arbiter_lite_wrch( .clk(clk),.rst_n(rst_n),.clear(clear),.requests( abrb_wrvld ),.grant_id( pwrch_id ) );
com_arbiter_lite #(.MODE( PRI_MODE ), .PORT_N( RCH )) r_com_arbiter_lite_rdch( .clk(clk),.rst_n(rst_n),.clear(clear),.requests( abrb_rdvld ),.grant_id( prdch_id ) );

//arbiter, wr/rd
wire bwrsel_flag;
assign binwr_busy = |abrb_wrvld;
assign binrd_busy = |abrb_rdvld;
generate
if( WRPRI )begin:gen_WR_PRIORITY
    assign bwrsel_flag = binwr_busy;
    assign bwrgnt_flag = !bcon_busy;
    assign brdgnt_flag = !binwr_busy && !bcon_busy;
end
else begin:gen_RD_PRIORITY
    assign bwrsel_flag = binwr_busy && !binrd_busy;
    assign bwrgnt_flag = !binrd_busy && !bcon_busy;
    assign brdgnt_flag = !bcon_busy;
end
endgenerate

wire            s0_cen = !(binwr_busy||binrd_busy);
wire [WSTB-1:0] s0_we  = bwrsel_flag ? arr_wr_vld[pwrch_id] : {WSTB{1'b0}};
wire [AW-1:0]   s0_adr  = bwrsel_flag ? arr_wr_addr[pwrch_id] : arr_rd_addr[prdch_id];
wire [DW-1:0]   s0_dat  = arr_wr_data[pwrch_id];
//ack
wire rdack_s;
wire rdack_e;
wire [RCH_AW-1:0] rdch_id_s;
reg  [RCH-1:0] abrb_rdack;
always @*
begin
    for( i=0; i<RCH; i=i+1 )begin
        abrb_rdack[i] = i[RCH_AW-1:0]==rdch_id_s ? rdack_e : 1'b0; //spyglass disable W216
    end
end
assign arr_rd_ack  = abrb_rdack;

wire              ack_wr_en    = !s0_cen && !(|s0_we);
wire [RCH_AW-1:0] ack_wr_data  = prdch_id;
wire              ack_wr_full  ;
wire              ack_rd_en    = rdack_e;
wire [RCH_AW-1:0] ack_rd_data  ;
wire              ack_rd_empty ;

com_sync_fifo_reg #(
    .DW         ( RCH_AW      ), //8
    .DEPTH      ( WREG+RREG+2 )  //4
)r_com_sync_fifo_reg_ack
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( ack_wr_en            ), //i
    .wr_data              ( ack_wr_data          ), //i
    .wr_full              ( ack_wr_full          ), //o
    .rd_en                ( ack_rd_en            ), //i
    .rd_data              ( ack_rd_data          ), //o
    .rd_empty             ( ack_rd_empty         ), //o
    .water_level          (                      )  //spyglass disable PartConnPort-ML,W287b //o
);
assign rdch_id_s = ack_rd_data;

generate
if(CASACADE==0) begin:gen_CON_MEM
    reg  rc_rdack;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n ) begin
            rc_rdack <= 1'b0;
        end
        else if( clear ) begin
            rc_rdack <= 1'b0;
        end
        else if( !cen && !we ) begin
            rc_rdack <= 1'b1;
        end
        else begin
            rc_rdack <= 1'b0;
        end
    end
    assign rdack_s = rc_rdack;
    assign rd_busy = 1'b0;
    assign wr_busy = 1'b0;
end
else begin:gen_CON_NEXT
    assign rdack_s = rd_ack;
    assign rd_busy = !rd_rdy;
    assign wr_busy = !wr_rdy;
end
endgenerate

//register
assign mem_busy = we ? wr_busy : rd_busy;
generate
if(WREG==0) begin:gen_NO_REG
    assign cen = s0_cen;
    assign we  = s0_we ;
    assign addr= s0_adr;
    assign din = s0_dat;
    assign bcon_busy = mem_busy || ack_wr_full;
end//end of gen_NO_REG
else begin:gen_REG
    wire            pmem_ivld     = !s0_cen;
    wire            pmem_irdy     ;
    wire            pmem_ovld     ;
    wire            pmem_ordy     = !(mem_busy || ack_wr_full);
    wire [WREG-1:0] pmem_in_upen  ;
    com_pipe_ctrl #( .NUM_PIPE(WREG) ) r_com_pipe_ctrl_mem( clk, rst_n, clear, pmem_ivld, pmem_irdy, pmem_ovld, pmem_ordy, pmem_in_upen );
    assign bcon_busy  = !pmem_irdy;

    reg  [WREG-1:0][WSTB-1:0]   arc_wen;
    reg  [WREG-1:0][AW-1:0]     arc_adr;
    reg  [WREG-1:0][DW-1:0]     arc_dat;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n ) begin
            arc_wen <= 'b0;
            arc_adr <= 'b0;
        end
        else begin
            if( pmem_in_upen[0] )begin
                arc_wen[0] <= s0_we ;
                arc_adr[0] <= s0_adr;
            end
            for( i=1; i<WREG; i=i+1 )
                if( pmem_in_upen[i] )begin
                    arc_wen[i] <= arc_wen[i-1];
                    arc_adr[i] <= arc_adr[i-1];
                end
        end
    end
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n ) begin
            arc_dat <= 'b0;
        end
        else begin
            if( pmem_in_upen[0] && (|s0_we) )begin
                arc_dat[0] <= s0_dat;
            end
            for( i=1; i<WREG; i=i+1 )begin
                if( pmem_in_upen[i]  && (|arc_wen[i-1]) )begin
                    arc_dat[i] <= arc_dat[i-1];
                end
            end//end of for
        end//end of else
    end
    assign cen = !pmem_ovld;
    assign we  = arc_wen[WREG-1];
    assign addr= arc_adr[WREG-1];
    assign din = arc_dat[WREG-1];
end//end of gen_REG

endgenerate

generate
if(RREG==0) begin:gen_rd_NO_REG
    assign arr_rd_data = {RCH{qout}};
    assign rdack_e = rdack_s;
end:gen_rd_NO_REG//end of gen_NO_REG
else begin:gen_rd_REG
    reg  [RREG-1:0] arc_ack;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            arc_ack <= 'b0;
        else begin
            arc_ack[0] <= rdack_s;
            for( int i=1; i<RREG; i++ )begin
                arc_ack[i] <= arc_ack[i-1];
            end
        end
    end
    assign rdack_e = arc_ack[RREG-1];

    reg  [RREG-1:0][DW-1:0] arc_rd_data;
    always @(posedge clk or negedge rst_n)
    begin
        if( !rst_n )
            arc_rd_data <= 'b0;
        else begin
            if( rdack_s )
                arc_rd_data[0] <= qout;
            for( int i=1; i<RREG; i++ )begin
                if( arc_ack[i-1] )
                    arc_rd_data[i] <= arc_rd_data[i-1];
            end
        end
    end
    assign arr_rd_data = {RCH{arc_rd_data[RREG-1]}};
end:gen_rd_REG
endgenerate

//busy
wire [WCH-1:0] arr_wr_gnt = binwr_busy ? (1<<pwrch_id) : {WCH{1'b1}};
wire [RCH-1:0] arr_rd_gnt = binrd_busy ? (1<<prdch_id) : {RCH{1'b1}};
assign arr_wr_rdy = ((arr_wr_gnt) & {WCH{bwrgnt_flag}});
assign arr_rd_rdy = ((arr_rd_gnt) & {RCH{brdgnt_flag}});

//assert

endmodule //end of com_spram_mate
`endif //end of com_spram_mate_v
