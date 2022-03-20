//-------------------------------------------------------
//FifoEnv
//-------------------------------------------------------
class FifoEnv #(type VIf);

// mailbox mbx_gen2drv;
// event evt_gen2drv;
VIf m_fifo_vif;
FifoDrv #( VIf ) cFifoDrv;

extern function new( input VIf fifo_vif );
extern function build();
extern task run();

endclass //FifoEnv

function FifoEnv::new( input VIf fifo_vif );
    m_fifo_vif = fifo_vif;
endfunction:new
function FifoEnv::build();
    cFifoDrv = new( m_fifo_vif );
endfunction:build

task FifoEnv::run();
    cFifoDrv.run();
endtask:run


//-------------------------------------------------------
//AFifoEnv
//-------------------------------------------------------
class AFifoEnv #(type VIf);

// mailbox mbx_gen2drv;
// event evt_gen2drv;
VIf m_afifo_vif;
AFifoDrv #(VIf) cAFifoDrv;

extern function new( input VIf afifo_vif );
extern function build();
extern task run();

endclass //AFifoEnv

function AFifoEnv::new( input VIf afifo_vif );
    m_afifo_vif = afifo_vif;
endfunction:new
function AFifoEnv::build();
    cAFifoDrv = new( m_afifo_vif );
endfunction:build

task AFifoEnv::run();
    cAFifoDrv.run();
endtask:run