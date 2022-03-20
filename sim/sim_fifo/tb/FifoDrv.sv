//-------------------------------------------------------
//FifoDrv
//-------------------------------------------------------
class FifoDrv #(type VIf);

VIf m_fifo_vif;

extern function new( input VIf fifo_vif );
extern function build();
extern task run();

extern task rd_fifo();
extern task wr_fifo();

endclass //FifoDrv

function FifoDrv::new( input VIf fifo_vif );
    m_fifo_vif = fifo_vif;
endfunction:new
function FifoDrv::build();
endfunction:build

task FifoDrv::rd_fifo();
    int cnt = 0;
    int rddata;
    m_fifo_vif.cb.rd_en <= 1'b0;
    // repeat(20) @(m_fifo_vif.cb );
    while ( 1 ) begin
        @(m_fifo_vif.cb);
        if( !m_fifo_vif.cb.rd_empty )begin
            m_fifo_vif.cb.rd_en <= $random%2;
        end
        @(m_fifo_vif.cb);
        m_fifo_vif.cb.rd_en   <= 1'b0;
        cnt++;
    end
endtask //rd_fifo
task FifoDrv::wr_fifo();
    int cnt = 0;
    int wr_en = 0;
    m_fifo_vif.cb.wr_en <= 1'b0;
    while ( cnt<16 ) begin
        @(m_fifo_vif.cb);
        if( !m_fifo_vif.cb.wr_full )begin
            wr_en = $random%2;
            m_fifo_vif.cb.wr_en   <= wr_en;
            m_fifo_vif.cb.wr_data <= cnt+1;
            @(m_fifo_vif.cb);
            m_fifo_vif.cb.wr_en   <= 1'b0;

            if( wr_en )
                cnt++;
         end
    end
endtask //wr_fifo

task FifoDrv::run();
    top.reset();
    fork
        wr_fifo();
        rd_fifo();
    join_none

    #2000;
    $finish;
endtask //run


//-------------------------------------------------------
//AFifoDrv
//-------------------------------------------------------
class AFifoDrv #(type VIf);

// import fifo_pkg::*;
VIf m_afifo_vif;

extern function new( input VIf afifo_vif );
extern function build();
extern task run();

extern task rd_fifo();
extern task wr_fifo();

endclass //AFifoDrv

function AFifoDrv::new( input VIf afifo_vif );
    m_afifo_vif = afifo_vif;
endfunction:new
function AFifoDrv::build();
endfunction:build

task AFifoDrv::rd_fifo();
    int cnt = 0;
    int rddata;
    m_afifo_vif.rcb.rd_en <= 1'b0;
    // repeat(20) @(m_afifo_vif.rcb );
    while ( 1 ) begin
        @(m_afifo_vif.rcb);
        if( !m_afifo_vif.rcb.rd_empty )begin
            m_afifo_vif.rcb.rd_en <= $random%2;
        end
        @(m_afifo_vif.rcb);
        m_afifo_vif.rcb.rd_en   <= 1'b0;
        cnt++;
    end
endtask //rd_fifo
task AFifoDrv::wr_fifo();
    int cnt = 0;
    int wr_en = 0;
    m_afifo_vif.wcb.wr_en <= 1'b0;
    while ( cnt<16 ) begin
        @(m_afifo_vif.wcb);
        if( !m_afifo_vif.wcb.wr_full )begin
            wr_en = $random%2;
            m_afifo_vif.wcb.wr_en   <= wr_en;
            m_afifo_vif.wcb.wr_data <= cnt+1;
            @(m_afifo_vif.wcb);
            m_afifo_vif.wcb.wr_en   <= 1'b0;

            if( wr_en )
                cnt++;
        end
    end
endtask //wr_fifo

task AFifoDrv::run();
    top.reset();
    repeat(10) @(m_afifo_vif.wcb);
    fork
        wr_fifo();
        rd_fifo();
    join_none

    #2000;
    $finish;
endtask //run