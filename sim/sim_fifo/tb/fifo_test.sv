//-------------------------------------------------------
//fifo_test
//-------------------------------------------------------
program automatic fifo_test #(type VIf) ( FifoIf fifo_if );

// typedef virtual FifoIf vFifoIf;
FifoEnv #( VIf ) cFifoEnv ;
initial begin
     cFifoEnv = new( fifo_if );
     cFifoEnv.build();
     cFifoEnv.run();
end

endprogram:fifo_test



//-------------------------------------------------------
//afifo_test
//-------------------------------------------------------
program automatic afifo_test #(type VIf) ( AFifoIf afifo_if );

AFifoEnv #(VIf) cAFifoEnv;
initial begin
    cAFifoEnv = new( afifo_if );
    cAFifoEnv.build();
    cAFifoEnv.run();
end

endprogram:afifo_test