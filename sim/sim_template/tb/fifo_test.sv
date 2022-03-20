program automatic fifo_test( FifoIf.tx fifo_if );

FifoEnv cFifoEnv;
initial begin
    cFifoEnv = new( fifo_if );
    cFifoEnv.build();
    cFifoEnv.run();
end

endprogram:fifo_test