class FifoEnv;

// mailbox mbx_gen2drv;
// event evt_gen2drv;
vFifoIf m_fifo_vif;
FifoDrv cFifoDrv;

extern function new( input vFifoIf fifo_vif );
extern function build();
extern task run();

endclass //FifoEnv

function FifoEnv::new( input vFifoIf fifo_vif );
    m_fifo_vif = fifo_vif;
endfunction:new
function FifoEnv::build();
    cFifoDrv = new( m_fifo_vif );
endfunction:build

task FifoEnv::run();
    cFifoDrv.run();
endtask:run

