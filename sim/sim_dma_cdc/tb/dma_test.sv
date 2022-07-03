program automatic dma_test( com_emi_tbif emi_if, DmaIf dma_if );

DmaEnv cDmaEnv;
initial begin
    cDmaEnv = new( emi_if, dma_if );
    cDmaEnv.build();
    cDmaEnv.run();
end

endprogram:dma_test
