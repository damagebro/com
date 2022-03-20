//-------------------------------------------------------
//ArbEnv
//-------------------------------------------------------
class ArbEnv;

vArbIf m_arb_vif;
ArbDrv cArbDrv;

function new( input vArbIf arb_vif );
    m_arb_vif = arb_vif;
endfunction:new
function build();
    cArbDrv = new( m_arb_vif );
endfunction:build

task run();
    cArbDrv.run();
endtask

endclass //ArbEnv

//-------------------------------------------------------
//PipeEnv
//-------------------------------------------------------
class PipeEnv;

vPipeIf m_pipe_vif;
PipeDrv cPipeDrv;

function new( input vPipeIf pipe_vif );
    m_pipe_vif = pipe_vif;
endfunction:new
function build();
    cPipeDrv = new( m_pipe_vif );
endfunction:build

task run();
    cPipeDrv.run();
endtask

endclass //PipeEnv



//-------------------------------------------------------
//RamMateEnv
//-------------------------------------------------------
class RamMateEnv;

vRamMateIf m_ram_vif;
RamMateDrv cRamMateDrv;

function new( input vRamMateIf ram_vif );
    m_ram_vif = ram_vif;
endfunction:new
function build();
    cRamMateDrv = new( m_ram_vif );
endfunction:build

task run();
    cRamMateDrv.run();
endtask

endclass //RamMateEnv