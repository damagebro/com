//-------------------------------------------------------
//arb_test
//-------------------------------------------------------
program automatic arb_test( ArbIf.tx arb_if );

ArbEnv cArbEnv;
initial begin
    cArbEnv = new( arb_if );
    cArbEnv.build();
    cArbEnv.run();
end

endprogram:arb_test

//-------------------------------------------------------
//pipe_test
//-------------------------------------------------------
program automatic pipe_test( PipeIf.tx pipe_if );

PipeEnv cPipeEnv;
initial begin
    cPipeEnv = new( pipe_if );
    cPipeEnv.build();
    cPipeEnv.run();
end

endprogram:pipe_test


//-------------------------------------------------------
//ram_mate_test
//-------------------------------------------------------
program automatic ram_mate_test( RamMateIf ram_if );

RamMateEnv cRamMateEnv;
initial begin
    cRamMateEnv = new( ram_if );
    cRamMateEnv.build();
    cRamMateEnv.run();
end

endprogram:ram_mate_test
