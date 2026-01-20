//-------------------------------------------------------------------
//content
//-------------------------------------------------------------------
// 1. instance prefix
// 2. frequently statement
// 3. function
// 4. instance module quickreference

//#instance-------------------------------------------------------------------
//u_inst: user   module
//r_inst: common module
//t_inst: third's IP module

//-------------------------------------------------------------------
//frequently statement
//-------------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_n <= 'b0;
    else if( cond )
        rc_n <= n;
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_n <= 'b0;
    end
    else if( cond )begin
        rc_n <= n;
    end
end
always @*
begin
    for( int i=0; i<4; i++ )begin
        a[i] = b[i];
    end
end

//assert-----------------------------
// `define STL_PARAM_ASSERT( cond, estr )
// `define STL_SIGNAL_ASSERT( str_property, clk,rst_n, key,cond,estr )
// `define STL_SIGNAL_ASSERT_LITE( str_property, key,cond,estr )
-example:
>>>
`COM_PARAM_ASSERT( DEPTH>0, "fifo depth must larger than 0" );
`COM_SIGNAL_ASSERT( a0, clk,rst_n,wr_en,!wr_full , "fifo write when full"  );
`COM_SIGNAL_ASSERT_LITE( a1, rd_en,!rd_empty, "fifo read when empty"  );
>>>

//interface-----------------------------
//global signal
//csr
//bus
//isp stream
//ram

//global signal---
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
`COM_SYS_IF                     sys_cfg             ,
//csr interface---
input  wire                     csr_write           ,
input  wire [CSR_AW-1:0]        csr_addr            ,
input  wire [CSR_DW-1:0]        csr_wdata           ,
input  wire [CSR_DW/8-1:0]      csr_wstrb           ,
input  wire                     csr_valid           ,
output wire                     csr_ready           ,
output wire [CSR_DW-1:0]        csr_rdata           //,
UniCSRIf #(.AW(CSR_AW), .DW(CSR_DW)) csr_ifm();
assign csr_write = csr_ifm.bCSRWrite;
assign csr_addr  = csr_ifm.CSRAddr  ;
assign csr_wdata = csr_ifm.CSRWrData;
assign csr_wstrb = csr_ifm.CSRWrStrb;
assign csr_valid = csr_ifm.CSRValid ;
assign csr_ifm.CSRReady  = csr_ready ;
assign csr_ifm.CSRRdData = csr_rddata;

UniCSRIf #(.AW(CSR_AW), .DW(CSR_DW)) csr_ifs();
assign csr_ifs.bCSRWrite = csr_write;
assign csr_ifs.CSRAddr   = csr_addr ;
assign csr_ifs.CSRWrData = csr_wdata;
assign csr_ifs.CSRWrStrb = csr_wstrb;
assign csr_ifs.CSRValid  = csr_valid;
assign csr_ready = csr_ifs.CSRReady ;
assign csr_rdata = csr_ifs.CSRRdData;

input  wire [AW-1:0]            ebus_wa_addr         ,
input  wire [LW-1:0]            ebus_wa_bytelen      ,
input  wire                     ebus_wa_valid        ,
output wire                     ebus_wa_ready        ,
input  wire [DW-1:0]            ebus_wd_data         ,
input  wire                     ebus_wd_valid        ,
output wire                     ebus_wd_ready        ,
output wire                     ebus_wb_resp         ,

//bus wr interface---
output wire [EMI_AW-1:0]        bus_wa_addr         ,
output wire [EMI_LW-1:0]        bus_wa_bytelen      ,
output wire                     bus_wa_valid        ,
input  wire                     bus_wa_ready        ,
output wire [EMI_DW-1:0]        bus_wd_data         ,
output wire                     bus_wd_valid        ,
input  wire                     bus_wd_ready        ,
input  wire                     bus_wb_resp         ,

//bus rd interface---
output wire [EMI_AW-1:0]        bus_ra_addr         ,
output wire [EMI_LW-1:0]        bus_ra_bytelen      ,
output wire                     bus_ra_valid        ,
input  wire                     bus_ra_ready        ,
input  wire [EMI_DW-1:0]        bus_rd_data         ,
input  wire                     bus_rd_valid        ,
output wire                     bus_rd_ready        ,
+
input  wire                     bus_rd_done         ,

//isp stream interface---
input  wire                     pixel_sof           ,
input  wire                     pixel_last          ,
input  wire [PW-1:0]            pixel_data          ,
input  wire                     pixel_valid         ,
output wire                     pixel_ready         ,
+
input  wire                     pixel_eof           ,
//-----
output wire                     pixel_sof           ,
output wire                     pixel_last          ,
output wire [PW-1:0]            pixel_data          ,
output wire                     pixel_valid         ,
input  wire                     pixel_ready         ,

//ram access interface---
output wire [RAM_AW-1:0]        ram_wr_addr         ,
output wire [RAM_DW-1:0]        ram_wr_data         ,
output wire [RAM_STRB-1:0]      ram_wr_vld          ,
input  wire                     ram_wr_rdy          ,

output wire [RAM_AW-1:0]        ram_rd_addr         ,
output wire                     ram_rd_vld          ,
input  wire                     ram_rd_rdy          ,
input  wire [RAM_DW-1:0]        ram_rd_data         ,
input  wire                     ram_rd_ack          ,

//#function-------------------------------------------------------------------
function <返回值的类型或范围> <函数名>
<端口说明语句>
<变量类型说明>

begin
<语句>
end
endfunction


//%ex.----
wire [PW-0:0] val1 = PW'(4);
wire [4:0] val1_l2 = F_clog2(val1);

localparam PW = 14;
function [4:0] F_clog2;
input [PW-0:0] v;

reg  [4:0] b;
begin
    for( int i=0; i<PW+1; i++ )begin
        if( (1<<i)<=v )
            b = i[4:0];
    end
    F_clog2 = b;
end
endfunction

//-------------------------------------------------------------------
//instance module quickreference
//-------------------------------------------------------------------
/*
com_reg_e
com_counter
com_arbiter_lite
com_pipe_ctrl
com_dp_buffer + com_dp_ram
com_sync_fifo_reg
com_sync_fifo_ram_1p2bank
com_async_fifo_reg
com_async_fifo_ram_2p2ck
com_spram_mate
com_spram_cell
com_mimo + com_simo_no_delay
*/

//-------------------------------------------------------------------
//com_reg_e
//-------------------------------------------------------------------
localparam DW   = 8;
localparam INIT = 0;
wire e; //enable
wire [DW-1:0] d;
wire [DW-1:0] q;

com_reg_e #( .DW(DW) ) zr_com_reg_e_x( clk,rst_n, e,d,q );
com_reg_e #( .DW(DW) ) zr_com_reg_e_x( clk,rst_n, e,{d3,d2,d1},{q3,q2,q1} );
com_reg_e #( .DW(DW) ) zr_com_reg_e_x( clk,rst_n, e,{d3,d2,d1},
                                                    {q3,q2,q1} );
com_reg_e #( .DW(DW), .INIT(INIT)) zr_com_reg_e_x( clk,rst_n, e,d,q );

com_reg_ce #( .DW(DW) ) zr_com_reg_ce_x( clk,rst_n,clear, e,d,q );
com_reg #( .DW(DW) ) zr_com_reg_x( clk,rst_n, d,q );

//-------------------------------------------------------------------
//com_counter
//-------------------------------------------------------------------
localparam DW   = 8;
localparam STEP = 1;
localparam INIT = 0;
wire [DW-1:0] x_cnt_max  ;
wire          x_cnt_start;
wire          x_cnt_done ;
wire          x_cnten    ;
wire [DW-1:0] x_cnt      ;
com_counter #( .DW(DW) ) zr_com_counter_x( clk,rst_n,clear||x_cnt_start, x_cnt_max,x_cnten,x_cnt,x_cnt_done );
com_counter #( .DW(DW), .INIT(INIT), .STEP(STEP) ) zr_com_counter_x( clk,rst_n,clear||x_cnt_start, x_cnt_max,x_cnten,x_cnt,x_cnt_done );

//-------------------------------------------------------------------
//com_arbiter_lite
//-------------------------------------------------------------------
localparam MODE= "round_from_small"; //small_first, large_first, round_from_small, round_from_large, round_hold_small, round_hold_large
localparam CH_N  = 2;
localparam CH_DW = $clog2(CH_N<2?2:CH_N);
wire [CH_N -1:0] requests;
wire [CH_DW-1:0] grant_id;
com_arbiter_lite #(.MODE( MODE ), .PORT_N( CH_N )) zr_com_arbiter_lite_x( .clk(clk),.rst_n(rst_n),.clear(clear),.requests( requests ),.grant_id( grant_id ) );

//-------------------------------------------------------------------
//com_pipe_ctrl
//-------------------------------------------------------------------
localparam PIPN_N = 2;
wire              x_ivld     ;
wire              x_irdy     ;
wire              x_ovld     ;
wire              x_ordy     ;
wire [PIPN_N-1:0] x_in_upen  ;
com_pipe_ctrl #( .NUM_PIPE(PIPN_N) ) zr_com_pipe_ctrl_x( clk, rst_n, clear, x_ivld, x_irdy, x_ovld, x_ordy, x_in_upen );

//-------------------------------------------------------------------
//com_dp_buffer + com_dp_ram
//-------------------------------------------------------------------
localparam DW    = 8;
localparam DEPTH = 4;
wire          x_ivld  ;
wire          x_irdy  ;
wire [DW-1:0] x_idata ;
wire          x_ovld  ;
wire          x_ordy  ;
wire [DW-1:0] x_odata ;
com_dp_buffer #(
    .DW         ( DW    ), //8
    .DEPTH      ( DEPTH )  //4
)zr_com_dp_buffer_x
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( x_ivld               ), //i
    .irdy                 ( x_irdy               ), //o
    .idata                ( x_idata              ), //i
    .ovld                 ( x_ovld               ), //o
    .ordy                 ( x_ordy               ), //i
    .odata                ( x_odata              )  //o
);
com_dp_buffer #(.DW(DW), .DEPTH(DEPTH)) zr_com_dp_buffer_x ( .clk(clk),.rst_n(rst_n),.clear(clear),
    .ivld(x_ivld), .irdy(x_irdy), .idata(x_idata), .ovld(x_ovld), .ordy(x_ordy), .odata(x_odata) );

localparam AW    = 8;
localparam DW    = 8;
localparam DEPTH = 4;
wire          x_ivld  ;
wire          x_irdy  ;
wire [AW-1:0] x_iaddr ;
wire          x_ovld  ;
wire          x_ordy  ;
wire [DW-1:0] x_odata ;
wire          x_ram_rd_vld  ;
wire          x_ram_rd_rdy  ;
wire [AW-1:0] x_ram_rd_addr ;
wire          x_ram_rd_ack  ;
wire [DW-1:0] x_ram_rd_data ;

com_dp_ram #(
    .AW         ( AW         ), //8
    .DW         ( DW         ), //8
    .DEPTH      ( DEPTH      )  //2
)zr_com_dp_ram_x
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( x_ivld               ), //i
    .irdy                 ( x_irdy               ), //o
    .iaddr                ( x_iaddr              ), //i
    .ovld                 ( x_ovld               ), //o
    .ordy                 ( x_ordy               ), //i
    .odata                ( x_odata              ), //o
    .ram_rd_vld           ( x_ram_rd_vld         ), //o
    .ram_rd_rdy           ( x_ram_rd_rdy         ), //i
    .ram_rd_addr          ( x_ram_rd_addr        ), //o
    .ram_rd_ack           ( x_ram_rd_ack         ), //i
    .ram_rd_data          ( x_ram_rd_data        )  //i
);

//-------------------------------------------------------------------
//com_sync_fifo_reg
//-------------------------------------------------------------------
localparam DW      = 8;
localparam DEPTH   = 4;
localparam AW = $clog2(DEPTH+1);
wire [AW-1:0] water_level ;
wire               wr_en    ;
wire [DW-1:0]      wr_data  ;
wire               wr_full  ;
wire               rd_en    ;
wire [DW-1:0]      rd_data  ;
wire               rd_empty ;
com_sync_fifo_reg #(
    .DW         ( DW     ), //8
    .DEPTH      ( DEPTH  )  //4
)zr_com_sync_fifo_reg_x
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wr_en                ), //i
    .wr_data              ( wr_data              ), //i
    .wr_full              ( wr_full              ), //o
    .rd_en                ( rd_en                ), //i
    .rd_data              ( rd_data              ), //o
    .rd_empty             ( rd_empty             ), //o
    .water_level          ( water_level          )  //o
);
com_sync_fifo_reg #(.DW(DW), .DEPTH(DEPTH)) zr_com_sync_fifo_reg_x ( .clk(clk),.rst_n(rst_n),.clear(clear),
    .wr_en(wr_en), .wr_data(wr_data), .wr_full(wr_full), .rd_en(rd_en), .rd_data(rd_data), .rd_empty(rd_empty), .water_level() );

//-------------------------------------------------------------------
//com_sync_fifo_ram_1p2bank
//-------------------------------------------------------------------
localparam RAM_DW    = 32;
localparam RAM_DEPTH = 64;
localparam RAM_ONE_DEPTH = RAM_DEPTH/2;
localparam RAM_ONE_AW= $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2);
localparam TOL_AW =$clog2( RAM_DEPTH+3+3 ); //ram_depth+in_depth>=3+out_depth>=3;
wire [TOL_AW-1:0] x_water_level;
wire              x_wr_en    ;
wire [RAM_DW-1:0] x_wr_data  ;
wire              x_wr_full  ;
wire              x_rd_en    ;
wire [RAM_DW-1:0] x_rd_data  ;
wire              x_rd_empty ;

wire [1:0]                 ram_cen  ;
wire [1:0]                 ram_we   ;
wire [1:0][RAM_ONE_AW-1:0] ram_addr ;
wire [1:0][RAM_DW-1:0]     ram_din  ;
wire [1:0][RAM_DW-1:0]     ram_qout ;
com_sync_fifo_ram_1p2bank #(
    .DW         ( RAM_DW     ), //8
    .RAM_DEPTH  ( RAM_DEPTH  )//, //4
)zr_com_sync_fifo_ram_1p2bank_x
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( x_wr_en              ), //i
    .wr_data              ( x_wr_data            ), //i
    .wr_full              ( x_wr_full            ), //o
    .rd_en                ( x_rd_en              ), //i
    .rd_data              ( x_rd_data            ), //o
    .rd_empty             ( x_rd_empty           ), //o
    .water_level          ( x_water_level        ), //o

    .ram_cen              ( ram_cen              ), //o
    .ram_we               ( ram_we               ), //o
    .ram_addr             ( ram_addr             ), //o
    .ram_din              ( ram_din              ), //o
    .ram_qout             ( ram_qout             )  //i
);
com_spram_cell #(
    .DATA_W     ( RAM_DW        ), //32
    .DEPTH      ( RAM_ONE_DEPTH )//, //512
)zt_com_spram_cell[1:0]
(
    .clk                  ( clk                  ), //i
    .mem_cfg              ( mem_cfg              ), //i

    .cen                  ( ram_cen              ), //i
    .we                   ( ram_we               ), //i
    .addr                 ( ram_addr             ), //i
    .din                  ( ram_din              ), //i
    .qout                 ( ram_qout             )  //o
);

//-------------------------------------------------------
//com_async_fifo_reg
//-------------------------------------------------------
localparam DW      = 8;
localparam DEPTH   = 4;
localparam AW = $clog2(DEPTH+1);
wire [AW-1:0] water_level ;
wire               wr_en    ;
wire [DW-1:0]      wr_data  ;
wire               wr_full  ;
wire               rd_en    ;
wire [DW-1:0]      rd_data  ;
wire               rd_empty ;
com_async_fifo_reg #(
    .DW         ( DW    ), //8
    .DEPTH      ( DEPTH )  //4
)u_com_async_fifo_reg
(
    .wr_clk               ( wr_clk               ), //i
    .wr_rst_n             ( wr_rst_n             ), //i
    .wr_clear             ( wr_clear             ), //i
    .rd_clk               ( rd_clk               ), //i
    .rd_rst_n             ( rd_rst_n             ), //i
    .rd_clear             ( rd_clear             ), //i

    .wr_en                ( wr_en                ), //i
    .wr_data              ( wr_data              ), //i
    .wr_full              ( wr_full              ), //o
    .rd_en                ( rd_en                ), //i
    .rd_data              ( rd_data              ), //o
    .rd_empty             ( rd_empty             ), //o
    .water_level          ( water_level          )  //o
);

//-------------------------------------------------------
//com_asyncfifo_reg_2p2ck
//-------------------------------------------------------
localparam RAM_DW    = 32;
localparam RAM_DEPTH = 64;
localparam RAM_AW = $clog2(RAM_DEPTH);
localparam RAM_CW = $clog2(RAM_DEPTH+1);
wire [RAM_CW-1:0] water_level ;
wire              ram_wr_en   ;
wire [RAM_CW-1:0] ram_wr_addr ;
wire [RAM_DW-1:0] ram_wr_data ;
wire              ram_rd_en   ;
wire [RAM_CW-1:0] ram_rd_addr ;
wire [RAM_DW-1:0] ram_rd_data ;
wire [RAM_AW-1:0] ram_wr_addr_t = ram_wr_addr;
wire [RAM_AW-1:0] ram_rd_addr_t = ram_rd_addr;
com_async_fifo_ram_2p2ck #(
    .DW         ( RAM_DW     ), //8
    .RAM_DEPTH  ( RAM_DEPTH  )  //4
)u_com_async_fifo_ram_2p2ck
(
    .wr_clk               ( wr_clk               ), //i
    .wr_rst_n             ( wr_rst_n             ), //i
    .wr_clear             ( wr_clear             ), //i
    .rd_clk               ( rd_clk               ), //i
    .rd_rst_n             ( rd_rst_n             ), //i
    .rd_clear             ( rd_clear             ), //i

    .wr_en                ( wr_en                ), //i
    .wr_data              ( wr_data              ), //i
    .wr_full              ( wr_full              ), //o
    .rd_en                ( rd_en                ), //i
    .rd_data              ( rd_data              ), //o
    .rd_empty             ( rd_empty             ), //o
    .water_level          ( water_level          ), //o

    .ram_wr_en            ( ram_wr_en            ), //o
    .ram_wr_addr          ( ram_wr_addr          ), //o
    .ram_wr_data          ( ram_wr_data          ), //o
    .ram_rd_en            ( ram_rd_en            ), //o
    .ram_rd_addr          ( ram_rd_addr          ), //o
    .ram_rd_data          ( ram_rd_data          )  //i
);
com_tpram2ck_cell #(
    .DATA_W       ( RAM_DW    ), //
    .DEPTH        ( RAM_DEPTH )  //
)zt_com_tpram2ck_cell_afifo2ck
(
    .wr_clk               ( wr_clk               ), //i
    .rd_clk               ( rd_clk               ), //i
    .mem_cfg              ( mem_cfg              ), //i

    .wr_en                ( wr_en                ), //i
    .wr_addr              ( wr_addr_t            ), //i
    .wr_data              ( wr_data              ), //i
    .rd_en                ( rd_en                ), //i
    .rd_addr              ( rd_addr_t            ), //i
    .rd_data              ( rd_data              )  //o
);

//-------------------------------------------------------------------
//com_spram_mate
//-------------------------------------------------------------------
localparam DEPTH = 16;
localparam DW    = 8;
localparam WCH   = 1; //number of write channel
localparam RCH   = 1; //number of read  channel
localparam WREG  = 0; //number of register pipeline to   ram;
localparam WRPRI = 1; //1:write/read priority,  0:read, 1:write
localparam CASACADE = 0; //0: connect to ram, 1: connect to next ram_mate;
localparam AW    = $clog2(DEPTH);

wire [WCH-1:0]           x_arr_wr_vld   ;
wire [WCH-1:0]           x_arr_wr_rdy   ;
wire [WCH-1:0][AW-1:0]   x_arr_wr_addr  ;
wire [WCH-1:0][DW-1:0]   x_arr_wr_data  ;
wire [RCH-1:0]           x_arr_rd_vld   ;
wire [RCH-1:0]           x_arr_rd_rdy   ;
wire [RCH-1:0][AW-1:0]   x_arr_rd_addr  ;
wire [RCH-1:0]           x_arr_rd_ack   ;
wire [RCH-1:0][DW-1:0]   x_arr_rd_data  ;

wire                     x_cen           ;
wire                     x_we            ;
wire [AW-1:0]            x_addr          ;
wire [DW-1:0]            x_din           ;
wire [DW-1:0]            x_qout          ;
wire                     x_rd_ack        = 1'b0;     //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
wire                     x_rd_rdy        = 1'b0;     //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
wire                     x_wr_rdy        = 1'b0;     //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
com_spram_mate #(
    .DEPTH      ( DEPTH      ), //16
    .DW         ( DW         ), //8
    .WCH        ( WCH        ), //3
    .RCH        ( RCH        ), //2
    .WREG       ( WREG       ), //0
    .WRPRI      ( WRPRI      ), //1
    .CASACADE   ( CASACADE   )  //0
)zr_com_spram_mate_x
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .arr_wr_vld           ( x_arr_wr_vld         ), //i
    .arr_wr_rdy           ( x_arr_wr_rdy         ), //o
    .arr_wr_addr          ( x_arr_wr_addr        ), //i
    .arr_wr_data          ( x_arr_wr_data        ), //i
    .arr_rd_vld           ( x_arr_rd_vld         ), //i
    .arr_rd_rdy           ( x_arr_rd_rdy         ), //o
    .arr_rd_addr          ( x_arr_rd_addr        ), //i
    .arr_rd_ack           ( x_arr_rd_ack         ), //o
    .arr_rd_data          ( x_arr_rd_data        ), //o

    .cen                  ( x_cen                ), //o
    .we                   ( x_we                 ), //o
    .addr                 ( x_addr               ), //o
    .din                  ( x_din                ), //o
    .qout                 ( x_qout               ), //i
    .rd_ack               ( x_rd_ack             ), //i
    .rd_rdy               ( x_rd_rdy             ), //i
    .wr_rdy               ( x_wr_rdy             )  //i
);


//-------------------------------------------------------------------
//com_spram_cell
//-------------------------------------------------------------------
localparam DEPTH = 16;
localparam DW    = 8;
localparam AW    = $clog2(DEPTH);
wire           x_cen           ;
wire           x_we            ;
wire [AW-1:0]  x_addr          ;
wire [DW-1:0]  x_din           ;
wire [DW-1:0]  x_qout          ;
com_spram_cell #(
    .DATA_W     ( DW    ), //32
    .DEPTH      ( DEPTH )//, //512
)zt_com_spram_cell_x
(
    .clk                  ( clk                  ), //i
    .mem_cfg              ( mem_cfg              ), //i

    .cen                  ( x_cen                ), //i
    .we                   ( x_we                 ), //i
    .addr                 ( x_addr               ), //i
    .din                  ( x_din                ), //i
    .qout                 ( x_qout               )  //o
);

//-------------------------------------------------------------------
//mimo
//-------------------------------------------------------------------
wire [0:0] x_arr_ivld ;
wire [0:0] x_arr_irdy ;
wire [1:0] x_arr_ovld ;
wire [1:0] x_arr_ordy ;
com_mimo #(
    .ICH        ( 1        ), //1
    .OCH        ( 2        )  //2
)zr_com_mimo_x
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .arr_ivld             ( x_arr_ivld           ), //i
    .arr_irdy             ( x_arr_irdy           ), //o
    .arr_ovld             ( x_arr_ovld           ), //o
    .arr_ordy             ( x_arr_ordy           )  //i
);

com_mimo #( .ICH(1), .OCH(2) ) zr_com_mimo_x( .clk(clk), .rst_n(rst_n), .clear(clear),
    .arr_ivld(ivld), .arr_irdy(irdy), .arr_ovld(ovld), .arr_ordy(ordy) );
com_simo_no_delay #( .OCH(2) ) zr_com_simo_no_delay_x( .clk(clk), .rst_n(rst_n), .clear(clear),
    .ivld(ivld), .irdy(irdy), .ovld(ovld), .ordy(ordy) );
