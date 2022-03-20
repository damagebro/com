program emi_test();

EmiEnv cEmiEnv;

initial begin
     top.reset();

     cEmiEnv = new( top.resp_if, top.wch_if, top.rch_if );
     cEmiEnv.build();
     cEmiEnv.run();
end

initial begin
    #10;
    $display("program yep!");
    #2000;
    ->cEmiEnv.all_done;
    #10;
    $finish;
end
endprogram