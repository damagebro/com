//ArbIf ------------------------------------------------------------
interface ArbIf(
    input clk
);
    parameter  PORT_N = 16;
    localparam PTID_W = $clog2(PORT_N>2?PORT_N:2);

    logic [PORT_N-1:0]   requests ;
    logic [PTID_W-1:0]   grant_id ;

    clocking cb @ (posedge clk);
        output requests;
        input  grant_id;
    endclocking
    modport tx(clocking cb);
endinterface //ArbIf
typedef virtual ArbIf.tx vArbIf;

//PipeIf ------------------------------------------------------------
interface PipeIf(
    input clk
);
    parameter  NUM_PIPE = 3;

    logic                   ivld      ;
    logic                   irdy      ;
    logic                   ovld      ;
    logic                   ordy      ;
    logic [NUM_PIPE-1:0]    pipe_upen ;

    clocking cb @ (posedge clk);
        output ivld, ordy;
        input  irdy, ovld, pipe_upen;
    endclocking
    modport tx(clocking cb);
endinterface //PipeIf
typedef virtual PipeIf.tx vPipeIf;



//RamMateIf ------------------------------------------------------------
interface RamMateIf(
    input clk
);
    import RamMatePkg::*;
    localparam WCH = RAM_MATE_WCH ;
    localparam RCH = RAM_MATE_RCH ;
    localparam AW  = RAM_MATE_AW  ;
    localparam DW  = RAM_MATE_DW  ;
    localparam WSTB= RAM_MATE_WSTB;

    logic [WCH-1:0][WSTB-1:0] arr_wr_vld         ;
    logic [WCH-1:0]           arr_wr_rdy         ;
    logic [WCH-1:0][AW-1:0]   arr_wr_addr        ;
    logic [WCH-1:0][DW-1:0]   arr_wr_data        ;
    logic [RCH-1:0]           arr_rd_vld         ;
    logic [RCH-1:0]           arr_rd_rdy         ;
    logic [RCH-1:0][AW-1:0]   arr_rd_addr        ;
    logic [RCH-1:0]           arr_rd_ack         ;
    logic [RCH-1:0][DW-1:0]   arr_rd_data        ;
    logic                     rd_ack            ;   //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
    logic                     rd_rdy            ;   //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
    logic                     wr_rdy            ;   //when CON_NEXT mode, connect rightly; when CON_MEM mode, don't care;
    //spram_if
    logic                     cen                ;
    logic [WSTB-1:0]          we                 ;
    logic [AW-1:0]            addr               ;
    logic [DW-1:0]            din                ;
    logic [DW-1:0]            qout               ;
    //tpram1ck_if
    logic [WSTB-1:0]          wr_en              ;
    logic [AW-1:0]            wr_addr            ;
    logic [DW-1:0]            wr_data            ;
    logic                     rd_en              ;
    logic [AW-1:0]            rd_addr            ;
    logic [DW-1:0]            rd_data            ;

    clocking cb @ (posedge clk);
        output arr_wr_addr,arr_wr_data, arr_wr_vld;
        input  arr_wr_rdy;
        output arr_rd_addr, arr_rd_vld;
        input  arr_rd_rdy, arr_rd_ack, arr_rd_data;
        input  rd_ack,rd_rdy,wr_rdy;

        output cen,we,addr,din;
        input  qout;

        output wr_en,wr_addr,wr_data,rd_en,rd_addr;
        input  rd_data;
    endclocking
    // modport tx(clocking cb,);
endinterface //RamMateIf
typedef virtual RamMateIf vRamMateIf;