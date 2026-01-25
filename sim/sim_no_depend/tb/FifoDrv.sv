class FifoDrv;

// import fifo_pkg::*;
vFifoIf m_fifo_vif;

extern function new( input vFifoIf fifo_vif );
extern function build();
extern task run();

extern task rd_fifo();
extern task wr_fifo();

endclass //FifoDrv

function FifoDrv::new( input vFifoIf fifo_vif );
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
