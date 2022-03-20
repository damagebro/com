//-------------------------------------------------------
//ArbDrv
//-------------------------------------------------------
class ArbDrv;

// import arb_pkg::*;
vArbIf m_arb_vif;
bit [15:0][2:0] arr_graycode = {
3'b000,3'b001,3'b011,3'b010,3'b110,3'b111,3'b101,3'b100,
3'b100,3'b101,3'b111,3'b110,3'b010,3'b011,3'b001,3'b000};

function new( input vArbIf arb_vif );
    m_arb_vif = arb_vif;
endfunction:new
function build();
endfunction:build
task run();
    int cnt = 0;

    top.reset();
    while ( cnt<16 ) begin
        @(m_arb_vif.cb);
        m_arb_vif.cb.requests <= arr_graycode[cnt%16];
        cnt++;
    end
    cnt = 0;
endtask:run

endclass:ArbDrv

//-------------------------------------------------------
//PipeDrv
//-------------------------------------------------------
class PipeDrv;

// import pipe_pkg::*;
vPipeIf m_pipe_vif;

function new( input vPipeIf pipe_vif );
    m_pipe_vif = pipe_vif;
endfunction:new
function build();
endfunction:build
task run();
    int cnt = 0;

    top.reset();
    while ( cnt<16 ) begin
        @(m_pipe_vif.cb);
        m_pipe_vif.cb.ivld <= $random%2;
        m_pipe_vif.cb.ordy <= $random%2;
        cnt++;
    end
    cnt = 0;
endtask:run

task x();
endtask:x;

endclass:PipeDrv


//-------------------------------------------------------
//RamMateDrv
//-------------------------------------------------------
class RamMateDrv;

import RamMatePkg::*;
vRamMateIf m_ram_vif;
bit  [RAM_MATE_DEPTH-1:0][RAM_MATE_DW-1:0] amem;

function new( input vRamMateIf ram_vif );
    m_ram_vif = ram_vif;
endfunction:new
function build();
endfunction:build
extern task run();

extern task wr_mem( int i );
extern task rd_mem( int i );
extern task spram_resp();
extern task tpram_resp();

endclass:RamMateDrv

task RamMateDrv::wr_mem( int i );
    int cnt = 0;
    forever begin
        @(m_ram_vif.cb);
        m_ram_vif.cb.arr_wr_vld[i] <= $random%2;
        m_ram_vif.cb.arr_wr_addr[i] <= cnt;
        m_ram_vif.cb.arr_wr_data[i] <= 'h10 + cnt;

        if( m_ram_vif.arr_wr_vld[i]==1 )begin
            do
                @(m_ram_vif.cb);
            while( m_ram_vif.cb.arr_wr_rdy[i]==0 );
            m_ram_vif.cb.arr_wr_vld[i] <= 1'b0;
            cnt++;
        end
    end
endtask //wr_mem

task RamMateDrv::rd_mem( int i );
    int cnt = 0;
    while ( cnt<16 ) begin
        @(m_ram_vif.cb);
        m_ram_vif.cb.arr_rd_vld[i] <= $random%2;
        m_ram_vif.cb.arr_rd_addr[i] <= cnt;
        if( m_ram_vif.arr_rd_vld[i]==1 )begin
            do
                @(m_ram_vif.cb);
            while( m_ram_vif.cb.arr_rd_rdy[i]==0 );
            m_ram_vif.cb.arr_rd_vld[i] <= 1'b0;
            cnt++;
        end
    end
endtask //rd_mem

task RamMateDrv::spram_resp();
    forever begin
        @(m_ram_vif.cb);
        if( !m_ram_vif.cen )begin
            if( |m_ram_vif.we )
                amem[ m_ram_vif.addr ] <= m_ram_vif.din;
            else
                m_ram_vif.qout = amem[ m_ram_vif.addr ];
        end
    end
endtask //spram_resp
task RamMateDrv::tpram_resp();
  fork
    forever begin
        @(m_ram_vif.cb);
        if( m_ram_vif.wr_en )begin
            amem[ m_ram_vif.wr_addr ] <= m_ram_vif.wr_data;
        end
    end

    forever begin
        @(m_ram_vif.cb);
        if( m_ram_vif.rd_en )begin
            m_ram_vif.rd_data = amem[ m_ram_vif.rd_addr ];
        end
    end
  join
endtask //tpram_resp

task RamMateDrv::run();
    top.reset();
    fork
        for( int i=0; i<RAM_MATE_WCH; i++ )
        begin
            fork
                int idx = i;
                wr_mem(idx);
            join_none
        end

        for( int i=0; i<RAM_MATE_RCH; i++ )
        begin
            fork
                int idx = i;
                rd_mem(idx);
            join_none
        end

        spram_resp();
        tpram_resp();
    join_none
endtask //run